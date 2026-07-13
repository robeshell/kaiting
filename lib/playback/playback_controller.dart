import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/library_models.dart';
import 'just_audio_playback_engine.dart';
import 'playback_engine.dart';
import 'playback_mode.dart';
import 'playback_session.dart';

class SoundPlaybackController extends ChangeNotifier {
  SoundPlaybackController({
    required PlaybackEngine engine,
    List<Track> initialQueue = const [],
    PlaybackSession? initialSession,
    Random? random,
  }) : _engine = engine,
       _queue = List.of(initialQueue),
       _snapshot = engine.current,
       _random = random ?? Random() {
    if (initialSession != null) _restoreSession(initialSession);
    _subscription = _engine.snapshots.listen(_acceptEngineSnapshot);
  }

  final PlaybackEngine _engine;
  final Random _random;
  late final StreamSubscription<PlaybackSnapshot> _subscription;
  List<Track> _queue;
  PlaybackSnapshot _snapshot;
  int _sessionGeneration = 0;
  int _queueIndex = 0;
  PlaybackMode _playbackMode = PlaybackMode.repeatAll;
  Duration? _resumePosition;
  String? _resumeTrackId;
  Track? _fallbackTrack;
  int? _completionHandledSession;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Public
  // ---------------------------------------------------------------------------

  PlaybackSnapshot get snapshot => _snapshot;
  Track? get currentTrack => _snapshot.track;
  Track? get displayTrack => _snapshot.track ?? _fallbackTrack;
  Duration get displayPosition => _snapshot.track == null
      ? _resumePosition ?? Duration.zero
      : _snapshot.position;
  Duration get displayDuration => _snapshot.track == null
      ? _fallbackTrack?.duration ?? Duration.zero
      : _snapshot.duration;
  List<Track> get queue => List.unmodifiable(_queue);
  int get queueIndex => _queueIndex;
  PlaybackMode get playbackMode => _playbackMode;

  bool get isPlaying => _snapshot.isPlaying;
  bool get hasActiveTrack => _snapshot.hasTrack;

  /// Allows setting engines-specific headers, e.g. WebDAV auth tokens.
  void setEngineAuthHeaders(
    Map<String, Map<String, String>> headers, {
    Set<String> allowBadCertificateUrls = const {},
  }) {
    if (_engine case JustAudioPlaybackEngine engine) {
      engine.webDavAuthHeaders = headers;
      engine.webDavAllowBadCertificateUrls = allowBadCertificateUrls;
    }
  }

  /// Captures the current controller state for persistence. Callers must
  /// throttle saves and never feed this data back into a live engine.
  PlaybackSession get sessionSnapshot => PlaybackSession(
    queue: _queue,
    queueIndex: _queueIndex,
    positionMs:
        _resumePosition?.inMilliseconds ?? _snapshot.position.inMilliseconds,
    playbackMode: _playbackMode,
  );

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    _fallbackTrack = track;
    if (queue != null && queue.isNotEmpty) {
      _queue = List.of(queue);
      _queueIndex = _queue.indexWhere((candidate) => candidate.id == track.id);
      if (_queueIndex < 0) {
        _queue = [track];
        _queueIndex = 0;
      }
      if (_playbackMode == PlaybackMode.shuffle && _queue.length > 1) {
        _shuffleQueueKeepingCurrent(track.id);
      }
    } else {
      if (!_queue.any((candidate) => candidate.id == track.id)) {
        _queue = [track];
      }
      _queueIndex = _queue.indexWhere((candidate) => candidate.id == track.id);
      if (_queueIndex < 0) _queueIndex = 0;
    }
    if (_resumeTrackId != null && _resumeTrackId != track.id) {
      _clearResumePosition();
    }
    final pendingSeek = _resumeTrackId == track.id ? _resumePosition : null;
    final sessionId = ++_sessionGeneration;
    _completionHandledSession = null;
    await _engine.load(track, sessionId: sessionId);
    if (_disposed || sessionId != _sessionGeneration) return;
    if (pendingSeek != null && pendingSeek > Duration.zero) {
      await _engine.seek(pendingSeek);
      if (_disposed || sessionId != _sessionGeneration) return;
      if (_resumeTrackId == track.id) _clearResumePosition();
    }
    await _engine.play();
    if (_disposed || sessionId != _sessionGeneration) return;
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_snapshot.track == null) {
      if (_queue.isNotEmpty) await playTrack(_queue[_queueIndex]);
      return;
    }
    if (_snapshot.phase == PlaybackPhase.loading) return;
    if (_snapshot.phase == PlaybackPhase.error) {
      await playTrack(_snapshot.track!);
      return;
    }
    if (_snapshot.phase == PlaybackPhase.completed) {
      _completionHandledSession = null;
      await _engine.seek(Duration.zero);
      await _engine.play();
      return;
    }
    if (_snapshot.isPlaying) {
      await _engine.pause();
    } else {
      await _engine.play();
    }
  }

  Future<void> seek(Duration position) async {
    _clearResumePosition();
    await _engine.seek(position);
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
    }
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
    if (currentIndex >= 0) {
      _queueIndex = currentIndex;
    } else if (_queue.length == 1) {
      _queueIndex = 0;
    }
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
    if (currentId != null) {
      _queueIndex = _queue.indexWhere((candidate) => candidate.id == currentId);
    }
    notifyListeners();
  }

  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final removed = _queue[index];
    final currentId = displayTrack?.id;
    final removedCurrent = removed.id == currentId;
    final hadLoadedTrack = _snapshot.track != null;
    _queue.removeAt(index);

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

  void _acceptEngineSnapshot(PlaybackSnapshot next) {
    if (next.sessionId != 0 && next.sessionId != _sessionGeneration) return;
    _snapshot = next;
    notifyListeners();

    if (next.phase == PlaybackPhase.completed &&
        _queue.isNotEmpty &&
        _queueIndex < _queue.length &&
        _queue[_queueIndex].id == next.track?.id &&
        _completionHandledSession != next.sessionId) {
      _completionHandledSession = next.sessionId;
      unawaited(_advanceAfterCompletion(next.sessionId, next.track!.id));
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

  void _shuffleQueueKeepingCurrent(String? currentId) {
    Track? current;
    if (currentId != null) {
      final index = _queue.indexWhere((track) => track.id == currentId);
      if (index >= 0) current = _queue.removeAt(index);
    }
    _queue.shuffle(_random);
    if (current != null) _queue.insert(0, current);
    _queueIndex = 0;
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
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionGeneration++;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
