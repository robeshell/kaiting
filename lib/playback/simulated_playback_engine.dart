import 'dart:async';

import '../domain/library_models.dart';
import 'playback_engine.dart';

/// A deterministic development and test engine. Production startup uses the
/// just_audio adapter; this engine lets tests exercise UI state without media.
class SimulatedPlaybackEngine implements PlaybackEngine {
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  PlaybackSnapshot _current = const PlaybackSnapshot.idle();
  Timer? _clock;
  double _volume = 1.0;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  PlaybackSnapshot get current => _current;

  @override
  Future<void> load(Track track, {required int sessionId}) async {
    _clock?.cancel();
    _emit(
      PlaybackSnapshot(
        sessionId: sessionId,
        phase: PlaybackPhase.ready,
        position: Duration.zero,
        duration: track.duration,
        track: track,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (!_current.hasTrack) return;
    _emit(_current.copyWith(phase: PlaybackPhase.playing));
    _clock ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_current.isPlaying) return;
      final next = _current.position + const Duration(milliseconds: 250);
      if (next >= _current.duration) {
        _clock?.cancel();
        _clock = null;
        _emit(
          _current.copyWith(
            phase: PlaybackPhase.completed,
            position: _current.duration,
          ),
        );
        return;
      }
      _emit(_current.copyWith(position: next));
    });
  }

  @override
  Future<void> pause() async {
    if (!_current.hasTrack) return;
    _emit(_current.copyWith(phase: PlaybackPhase.paused));
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_current.hasTrack) return;
    final clamped = Duration(
      microseconds: position.inMicroseconds.clamp(
        0,
        _current.duration.inMicroseconds,
      ),
    );
    _emit(_current.copyWith(position: clamped));
  }

  @override
  Future<void> stop() async {
    _clock?.cancel();
    _clock = null;
    _emit(const PlaybackSnapshot.idle());
  }

  void _emit(PlaybackSnapshot next) {
    _current = next;
    if (!_snapshots.isClosed) _snapshots.add(next);
  }

  @override
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
  }

  @override
  double get volume => _volume;

  @override
  void dispose() {
    _clock?.cancel();
    _snapshots.close();
  }
}
