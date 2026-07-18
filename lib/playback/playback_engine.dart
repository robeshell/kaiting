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

  /// Sets the output volume (0.0 = mute, 1.0 = normal).
  Future<void> setVolume(double value);

  /// Current normalized output volume.
  double get volume;

  void dispose();
}

enum PlaybackQueueLoopMode { off, one, all }

/// Optional capability for engines that can keep the complete queue loaded.
///
/// Engines without this interface continue to use controller-driven
/// load/play transitions. Playlist-capable engines may transition natively and
/// therefore avoid the audible unload/reload boundary between songs.
abstract interface class PlaylistPlaybackEngine implements PlaybackEngine {
  bool get supportsGaplessTransitions;

  Future<void> loadQueue(
    List<Track> tracks, {
    required int initialIndex,
    required int sessionId,
    required PlaybackQueueLoopMode loopMode,
  });

  Future<void> updateQueue(List<Track> tracks);

  Future<void> setQueueLoopMode(PlaybackQueueLoopMode loopMode);
}
