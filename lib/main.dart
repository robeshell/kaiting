import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app/sound_app.dart';
import 'app/theme_preferences.dart';
import 'core/sound_theme.dart';
import 'library/persistence/drift_library_repository.dart';
import 'playback/just_audio_playback_engine.dart';
import 'playback/playback_media_provider.dart';
import 'playback/playback_session.dart';
import 'playback/sound_audio_handler.dart';
import 'presentation/controllers/library_catalog_controller.dart';
import 'sources/webdav/webdav_cache.dart';
import 'sources/webdav/webdav_playback_media_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ThemePreferences? themePreferences;
  var initialAccent = SoundColors.defaultAccentPreset;
  try {
    themePreferences = await ThemePreferences.load();
    initialAccent = themePreferences.selectedPreset;
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'sound theme preferences',
        context: ErrorDescription('while preloading the selected accent color'),
      ),
    );
  }
  initialAccent.apply();

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
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.soundplayer.sound_player.audio',
      androidNotificationChannelName: '音乐播放',
      androidNotificationChannelDescription: '播放控制和当前歌曲信息',
      androidNotificationIcon: 'drawable/ic_stat_sound',
      notificationColor: initialAccent.accent,
      androidNotificationOngoing: false,
      // OriginOS occasionally treats taps near a media action as a tap on the
      // notification body. Keep the card passive so a slightly imprecise tap
      // can never pull the app to the foreground.
      androidNotificationClickStartsActivity: false,
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
  final playbackSessionStore = await _createPlaybackSessionStore();
  final initialPlaybackSession = await playbackSessionStore.load();

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
      sessionStore: playbackSessionStore,
      initialSession: initialPlaybackSession,
      initialThemePreferences: themePreferences,
      sessionIsPreloaded: true,
      audioHandler: audioHandler,
      webDavCache: cache,
    ),
  );

  if (!kIsWeb && Platform.isMacOS) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_dismissMacOSLaunchScreen());
    });
  }
}

Future<PlaybackSessionStore> _createPlaybackSessionStore() async {
  try {
    return await PlaybackSessionStore.create();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'sound playback session',
        context: ErrorDescription('while creating the session store'),
      ),
    );
    return PlaybackSessionStore.memory();
  }
}

const _macOSLaunchScreenChannel = MethodChannel(
  'com.soundplayer.sound_player/launch_screen',
);

Future<void> _dismissMacOSLaunchScreen() async {
  try {
    await _macOSLaunchScreenChannel.invokeMethod<void>('hide');
  } on MissingPluginException {
    // A custom embedder is allowed to omit the native launch overlay.
  } on PlatformException catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'native launch screen',
        context: ErrorDescription('while dismissing the macOS launch screen'),
      ),
    );
  }
}
