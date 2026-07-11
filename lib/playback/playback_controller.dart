import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/library_models.dart';
import 'playback_engine.dart';

class SoundPlaybackController extends ChangeNotifier {
  SoundPlaybackController({
    required PlaybackEngine engine,
    List<Track> initialQueue = const [],
  }) : _engine = engine,
       _queue = List.of(initialQueue),
       _snapshot = engine.current {
    _subscription = _engine.snapshots.listen(_acceptEngineSnapshot);
  }

  final PlaybackEngine _engine;
  late final StreamSubscription<PlaybackSnapshot> _subscription;
  List<Track> _queue;
  PlaybackSnapshot _snapshot;
  int _sessionGeneration = 0;
  int _queueIndex = 0;

  PlaybackSnapshot get snapshot => _snapshot;
  Track? get currentTrack => _snapshot.track;
  List<Track> get queue => List.unmodifiable(_queue);
  bool get isPlaying => _snapshot.isPlaying;

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
      _queue = List.of(queue);
    } else if (!_queue.any((candidate) => candidate.id == track.id)) {
      _queue = [track];
    }
    _queueIndex = _queue.indexWhere((candidate) => candidate.id == track.id);
    if (_queueIndex < 0) _queueIndex = 0;
    final sessionId = ++_sessionGeneration;
    await _engine.load(track, sessionId: sessionId);
    await _engine.play();
  }

  Future<void> toggle() async {
    if (_snapshot.track == null) {
      if (_queue.isNotEmpty) await playTrack(_queue[_queueIndex]);
      return;
    }
    if (_snapshot.isPlaying) {
      await _engine.pause();
    } else {
      await _engine.play();
    }
  }

  Future<void> seek(Duration position) => _engine.seek(position);

  Future<void> next() async {
    if (_queue.isEmpty) return;
    _queueIndex = (_queueIndex + 1) % _queue.length;
    await playTrack(_queue[_queueIndex]);
  }

  Future<void> previous() async {
    if (_snapshot.position >= const Duration(seconds: 4)) {
      await seek(Duration.zero);
      return;
    }
    if (_queue.isEmpty) return;
    _queueIndex = (_queueIndex - 1 + _queue.length) % _queue.length;
    await playTrack(_queue[_queueIndex]);
  }

  void _acceptEngineSnapshot(PlaybackSnapshot next) {
    if (next.sessionId != 0 && next.sessionId != _sessionGeneration) return;
    _snapshot = next;
    notifyListeners();

    if (next.phase == PlaybackPhase.completed) {
      unawaited(this.next());
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
