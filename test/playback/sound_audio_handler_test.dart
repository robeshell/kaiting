import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/playback/media_favorite_controller.dart';
import 'package:kaiting/playback/media_notification_permission.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/playback_engine.dart';
import 'package:kaiting/playback/playback_mode.dart';
import 'package:kaiting/playback/sound_audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android media notification permission is requested only once',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel(
        'com.kaiting.player/system_media',
      );
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls++;
            expect(call.method, 'ensureNotificationPermission');
            return true;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final permission = PlatformMediaNotificationPermission();
      expect(await permission.ensureGranted(), isTrue);
      expect(await permission.ensureGranted(), isTrue);
      expect(calls, 1);
    },
  );

  test('system media commands stay synchronized with the controller', () async {
    final engine = _HandlerEngine();
    const first = Track(
      id: 'first',
      title: 'First',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 3),
      source: SourceKind.local,
      mediaUri: '/music/first.mp3',
    );
    const second = Track(
      id: 'second',
      title: 'Second',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 4),
      source: SourceKind.local,
      mediaUri: '/music/second.mp3',
    );
    final controller = SoundPlaybackController(
      engine: engine,
      initialQueue: const [first, second],
    );
    final notificationPermission = _RecordingNotificationPermission();
    final favorites = _HandlerFavoriteController();
    final handler =
        SoundAudioHandler(notificationPermission: notificationPermission)
          ..attach(controller)
          ..attachFavoriteController(favorites);
    addTearDown(() {
      handler.detachFavoriteController(favorites);
      handler.detach();
      favorites.dispose();
      controller.dispose();
      engine.dispose();
    });

    await handler.play();

    expect(controller.currentTrack, first);
    expect(handler.mediaItem.value?.title, 'First');
    expect(handler.queue.value.map((item) => item.id), ['first', 'second']);
    expect(handler.playbackState.value.playing, isTrue);
    expect(
      handler.playbackState.value.controls.any(
        (control) => control.action == MediaAction.pause,
      ),
      isTrue,
    );
    expect(handler.playbackState.value.controls, hasLength(5));
    expect(
      handler.playbackState.value.controls.first.customAction?.name,
      SoundAudioHandler.toggleShuffleAction,
    );
    expect(
      handler.playbackState.value.controls.last.customAction?.name,
      SoundAudioHandler.toggleFavoriteAction,
    );
    expect(handler.playbackState.value.androidCompactActionIndices, [1, 2, 3]);
    expect(handler.playbackState.value.repeatMode, AudioServiceRepeatMode.all);
    expect(
      handler.playbackState.value.shuffleMode,
      AudioServiceShuffleMode.none,
    );
    expect(notificationPermission.requestCount, 1);

    await handler.seek(const Duration(seconds: 75));
    expect(controller.snapshot.position, const Duration(seconds: 75));
    expect(
      handler.playbackState.value.updatePosition,
      const Duration(seconds: 75),
    );

    await handler.skipToNext();
    expect(controller.currentTrack, second);
    expect(handler.mediaItem.value?.title, 'Second');
    expect(handler.playbackState.value.queueIndex, 1);

    await handler.pause();
    expect(controller.isPlaying, isFalse);
    expect(
      handler.playbackState.value.controls.any(
        (control) => control.action == MediaAction.play,
      ),
      isTrue,
    );
    expect(engine.pauseCount, 1);

    await handler.play();
    expect(controller.isPlaying, isTrue);
    expect(engine.playCount, 3);
    await handler.play();
    expect(engine.playCount, 3);

    await handler.pause();
    await handler.pause();
    expect(controller.isPlaying, isFalse);
    expect(engine.pauseCount, 2);

    await handler.skipToPrevious();
    expect(controller.currentTrack, first);
    expect(handler.playbackState.value.queueIndex, 0);
    expect(notificationPermission.requestCount, 1);

    await controller.playTrack(first, queue: const [first]);
    await handler.pause();
    final controls = handler.playbackState.value.controls;
    expect(controls, hasLength(5));
    expect(controls[1].action, MediaAction.skipToPrevious);
    expect(controls[1].androidIcon, 'drawable/ic_notification_previous');
    expect(controls[2].action, MediaAction.play);
    expect(controls[2].androidIcon, 'drawable/ic_notification_play');
    expect(controls[3].action, MediaAction.skipToNext);
    expect(controls[3].androidIcon, 'drawable/ic_notification_next');
    expect(handler.playbackState.value.androidCompactActionIndices, [1, 2, 3]);

    await handler.customAction(SoundAudioHandler.toggleShuffleAction);
    expect(controller.playbackMode, PlaybackMode.shuffle);
    expect(
      handler.playbackState.value.shuffleMode,
      AudioServiceShuffleMode.all,
    );
    expect(
      handler.playbackState.value.controls.first.androidIcon,
      'drawable/ic_notification_shuffle_on',
    );

    expect(favorites.isFavorite(first.id), isFalse);
    expect(
      handler.playbackState.value.controls.last.androidIcon,
      'drawable/ic_notification_favorite_border',
    );
    await handler.customAction(SoundAudioHandler.toggleFavoriteAction);
    expect(favorites.isFavorite(first.id), isTrue);
    expect(
      handler.playbackState.value.controls.last.androidIcon,
      'drawable/ic_notification_favorite',
    );
    await handler.customAction(SoundAudioHandler.toggleFavoriteAction);
    expect(favorites.isFavorite(first.id), isFalse);
  });
}

class _RecordingNotificationPermission implements MediaNotificationPermission {
  int requestCount = 0;

  @override
  Future<bool> ensureGranted() async {
    requestCount++;
    return true;
  }
}

class _HandlerFavoriteController extends ChangeNotifier
    implements MediaFavoriteController {
  final Set<String> _favoriteIds = {};

  @override
  bool isFavorite(String trackId) => _favoriteIds.contains(trackId);

  @override
  Future<void> toggleFavorite(Track track) async {
    if (!_favoriteIds.add(track.id)) _favoriteIds.remove(track.id);
    notifyListeners();
  }
}

class _HandlerEngine implements PlaybackEngine {
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  PlaybackSnapshot _current = const PlaybackSnapshot.idle();
  int playCount = 0;
  int pauseCount = 0;

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> load(Track track, {required int sessionId}) async {
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
    if (_current.track == null) return;
    playCount++;
    _emit(_current.copyWith(phase: PlaybackPhase.playing));
  }

  @override
  Future<void> pause() async {
    if (_current.track == null) return;
    pauseCount++;
    _emit(_current.copyWith(phase: PlaybackPhase.paused));
  }

  @override
  Future<void> seek(Duration position) async {
    if (_current.track == null) return;
    _emit(_current.copyWith(position: position));
  }

  @override
  Future<void> stop() async {
    _emit(const PlaybackSnapshot.idle());
  }

  void _emit(PlaybackSnapshot snapshot) {
    _current = snapshot;
    _snapshots.add(snapshot);
  }

  @override
  Future<void> setVolume(double value) async {}

  @override
  double get volume => 1.0;

  @override
  void dispose() {
    unawaited(_snapshots.close());
  }
}
