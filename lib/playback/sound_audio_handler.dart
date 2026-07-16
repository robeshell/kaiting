import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../domain/library_models.dart';
import 'media_notification_permission.dart';
import 'playback_controller.dart';
import 'playback_engine.dart';

/// Bridges Android/iOS system media controls back into the existing playback
/// controller. The controller remains the only queue and command authority.
class SoundAudioHandler extends BaseAudioHandler {
  SoundAudioHandler({MediaNotificationPermission? notificationPermission})
    : _notificationPermission =
          notificationPermission ?? PlatformMediaNotificationPermission();

  final MediaNotificationPermission _notificationPermission;
  SoundPlaybackController? _controller;
  String? _lastMediaSignature;
  String? _lastQueueSignature;
  String? _lastStateSignature;
  DateTime? _lastStateAt;
  Duration _lastStatePosition = Duration.zero;
  bool _lastStatePlaying = false;
  bool _notificationPermissionRequested = false;

  void attach(SoundPlaybackController controller) {
    if (identical(_controller, controller)) return;
    detach();
    _controller = controller;
    controller.addListener(_sync);
    _sync(force: true);
  }

  void detach() {
    _controller?.removeListener(_sync);
    _controller = null;
  }

  @override
  Future<void> play() async {
    await _controller?.resume();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _controller?.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _controller?.next();
  }

  @override
  Future<void> skipToPrevious() async {
    await _controller?.previous();
  }

  void _sync({bool force = false}) {
    final controller = _controller;
    if (controller == null) return;
    _syncQueue(controller, force: force);
    _syncMediaItem(controller, force: force);
    _syncPlaybackState(controller, force: force);
  }

  void _syncQueue(SoundPlaybackController controller, {required bool force}) {
    final signature = controller.queue.map((track) => track.id).join('\n');
    if (!force && signature == _lastQueueSignature) return;
    _lastQueueSignature = signature;
    queue.add(controller.queue.map(_mediaItemForTrack).toList(growable: false));
  }

  void _syncMediaItem(
    SoundPlaybackController controller, {
    required bool force,
  }) {
    final track = controller.displayTrack;
    final duration = controller.displayDuration;
    final signature = '${track?.id}\n${duration.inMilliseconds}';
    if (!force && signature == _lastMediaSignature) return;
    _lastMediaSignature = signature;
    mediaItem.add(
      track == null ? null : _mediaItemForTrack(track, duration: duration),
    );
  }

  void _syncPlaybackState(
    SoundPlaybackController controller, {
    required bool force,
  }) {
    final snapshot = controller.snapshot;
    final now = DateTime.now();
    final position = controller.displayPosition;
    final stateSignature = [
      snapshot.phase.name,
      snapshot.isPlaying,
      snapshot.track?.id,
      snapshot.errorMessage,
      controller.queueIndex,
    ].join('\n');
    final expectedPosition = _lastStatePlaying && _lastStateAt != null
        ? _lastStatePosition + now.difference(_lastStateAt!)
        : _lastStatePosition;
    final positionJump =
        (position - expectedPosition).inMilliseconds.abs() > 1500;
    if (!force &&
        stateSignature == _lastStateSignature &&
        !positionJump &&
        (snapshot.isPlaying || position == _lastStatePosition)) {
      return;
    }

    _lastStateSignature = stateSignature;
    _lastStateAt = now;
    _lastStatePosition = position;
    _lastStatePlaying = snapshot.isPlaying;
    if (snapshot.isPlaying && !_notificationPermissionRequested) {
      _notificationPermissionRequested = true;
      unawaited(
        _notificationPermission.ensureGranted().then((_) {
          if (identical(_controller, controller)) _sync(force: true);
        }),
      );
    }
    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      snapshot.isPlaying ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
    ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        // Keep the native transport layout stable across queue sizes. Android
        // 13+ derives these slots from PlaybackState; older versions use these
        // compact indices directly.
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: _processingState(snapshot.phase),
        playing: snapshot.isPlaying,
        updatePosition: position,
        speed: 1,
        queueIndex: controller.queue.isEmpty ? null : controller.queueIndex,
        errorMessage: snapshot.errorMessage,
      ),
    );
  }

  MediaItem _mediaItemForTrack(Track track, {Duration? duration}) {
    return MediaItem(
      id: track.id,
      title: track.title,
      album: track.albumTitle,
      artist: track.artist,
      duration: duration ?? track.duration,
      artUri: _supportedArtUri(track.artworkUri),
      playable: true,
    );
  }

  Uri? _supportedArtUri(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    return switch (uri.scheme) {
      'http' || 'https' || 'file' || 'content' => uri,
      _ => null,
    };
  }

  AudioProcessingState _processingState(PlaybackPhase phase) {
    return switch (phase) {
      PlaybackPhase.idle => AudioProcessingState.idle,
      PlaybackPhase.loading => AudioProcessingState.loading,
      PlaybackPhase.buffering => AudioProcessingState.buffering,
      PlaybackPhase.error => AudioProcessingState.error,
      PlaybackPhase.completed => AudioProcessingState.completed,
      PlaybackPhase.ready ||
      PlaybackPhase.playing ||
      PlaybackPhase.paused => AudioProcessingState.ready,
    };
  }
}
