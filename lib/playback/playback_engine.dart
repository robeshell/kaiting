import '../domain/library_models.dart';

enum PlaybackPhase {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
}

class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.sessionId,
    required this.phase,
    required this.position,
    required this.duration,
    this.track,
    this.errorMessage,
    this.playWhenReady = false,
  });

  const PlaybackSnapshot.idle()
    : sessionId = 0,
      phase = PlaybackPhase.idle,
      position = Duration.zero,
      duration = Duration.zero,
      track = null,
      errorMessage = null,
      playWhenReady = false;

  final int sessionId;
  final PlaybackPhase phase;
  final Duration position;
  final Duration duration;
  final Track? track;
  final String? errorMessage;
  final bool playWhenReady;

  bool get isPlaying =>
      phase == PlaybackPhase.playing ||
      (phase == PlaybackPhase.buffering && playWhenReady);
  bool get hasTrack => track != null;

  PlaybackSnapshot copyWith({
    PlaybackPhase? phase,
    Duration? position,
    Duration? duration,
    Track? track,
    String? errorMessage,
    bool? playWhenReady,
  }) {
    return PlaybackSnapshot(
      sessionId: sessionId,
      phase: phase ?? this.phase,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      track: track ?? this.track,
      errorMessage: errorMessage ?? this.errorMessage,
      playWhenReady: playWhenReady ?? this.playWhenReady,
    );
  }
}

abstract interface class PlaybackEngine {
  Stream<PlaybackSnapshot> get snapshots;
  PlaybackSnapshot get current;

  Future<void> load(Track track, {required int sessionId});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  void dispose();
}
