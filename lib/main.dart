import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app/sound_app.dart';
import 'app/kaiting_launch_screen.dart';
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

  SoundColors.defaultAccentPreset.apply();

  // Android already owns the launch surface through the system SplashScreen
  // API. Keep that one surface visible until initialization completes so the
  // first Flutter frame is the ready app shell, not a second splash screen.
  if (!kIsWeb && Platform.isAndroid) {
    final result = await _initializeKaiting();
    runApp(_readyKaitingApp(result));
    return;
  }

  // Other targets hand their native window off to the shared Flutter launch
  // surface while slower initialization continues in the background.
  runApp(const _KaitingBootstrap());

  if (!kIsWeb && Platform.isMacOS) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_dismissMacOSLaunchScreen());
    });
  }
}

class _KaitingBootstrap extends StatefulWidget {
  const _KaitingBootstrap();

  @override
  State<_KaitingBootstrap> createState() => _KaitingBootstrapState();
}

class _KaitingBootstrapState extends State<_KaitingBootstrap> {
  late final Future<_KaitingBootstrapResult> _initialization =
      _initializeKaiting();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_KaitingBootstrapResult>(
      future: _initialization,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) return const KaitingLaunchApp();
        return _readyKaitingApp(result);
      },
    );
  }
}

Widget _readyKaitingApp(_KaitingBootstrapResult result) {
  return SoundApp(
    engine: JustAudioPlaybackEngine(
      mediaProviders: PlaybackMediaProviderRegistry([
        WebDavPlaybackMediaProvider(cache: result.cache),
        const DirectPlaybackMediaProvider(),
      ]),
    ),
    repository: result.libraryRepository,
    initialCatalog: result.initialCatalog,
    ownsRepository: true,
    sessionStore: result.playbackSessionStore,
    initialSession: result.initialPlaybackSession,
    initialThemePreferences: result.themePreferences,
    sessionIsPreloaded: true,
    audioHandler: result.audioHandler,
    webDavCache: result.cache,
  );
}

Future<_KaitingBootstrapResult> _initializeKaiting() async {
  ThemePreferences? themePreferences;
  var initialAccent = SoundColors.defaultAccentPreset;
  try {
    themePreferences = await ThemePreferences.load();
    initialAccent = themePreferences.selectedAccentPreset;
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
      androidNotificationChannelId: 'com.kaiting.player.audio',
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

  return _KaitingBootstrapResult(
    themePreferences: themePreferences,
    libraryRepository: libraryRepository,
    initialCatalog: initialCatalog,
    audioHandler: audioHandler,
    cache: cache,
    playbackSessionStore: playbackSessionStore,
    initialPlaybackSession: initialPlaybackSession,
  );
}

class _KaitingBootstrapResult {
  const _KaitingBootstrapResult({
    required this.themePreferences,
    required this.libraryRepository,
    required this.initialCatalog,
    required this.audioHandler,
    required this.cache,
    required this.playbackSessionStore,
    required this.initialPlaybackSession,
  });

  final ThemePreferences? themePreferences;
  final DriftLibraryRepository libraryRepository;
  final LibraryCatalogSnapshot? initialCatalog;
  final SoundAudioHandler audioHandler;
  final WebDavCache? cache;
  final PlaybackSessionStore playbackSessionStore;
  final PlaybackSession? initialPlaybackSession;
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
  'com.kaiting.player/launch_screen',
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
