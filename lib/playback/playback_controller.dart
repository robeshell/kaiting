import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/library_models.dart';
import 'playback_engine.dart';
import 'playback_session.dart';

class SoundPlaybackController extends ChangeNotifier {
  SoundPlaybackController({
    required PlaybackEngine engine,
    List<Track> initialQueue = const [],
    PlaybackSession? initialSession,
  }) : _engine = engine,
       _queue = List.of(initialQueue),
       _snapshot = engine.current {
    if (initialSession != null) _restoreSession(initialSession);
    _subscription = _engine.snapshots.listen(_acceptEngineSnapshot);
  }

  final PlaybackEngine _engine;
  late final StreamSubscription<PlaybackSnapshot> _subscription;
  List<Track> _queue;
  PlaybackSnapshot _snapshot;
  int _sessionGeneration = 0;
  int _queueIndex = 0;
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

  bool get isPlaying => _snapshot.isPlaying;
  bool get hasActiveTrack => _snapshot.hasTrack;

  /// Captures the current controller state for persistence. Callers must
  /// throttle saves and never feed this data back into a live engine.
  PlaybackSession get sessionSnapshot => PlaybackSession(
    queue: _queue,
    queueIndex: _queueIndex,
    positionMs:
        _resumePosition?.inMilliseconds ?? _snapshot.position.inMilliseconds,
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
      await playTrack(_snapshot.track!, queue: _queue);
      return;
    }
    if (_snapshot.phase == PlaybackPhase.completed) {
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
    if (_queue.isEmpty) return;
    _clearResumePosition();
    _queueIndex = (_queueIndex + 1) % _queue.length;
    await playTrack(_queue[_queueIndex]);
  }

  Future<void> previous() async {
    if (_snapshot.position >= const Duration(seconds: 4)) {
      await seek(Duration.zero);
      return;
    }
    if (_queue.isEmpty) return;
    _clearResumePosition();
    _queueIndex = (_queueIndex - 1 + _queue.length) % _queue.length;
    await playTrack(_queue[_queueIndex]);
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _restoreSession(PlaybackSession session) {
    if (session.queue.isEmpty) return;
    _queue = List.of(session.queue);
    _queueIndex = session.queueIndex.clamp(0, _queue.length - 1);
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
      await next();
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

  @override
  void dispose() {
    _disposed = true;
    _sessionGeneration++;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
