import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../domain/library_models.dart';
import 'media_favorite_controller.dart';
import 'media_notification_permission.dart';
import 'playback_controller.dart';
import 'playback_engine.dart';
import 'playback_mode.dart';

/// Bridges Android/iOS system media controls back into the existing playback
/// controller. The controller remains the only queue and command authority.
class SoundAudioHandler extends BaseAudioHandler {
  static const toggleShuffleAction = 'toggleShuffle';
  static const toggleFavoriteAction = 'toggleFavorite';
  static const _previousControl = MediaControl(
    androidIcon: 'drawable/ic_notification_previous',
    label: '上一首',
    action: MediaAction.skipToPrevious,
  );
  static const _playControl = MediaControl(
    androidIcon: 'drawable/ic_notification_play',
    label: '播放',
    action: MediaAction.play,
  );
  static const _pauseControl = MediaControl(
    androidIcon: 'drawable/ic_notification_pause',
    label: '暂停',
    action: MediaAction.pause,
  );
  static const _nextControl = MediaControl(
    androidIcon: 'drawable/ic_notification_next',
    label: '下一首',
    action: MediaAction.skipToNext,
  );

  SoundAudioHandler({MediaNotificationPermission? notificationPermission})
    : _notificationPermission =
          notificationPermission ?? PlatformMediaNotificationPermission();

  final MediaNotificationPermission _notificationPermission;
  SoundPlaybackController? _controller;
  MediaFavoriteController? _favoriteController;
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

  void attachFavoriteController(MediaFavoriteController controller) {
    if (identical(_favoriteController, controller)) return;
    detachFavoriteController();
    _favoriteController = controller;
    controller.addListener(_sync);
    _sync(force: true);
  }

  void detachFavoriteController([MediaFavoriteController? controller]) {
    final current = _favoriteController;
    if (current == null ||
        (controller != null && !identical(current, controller))) {
      return;
    }
    current.removeListener(_sync);
    _favoriteController = null;
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

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    final controller = _controller;
    if (controller == null) return null;
    switch (name) {
      case toggleShuffleAction:
        controller.toggleShuffle();
        return null;
      case toggleFavoriteAction:
        final track = controller.displayTrack;
        final favoriteController = _favoriteController;
        if (track != null && favoriteController != null) {
          await favoriteController.toggleFavorite(track);
        }
        return null;
      default:
        return super.customAction(name, extras);
    }
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
    final track = controller.displayTrack;
    final favorite =
        track != null && (_favoriteController?.isFavorite(track.id) ?? false);
    final now = DateTime.now();
    final position = controller.displayPosition;
    final stateSignature = [
      snapshot.phase.name,
      snapshot.isPlaying,
      snapshot.track?.id,
      snapshot.errorMessage,
      controller.queueIndex,
      controller.playbackMode.name,
      controller.isShuffleEnabled,
      controller.repeatMode.name,
      favorite,
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
    final shuffleEnabled = controller.isShuffleEnabled;
    final controls = <MediaControl>[
      _shuffleControl(shuffleEnabled),
      _previousControl,
      snapshot.isPlaying ? _pauseControl : _playControl,
      _nextControl,
      _favoriteControl(favorite),
    ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        // The expanded media card uses all five controls. Compact cards retain
        // the three transport actions that matter most.
        androidCompactActionIndices: const [1, 2, 3],
        systemActions: const {MediaAction.seek},
        processingState: _processingState(snapshot.phase),
        playing: snapshot.isPlaying,
        updatePosition: position,
        speed: 1,
        queueIndex: controller.queue.isEmpty ? null : controller.queueIndex,
        // Shuffle and list-loop are independent axes on the controller.
        repeatMode: _systemRepeatMode(controller.repeatMode),
        shuffleMode: shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        errorMessage: snapshot.errorMessage,
      ),
    );
  }

  MediaControl _shuffleControl(bool enabled) {
    return MediaControl.custom(
      androidIcon: enabled
          ? 'drawable/ic_notification_shuffle_on'
          : 'drawable/ic_notification_shuffle',
      label: enabled ? '关闭随机播放' : '开启随机播放',
      name: toggleShuffleAction,
    );
  }

  MediaControl _favoriteControl(bool favorite) {
    return MediaControl.custom(
      androidIcon: favorite
          ? 'drawable/ic_notification_favorite'
          : 'drawable/ic_notification_favorite_border',
      label: favorite ? '取消收藏' : '收藏歌曲',
      name: toggleFavoriteAction,
    );
  }

  AudioServiceRepeatMode _systemRepeatMode(PlaybackRepeatMode mode) =>
      switch (mode) {
        PlaybackRepeatMode.one => AudioServiceRepeatMode.one,
        PlaybackRepeatMode.all => AudioServiceRepeatMode.all,
        PlaybackRepeatMode.off => AudioServiceRepeatMode.none,
      };

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
