import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app/sound_app.dart';
import 'library/persistence/drift_library_repository.dart';
import 'playback/just_audio_playback_engine.dart';
import 'playback/playback_media_provider.dart';
import 'playback/sound_audio_handler.dart';
import 'presentation/controllers/library_catalog_controller.dart';
import 'sources/webdav/webdav_cache.dart';
import 'sources/webdav/webdav_playback_media_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final libraryRepository = DriftLibraryRepository.defaults();
  final initialCatalogFuture = loadLibraryCatalogSnapshot(libraryRepository)
      .then<LibraryCatalogSnapshot?>((snapshot) => snapshot)
      .catchError((Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'sound library bootstrap',
            context: ErrorDescription('while preloading the library catalog'),
          ),
        );
        return null;
      });

  final audioHandler = await AudioService.init(
    builder: SoundAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.soundplayer.sound_player.audio',
      androidNotificationChannelName: '音乐播放',
      androidNotificationChannelDescription: '播放控制和当前歌曲信息',
      androidNotificationIcon: 'drawable/ic_stat_sound',
      notificationColor: Color(0xFFFF5B55),
      androidNotificationOngoing: false,
      // Keep the media foreground service alive while paused. Android 12+
      // may reject restarting it from a notification action once the app is
      // backgrounded, which makes the system play button appear unresponsive.
      androidStopForegroundOnPause: false,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
      preloadArtwork: true,
    ),
  );

  WebDavCache? cache;
  if (!kIsWeb) {
    final cacheDir = Directory(
      '${(await getApplicationCacheDirectory()).path}/webdav',
    );
    cache = WebDavCache(cacheDir: cacheDir);
    await cache.init();
  }
  final initialCatalog = await initialCatalogFuture;

  runApp(
    SoundApp(
      engine: JustAudioPlaybackEngine(
        mediaProviders: PlaybackMediaProviderRegistry([
          WebDavPlaybackMediaProvider(cache: cache),
          const DirectPlaybackMediaProvider(),
        ]),
      ),
      repository: libraryRepository,
      initialCatalog: initialCatalog,
      ownsRepository: true,
      audioHandler: audioHandler,
      webDavCache: cache,
    ),
  );
}
