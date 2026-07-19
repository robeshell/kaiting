import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/library_models.dart';
import 'playback_engine.dart';
import 'playback_lyrics_source.dart';
import 'playback_media_provider.dart';
import 'playback_mode.dart';
import 'playback_session.dart';

class SoundPlaybackController extends ChangeNotifier {
  SoundPlaybackController({
    required PlaybackEngine engine,
    List<Track> initialQueue = const [],
    PlaybackSession? initialSession,
    this._lyricsSource,
    Random? random,
  }) : _engine = engine,
       _queue = List.of(initialQueue),
       _snapshot = engine.current,
       _random = random ?? Random() {
    if (initialSession != null) _restoreSession(initialSession);
    _subscription = _engine.snapshots.listen(_acceptEngineSnapshot);
    if (_lyricsSource != null && _queue.isNotEmpty) {
      unawaited(hydrateQueueLyrics());
    }
  }

  final PlaybackEngine _engine;
  final PlaybackLyricsSource? _lyricsSource;
  final Random _random;
  final StreamController<Track> _trackStartedController =
      StreamController<Track>.broadcast(sync: true);
  late final StreamSubscription<PlaybackSnapshot> _subscription;
  List<Track> _queue;
  PlaybackSnapshot _snapshot;
  int _sessionGeneration = 0;
  int _lyricsHydrationGeneration = 0;
  int _queueIndex = 0;
  int _queueRevision = 0;
  PlaybackMode _playbackMode = PlaybackMode.repeatAll;
  Duration? _resumePosition;
  String? _resumeTrackId;
  Duration? _pendingSeekPosition;
  String? _pendingSeekTrackId;
  int _positionDiscontinuityRevision = 0;
  Track? _fallbackTrack;
  int? _completionHandledSession;
  int? _lastStartedSession;
  String? _lastStartedTrackId;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Public
  // ---------------------------------------------------------------------------

  PlaybackSnapshot get snapshot => _snapshot;
  Track? get currentTrack => _snapshot.track;
  Track? get displayTrack => _snapshot.track ?? _fallbackTrack;
  Duration get displayPosition {
    final track = _snapshot.track;
    if (track == null) return _resumePosition ?? Duration.zero;
    if (_pendingSeekTrackId == track.id) {
      return _pendingSeekPosition ?? _snapshot.position;
    }
    return _snapshot.position;
  }

  Duration get displayDuration => _snapshot.track == null
      ? _fallbackTrack?.duration ?? Duration.zero
      : _snapshot.duration;
  List<Track> get queue => List.unmodifiable(_queue);
  int get queueIndex => _queueIndex;
  PlaybackMode get playbackMode => _playbackMode;
  Stream<Track> get trackStarted => _trackStartedController.stream;
  bool get supportsGaplessTransitions => switch (_engine) {
    PlaylistPlaybackEngine engine => engine.supportsGaplessTransitions,
    _ => false,
  };

  bool get isPlaying => _snapshot.isPlaying;
  bool get hasActiveTrack => _snapshot.hasTrack;
  int get positionDiscontinuityRevision => _positionDiscontinuityRevision;

  void updatePlaybackMediaAccess(List<PlaybackMediaAccessRule> rules) {
    if (_engine case PlaybackMediaAccessSink sink) {
      sink.updatePlaybackMediaAccess(rules);
    }
  }

  /// Captures the current controller state for persistence. Callers must
  /// throttle saves and never feed this data back into a live engine.
  PlaybackSession get sessionSnapshot => PlaybackSession(
    queue: _queue,
    queueIndex: _queueIndex,
    positionMs: displayPosition.inMilliseconds,
    playbackMode: _playbackMode,
    queueRevision: _queueRevision,
  );

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    _positionDiscontinuityRevision++;
    _pendingSeekPosition = null;
    _pendingSeekTrackId = null;
    final hydrateToken = ++_lyricsHydrationGeneration;

