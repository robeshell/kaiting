import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/sound_theme.dart';
import '../domain/library_models.dart';
import '../library/library_repository.dart';
import '../playback/playback_controller.dart';
import '../playback/playback_engine.dart';
import '../playback/playback_media_provider.dart';
import '../playback/playback_session.dart';
import '../playback/sound_audio_handler.dart';
import '../presentation/app_shell.dart';
import '../presentation/controllers/library_catalog_controller.dart';
import '../sources/webdav/webdav_cache.dart';

class SoundApp extends StatefulWidget {
  const SoundApp({
    required this.engine,
    this.repository,
    this.initialCatalog,
    this.ownsRepository = false,
    this.sessionStore,
    this.audioHandler,
    this.webDavCache,
    this.enableFirstRunGuide,
    super.key,
  });

  final PlaybackEngine engine;
  final LibraryRepository? repository;
  final LibraryCatalogSnapshot? initialCatalog;
  final bool ownsRepository;
  final PlaybackSessionStore? sessionStore;
  final SoundAudioHandler? audioHandler;
  final WebDavCache? webDavCache;
  final bool? enableFirstRunGuide;

  @override
  State<SoundApp> createState() => _SoundAppState();
}

class _SoundAppState extends State<SoundApp> with WidgetsBindingObserver {
  static const _sessionSaveInterval = Duration(seconds: 2);

  static const _validationMedia = String.fromEnvironment(
    'SOUND_VALIDATION_MEDIA',
  );
  static const _validationSeekMs = int.fromEnvironment(
    'SOUND_VALIDATION_SEEK_MS',
    defaultValue: -1,
  );
  static const _validationUsername = String.fromEnvironment(
    'SOUND_VALIDATION_USERNAME',
  );
  static const _validationPassword = String.fromEnvironment(
    'SOUND_VALIDATION_PASSWORD',
  );

  late final PlaybackEngine _engine;
  SoundPlaybackController? _playback;
  PlaybackSessionStore? _sessionStore;
  Timer? _sessionSaveTimer;
  DateTime? _lastSessionSaveStartedAt;
  Future<void> _writeTail = Future<void>.value();
  bool _sessionDirty = false;
  bool _saveInProgress = false;
  bool _forceSaveAfterCurrent = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = widget.engine;
    unawaited(_bootstrapPlayback());
  }

  Future<void> _bootstrapPlayback() async {
    PlaybackSessionStore store;
    try {
      store = widget.sessionStore ?? await PlaybackSessionStore.create();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'sound playback session',
          context: ErrorDescription('while creating the session store'),
        ),
      );
      store = PlaybackSessionStore.memory();
    }
    final session = await store.load();
    if (!mounted) return;

    final playback = SoundPlaybackController(
      engine: _engine,
      initialSession: session,
    );
    playback.addListener(_scheduleSessionSave);
    widget.audioHandler?.attach(playback);
    _sessionStore = store;
    setState(() => _playback = playback);

    if (_validationMedia.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_playback, playback)) {
          unawaited(_startValidationPlayback(playback));
        }
      });
    }
  }

  void _scheduleSessionSave() {
    if (_disposed || _sessionStore == null || _playback == null) return;
    _sessionDirty = true;
    if (_saveInProgress || _sessionSaveTimer != null) return;

    final lastSave = _lastSessionSaveStartedAt;
    if (lastSave == null) {
      unawaited(_flushSession());
      return;
    }
    final elapsed = DateTime.now().difference(lastSave);
    if (elapsed >= _sessionSaveInterval) {
      unawaited(_flushSession());
      return;
    }
    _sessionSaveTimer = Timer(
      _sessionSaveInterval - elapsed,
      () => unawaited(_flushSession()),
    );
  }

  Future<void> _flushSession({bool force = false}) async {
    _sessionSaveTimer?.cancel();
    _sessionSaveTimer = null;
    final store = _sessionStore;
    final playback = _playback;
    if (store == null || playback == null || _disposed) return;
    if (_saveInProgress) {
      if (force) _forceSaveAfterCurrent = true;
      return;
    }
    if (!_sessionDirty && !force) return;

    _sessionDirty = false;
    _saveInProgress = true;
    _lastSessionSaveStartedAt = DateTime.now();
    final snapshot = playback.sessionSnapshot;
    try {
      await _enqueueSnapshot(store, snapshot);
    } finally {
      _saveInProgress = false;
      if (!_disposed) {
        if (_forceSaveAfterCurrent) {
          _forceSaveAfterCurrent = false;
          _sessionDirty = true;
          unawaited(_flushSession(force: true));
        } else if (_sessionDirty) {
          _scheduleSessionSave();
        }
      }
    }
  }

  Future<void> _enqueueSnapshot(
    PlaybackSessionStore store,
    PlaybackSession snapshot,
  ) {
    _writeTail = _writeTail.then((_) {
      return snapshot.queue.isEmpty ? store.clear() : store.save(snapshot);
    });
    return _writeTail;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_flushSession(force: true));
    }
  }

  Future<void> _startValidationPlayback(
    SoundPlaybackController playback,
  ) async {
    final validationMedia = await _resolvedValidationMedia();
    final uri = Uri.tryParse(validationMedia);
    final isRemote = uri?.hasScheme == true && uri?.scheme != 'file';
    final filename = isRemote
        ? uri!.pathSegments.lastOrNull ?? '验证音频'
        : validationMedia.split('/').last;
    final track = Track(
      id: 'startup-validation:${validationMedia.hashCode}',
      title: filename,
      artist: isRemote ? '远程验证' : '本地验证',
      albumTitle: '播放验证',
      duration: Duration.zero,
      source: isRemote ? SourceKind.webDav : SourceKind.local,
      mediaUri: validationMedia,
    );
    if (isRemote) {
      playback.updatePlaybackMediaAccess([
        PlaybackMediaAccessRule(
          baseUri: uri!.replace(path: '/'),
          headers: _validationHeaders,
        ),
      ]);
    }
    await playback.playTrack(track, queue: [track]);
    if (_validationSeekMs < 0) return;

    await Future<void>.delayed(const Duration(seconds: 2));
    for (var attempt = 0; attempt < 50; attempt++) {
      if (!mounted ||
          !identical(_playback, playback) ||
          playback.snapshot.duration > Duration.zero) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (mounted &&
        identical(_playback, playback) &&
        playback.snapshot.duration > Duration.zero) {
      await playback.seek(Duration(milliseconds: _validationSeekMs));
    }
  }

  Future<String> _resolvedValidationMedia() async {
    final uri = Uri.tryParse(_validationMedia);
    if (uri?.scheme != 'app-documents') return _validationMedia;
    final documents = await getApplicationDocumentsDirectory();
    return [documents.path, ...uri!.pathSegments].join('/');
  }

  Map<String, String> get _validationHeaders {
    final headers = <String, String>{'Accept': '*/*'};
    if (_validationUsername.isNotEmpty) {
      final token = base64Encode(
        utf8.encode('$_validationUsername:$_validationPassword'),
      );
      headers['Authorization'] = 'Basic $token';
    }
    return headers;
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _sessionSaveTimer?.cancel();
    final playback = _playback;
    final store = _sessionStore;
    if (playback != null && store != null) {
      unawaited(_enqueueSnapshot(store, playback.sessionSnapshot));
      playback.removeListener(_scheduleSessionSave);
    }
    widget.audioHandler?.detach();
    playback?.dispose();
    _engine.dispose();
    if (widget.ownsRepository) unawaited(widget.repository?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = _playback;
    return MaterialApp(
      title: 'Reverie',
      debugShowCheckedModeBanner: false,
      theme: SoundTheme.light,
      darkTheme: SoundTheme.dark,
      themeMode: ThemeMode.light,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: playback == null
          ? const _PlaybackBootstrapScreen()
          : AppShell(
              playback: playback,
              libraryRepository: widget.repository,
              initialCatalog: widget.initialCatalog,
              webDavCache: widget.webDavCache,
              enableFirstRunGuide:
                  widget.enableFirstRunGuide ?? widget.repository == null,
            ),
    );
  }
}

class _PlaybackBootstrapScreen extends StatelessWidget {
  const _PlaybackBootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