    late final Track selected;
    if (queue != null && queue.isNotEmpty) {
      final hydratedQueue = await _hydrateTracks(queue);
      if (_disposed || hydrateToken != _lyricsHydrationGeneration) return;
      final index = hydratedQueue.indexWhere(
        (candidate) => candidate.id == track.id,
      );
      selected = index >= 0
          ? _preferRicherLyrics(hydratedQueue[index], track)
          : await _hydrateTrack(track);
      if (_disposed || hydrateToken != _lyricsHydrationGeneration) return;
      _queue = index >= 0
          ? [
              for (final candidate in hydratedQueue)
                if (candidate.id == selected.id) selected else candidate,
            ]
          : [selected];
      _queueRevision++;
      _queueIndex = _queue.indexWhere((candidate) => candidate.id == selected.id);
      if (_queueIndex < 0) {
        _queue = [selected];
        _queueIndex = 0;
      }
      if (_playbackMode == PlaybackMode.shuffle && _queue.length > 1) {
        _shuffleQueueKeepingCurrent(selected.id);
      }
    } else {
      selected = await _hydrateTrack(track);
      if (_disposed || hydrateToken != _lyricsHydrationGeneration) return;
      if (!_queue.any((candidate) => candidate.id == selected.id)) {
        _queue = [selected];
        _queueRevision++;
      } else {
        final index = _queue.indexWhere(
          (candidate) => candidate.id == selected.id,
        );
        if (index >= 0 &&
            _queue[index].lyrics.isEmpty &&
            selected.lyrics.isNotEmpty) {
          _queue[index] = selected;
        }
      }
      _queueIndex = _queue.indexWhere((candidate) => candidate.id == selected.id);
      if (_queueIndex < 0) _queueIndex = 0;
    }

    final active = _queue[_queueIndex];
    _fallbackTrack = active;
    if (_resumeTrackId != null && _resumeTrackId != active.id) {
      _clearResumePosition();
    }
    final pendingSeek = _resumeTrackId == active.id ? _resumePosition : null;
    final sessionId = ++_sessionGeneration;
    _completionHandledSession = null;
    if (_engine case PlaylistPlaybackEngine engine) {
      await engine.loadQueue(
        _queue,
        initialIndex: _queueIndex,
        sessionId: sessionId,
        loopMode: _queueLoopMode,
      );
    } else {
      await _engine.load(active, sessionId: sessionId);
    }
    if (_disposed || sessionId != _sessionGeneration) return;
    if (pendingSeek != null && pendingSeek > Duration.zero) {
      await _engine.seek(pendingSeek);
      if (_disposed || sessionId != _sessionGeneration) return;
      if (_resumeTrackId == active.id) _clearResumePosition();
    }
    await _engine.play();
    if (_disposed || sessionId != _sessionGeneration) return;
    notifyListeners();
  }

  /// Re-attaches catalog lyrics to queue entries that restored without them.
  ///
  /// Safe to call after session restore or whenever the library finishes loading.
  Future<void> hydrateQueueLyrics() async {
    final source = _lyricsSource;
    if (source == null || _disposed || _queue.isEmpty) return;
    final token = ++_lyricsHydrationGeneration;
    final hydrated = await _hydrateTracks(_queue);
    if (_disposed || token != _lyricsHydrationGeneration) return;
    if (!_queueLyricsChanged(_queue, hydrated)) return;
    final currentId = displayTrack?.id ?? _queue[_queueIndex].id;
    _queue = hydrated;
    final index = _queue.indexWhere((track) => track.id == currentId);
    if (index >= 0) {
      _queueIndex = index;
      _fallbackTrack = _queue[index];
      final snapshotTrack = _snapshot.track;
      if (snapshotTrack != null &&
          snapshotTrack.id == currentId &&
          snapshotTrack.lyrics.isEmpty &&
          _queue[index].lyrics.isNotEmpty) {
        _snapshot = _snapshot.copyWith(track: _queue[index]);
      }
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_snapshot.isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Explicitly resumes the current media item.
  ///
  /// System media controls send separate play and pause commands, so they
  /// should not depend on a toggle that can race a delayed native state update.
  Future<void> resume() async {
    if (_snapshot.track == null) {
      if (_queue.isNotEmpty) await playTrack(_queue[_queueIndex]);
      return;
    }
    if (_snapshot.phase == PlaybackPhase.loading) return;
    if (_snapshot.phase == PlaybackPhase.error) {
      await retryCurrent();
      return;
    }
    if (_snapshot.phase == PlaybackPhase.completed) {
      _completionHandledSession = null;
      await seek(Duration.zero);
      await _engine.play();
      return;
    }
    if (_snapshot.isPlaying) return;
    await _engine.play();
  }

  Future<void> pause() async {
    if (_snapshot.track == null || !_snapshot.isPlaying) return;
    await _engine.pause();
  }

  /// Reloads the failed item without losing the active queue or listen point.
  ///
  /// Network recovery uses this instead of starting the track from zero. The
  /// regular session-generation checks still reject callbacks from the failed
  /// native load.
  Future<void> retryCurrent() async {
    final track = displayTrack;
    if (track == null) return;
    final retryPosition = displayPosition;
    if (retryPosition > Duration.zero) {
      _resumeTrackId = track.id;
      _resumePosition = retryPosition;
    }
    await playTrack(track);
  }

  Future<void> seek(Duration position) async {
    _clearResumePosition();
    final duration = displayDuration;
    final upperBound = duration > Duration.zero
        ? duration.inMicroseconds
        : position.inMicroseconds.clamp(0, 1 << 62);
    final target = Duration(
      microseconds: position.inMicroseconds.clamp(0, upperBound),
    );
    // Keep the engine snapshot authoritative while exposing a provisional
    // display position so the scrubber and lyrics react in the same frame.
    final seekTrackId = _snapshot.track?.id;
    if (seekTrackId != null) {
      _positionDiscontinuityRevision++;
      _pendingSeekPosition = target;
      _pendingSeekTrackId = seekTrackId;
      notifyListeners();
    }
    await _engine.seek(target);
    // Every in-tree engine publishes its confirmed seek before completing the
    // Future. If it could not seek (for example while still loading), remove
    // the provisional display target instead of leaving progress and lyrics
    // pinned to a position the engine never reached.
    if (_pendingSeekTrackId == seekTrackId && _pendingSeekPosition == target) {
      _pendingSeekPosition = null;
      _pendingSeekTrackId = null;
      notifyListeners();
    }
  }

  Future<void> next() async {
    await _advance(fromCompletion: false);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    _clearResumePosition();
    if (_queueIndex > 0) {
      _queueIndex--;
    } else if (_playbackMode == PlaybackMode.repeatAll) {
      _queueIndex = _queue.length - 1;
    } else {
      return;
    }
    await playTrack(_queue[_queueIndex]);
  }

  void setPlaybackMode(PlaybackMode mode) {
    if (_playbackMode == mode) return;
    _playbackMode = mode;
    if (mode == PlaybackMode.shuffle && _queue.length > 1) {
      _shuffleQueueKeepingCurrent(displayTrack?.id);
      _syncPlaylistQueue();
    }
    _syncPlaylistLoopMode();
    notifyListeners();
  }

  void toggleShuffle() {
    setPlaybackMode(
      _playbackMode == PlaybackMode.shuffle
          ? PlaybackMode.sequential
          : PlaybackMode.shuffle,
    );
  }

  void cycleRepeatMode() {
    setPlaybackMode(switch (_playbackMode) {
      PlaybackMode.repeatAll => PlaybackMode.repeatOne,
      PlaybackMode.repeatOne => PlaybackMode.sequential,
      PlaybackMode.sequential || PlaybackMode.shuffle => PlaybackMode.repeatAll,
    });
  }

  Future<void> playQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length || index == _queueIndex) return;
    _clearResumePosition();
    _queueIndex = index;
    await playTrack(_queue[index]);
  }

  void playNext(Track track) {
    final currentId = displayTrack?.id;
    if (track.id == currentId) return;

    final existingIndex = _queue.indexWhere(
      (candidate) => candidate.id == track.id,
    );
    if (existingIndex >= 0) _queue.removeAt(existingIndex);

    final currentIndex = currentId == null
        ? -1
        : _queue.indexWhere((candidate) => candidate.id == currentId);
    final insertIndex = currentIndex < 0 ? 0 : currentIndex + 1;
    _queue.insert(insertIndex, track);
    _queueRevision++;
    if (currentIndex >= 0) {
      _queueIndex = currentIndex;
    } else if (_queue.length == 1) {
      _queueIndex = 0;
    }
    _syncPlaylistQueue();
    notifyListeners();
  }

  void moveQueueItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length || newIndex == oldIndex) {
      return;
    }
    final currentId = displayTrack?.id;
    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);
    _queueRevision++;
    if (currentId != null) {
      _queueIndex = _queue.indexWhere((candidate) => candidate.id == currentId);
    }
    _syncPlaylistQueue();
    notifyListeners();
  }

  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final removed = _queue[index];
    final currentId = displayTrack?.id;
    final removedCurrent = removed.id == currentId;
    final hadLoadedTrack = _snapshot.track != null;
    _queue.removeAt(index);
    _queueRevision++;

    if (_queue.isEmpty) {
      _queueIndex = 0;
      _fallbackTrack = null;
      _completionHandledSession = null;
      _clearResumePosition();
      await _engine.stop();
      if (!_disposed) notifyListeners();
      return;
    }

    if (!removedCurrent) {
      if (currentId != null) {
        _queueIndex = _queue.indexWhere(
          (candidate) => candidate.id == currentId,
        );
      } else {
        _queueIndex = _queueIndex.clamp(0, _queue.length - 1);
      }
      _syncPlaylistQueue();
      notifyListeners();
      return;
    }

    _clearResumePosition();
    _queueIndex = index.clamp(0, _queue.length - 1);
    _fallbackTrack = _queue[_queueIndex];
    if (hadLoadedTrack) {
      await playTrack(_queue[_queueIndex]);
    } else {
      notifyListeners();
    }
  }

  Future<void> clearQueue() async {
    if (_queue.isEmpty && displayTrack == null) return;
    _queue = [];
    _queueRevision++;
    _queueIndex = 0;
    _fallbackTrack = null;
    _completionHandledSession = null;
    _clearResumePosition();
    await _engine.stop();
    if (!_disposed) notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _restoreSession(PlaybackSession session) {
    if (session.queue.isEmpty) return;
    _queue = List.of(session.queue);
    _queueRevision = session.queueRevision;
    _queueIndex = session.queueIndex.clamp(0, _queue.length - 1);
    _playbackMode = session.playbackMode;
    _fallbackTrack = _queue[_queueIndex];
    if (session.positionMs > 0) {
      _resumePosition = Duration(milliseconds: session.positionMs);
      _resumeTrackId = _queue[_queueIndex].id;
    }
  }

  void _clearResumePosition() {
    _resumePosition = null;
    _resumeTrackId = null;
  }

  Future<Track> _hydrateTrack(Track track) async {
    if (track.lyrics.isNotEmpty) return track;
    final source = _lyricsSource;
    if (source == null) return track;
    try {
      final lyrics = await source.lyricsForTrack(track.id);
      if (lyrics.isEmpty) return track;
      return track.copyWith(lyrics: lyrics);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'sound playback lyrics',
          context: ErrorDescription(
            'while hydrating lyrics for track ${track.id}',
          ),
        ),
      );
      return track;
    }
  }

  Future<List<Track>> _hydrateTracks(List<Track> tracks) async {
    final source = _lyricsSource;
    if (source == null || tracks.isEmpty) return List.of(tracks);
    final missingIds = [
      for (final track in tracks)
        if (track.lyrics.isEmpty) track.id,
    ];
    if (missingIds.isEmpty) return List.of(tracks);
    try {
      final lyricsById = await source.lyricsForTracks(missingIds);
      if (lyricsById.isEmpty) return List.of(tracks);
      return [
        for (final track in tracks)
          if (track.lyrics.isEmpty)
            if (lyricsById[track.id] case final List<LyricLine> lyrics
                when lyrics.isNotEmpty)
              track.copyWith(lyrics: lyrics)
            else
              track
          else
            track,
      ];
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'sound playback lyrics',
          context: ErrorDescription('while hydrating queue lyrics'),
        ),
      );
      return List.of(tracks);
    }
  }

  Track _preferRicherLyrics(Track primary, Track fallback) {
    if (primary.lyrics.isNotEmpty || fallback.lyrics.isEmpty) return primary;
    return fallback;
  }

  bool _queueLyricsChanged(List<Track> before, List<Track> after) {
    if (before.length != after.length) return true;
    for (var index = 0; index < before.length; index++) {
      if (before[index].id != after[index].id) return true;
      if (before[index].lyrics.length != after[index].lyrics.length) {
        return true;
      }
      if (before[index].lyrics.isEmpty && after[index].lyrics.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void _acceptEngineSnapshot(PlaybackSnapshot next) {
    if (next.sessionId != 0 && next.sessionId != _sessionGeneration) return;
    var acceptedSnapshot = next;
    var nextTrack = next.track;
    if (nextTrack != null && _queue.isNotEmpty) {
      final emittedTrack = nextTrack;
      final index = _queue.indexWhere((track) => track.id == emittedTrack.id);
      if (index < 0) return;
      _queueIndex = index;
      final queuedTrack = _queue[index];
      final libraryTrack =
          queuedTrack.lyrics.isEmpty && emittedTrack.lyrics.isNotEmpty
          ? emittedTrack
          : queuedTrack;
      if (!identical(queuedTrack, libraryTrack)) _queue[index] = libraryTrack;
      nextTrack = libraryTrack;
      _fallbackTrack = libraryTrack;
      if (!identical(next.track, libraryTrack)) {
        acceptedSnapshot = next.copyWith(track: libraryTrack);
      }
    }
    final pendingTarget = _pendingSeekPosition;
    if (_pendingSeekTrackId != null &&
        (_pendingSeekTrackId != nextTrack?.id ||
            next.phase == PlaybackPhase.error ||
            (pendingTarget != null &&
                (next.position - pendingTarget).abs() <=
                    const Duration(milliseconds: 500)))) {
      _pendingSeekPosition = null;
      _pendingSeekTrackId = null;
    }
    _snapshot = acceptedSnapshot;
    if (nextTrack != null &&
        next.isPlaying &&
        (_lastStartedSession != next.sessionId ||
            _lastStartedTrackId != nextTrack.id)) {
      _lastStartedSession = next.sessionId;
      _lastStartedTrackId = nextTrack.id;
      _trackStartedController.add(nextTrack);
    }
    notifyListeners();

    if (next.phase == PlaybackPhase.completed &&
        _queue.isNotEmpty &&
        _queueIndex < _queue.length &&
        _queue[_queueIndex].id == nextTrack?.id &&
        _completionHandledSession != next.sessionId) {
      _completionHandledSession = next.sessionId;
      unawaited(_advanceAfterCompletion(next.sessionId, nextTrack!.id));
    }
  }

  Future<void> _advanceAfterCompletion(
    int completedSession,
    String completedTrackId,
  ) async {
    await Future<void>.delayed(Duration.zero);
    if (_disposed ||
        completedSession != _sessionGeneration ||
        _queue.isEmpty ||
        _queueIndex >= _queue.length ||
        _queue[_queueIndex].id != completedTrackId) {
      return;
    }
    try {
      await _advance(fromCompletion: true);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'sound playback',
          context: ErrorDescription('while advancing the completed queue'),
        ),
      );
    }
  }

  Future<void> _advance({required bool fromCompletion}) async {
    if (_queue.isEmpty) return;
    _clearResumePosition();

    if (fromCompletion && _playbackMode == PlaybackMode.repeatOne) {
      await playTrack(_queue[_queueIndex]);
      return;
    }

    if (_queueIndex + 1 < _queue.length) {
      _queueIndex++;
    } else {
      switch (_playbackMode) {
        case PlaybackMode.repeatAll:
          _queueIndex = 0;
        case PlaybackMode.shuffle:
          _reshuffleForNextCycle();
        case PlaybackMode.sequential || PlaybackMode.repeatOne:
          return;
      }
    }
    await playTrack(_queue[_queueIndex]);
  }

  PlaybackQueueLoopMode get _queueLoopMode => switch (_playbackMode) {
    PlaybackMode.repeatAll => PlaybackQueueLoopMode.all,
    PlaybackMode.repeatOne => PlaybackQueueLoopMode.one,
    PlaybackMode.sequential ||
    PlaybackMode.shuffle => PlaybackQueueLoopMode.off,
  };

  void _syncPlaylistLoopMode() {
    if (_engine case PlaylistPlaybackEngine engine) {
      unawaited(
        engine.setQueueLoopMode(_queueLoopMode).catchError((Object error) {
          _reportPlaylistError(error, 'while changing the queue loop mode');
        }),
      );
    }
  }

  void _syncPlaylistQueue() {
    if (_engine case PlaylistPlaybackEngine engine
        when _snapshot.track != null) {
      unawaited(
        engine.updateQueue(_queue).catchError((Object error) {
          _reportPlaylistError(error, 'while synchronizing the playback queue');
        }),
      );
    }
  }

  void _reportPlaylistError(Object error, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        library: 'sound playback',
        context: ErrorDescription(context),
      ),
    );
  }

  void _shuffleQueueKeepingCurrent(String? currentId) {
    Track? current;
    if (currentId != null) {
      final index = _queue.indexWhere((track) => track.id == currentId);
      if (index >= 0) current = _queue.removeAt(index);
    }
    _queue.shuffle(_random);
    if (current != null) _queue.insert(0, current);
    _queueIndex = 0;
    _queueRevision++;
  }

  void _reshuffleForNextCycle() {
    final completedId = displayTrack?.id;
    _queue.shuffle(_random);
    if (_queue.length > 1 && _queue.first.id == completedId) {
      final replacement = _queue.indexWhere((track) => track.id != completedId);
      final first = _queue.first;
      _queue[0] = _queue[replacement];
      _queue[replacement] = first;
    }
    _queueIndex = 0;
    _queueRevision++;
  }

  /// Sets the output volume (0.0 = mute, 1.0 = normal).
  Future<void> setVolume(double value) async {
    if (_disposed) return;
    await _engine.setVolume(value.clamp(0.0, 1.0));
    if (!_disposed) notifyListeners();
  }

  /// Current volume level from the audio engine.
  double get volume => _engine.volume;

  @override
  void dispose() {
    _disposed = true;
    _sessionGeneration++;
    unawaited(_subscription.cancel());
    unawaited(_trackStartedController.close());
    super.dispose();
  }
}
