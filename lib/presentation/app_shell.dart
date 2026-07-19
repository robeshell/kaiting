import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_failure.dart';
import '../core/now_playing_style.dart';
import '../core/platform_window.dart';
import '../core/sound_theme.dart';
import '../domain/library_models.dart';
import '../library/library_repository.dart';
import '../library/library_records.dart';
import '../library/persistence/drift_library_repository.dart';
import '../library/scanning/local_library_scanner.dart';
import '../library/scanning/local_media_catalog_factory.dart';
import '../playback/playback_controller.dart';
import '../playback/playback_media_provider.dart';
import '../playback/sleep_timer_controller.dart';
import '../playback/sound_audio_handler.dart';
import '../sources/local/local_directory_access_factory.dart';
import '../sources/local/local_source_service.dart';
import '../sources/webdav/webdav_connection_service.dart';
import '../sources/webdav/webdav_cache.dart';
import '../sources/webdav/webdav_offline_media_provider.dart';
import 'controllers/app_diagnostics_controller.dart';
import 'controllers/library_catalog_controller.dart';
import 'controllers/library_search_controller.dart';
import 'controllers/library_user_state_controller.dart';
import 'controllers/offline_download_controller.dart';
import 'controllers/playback_recovery_controller.dart';
import 'screens/album_detail_screen.dart';
import 'screens/first_run_dialog.dart';
import 'screens/library_collection_screen.dart';
import 'screens/library_screen.dart';
import 'screens/library_user_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/mini_player.dart';
import 'widgets/playback_queue_sheet.dart';
import 'widgets/sound_components.dart';

enum AppSection { library, search, settings }

/// Presents application-wide failures above the root Navigator, including
/// modal routes and their barriers.
class AppFailureOverlayController extends ChangeNotifier {
  _AppFailurePresentation? _presentation;

  void _show(_AppFailurePresentation presentation) {
    _presentation = presentation;
    notifyListeners();
  }

  void _hide() {
    if (_presentation == null) return;
    _presentation = null;
    notifyListeners();
  }
}

class AppFailureOverlayHost extends StatelessWidget {
  const AppFailureOverlayHost({
    required this.controller,
    required this.child,
    super.key,
  });

  final AppFailureOverlayController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final presentation = controller._presentation;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (presentation != null)
              Positioned.fill(
                child: Overlay(
                  key: ValueKey(
                    'app-failure-overlay-'
                    '${presentation.event.id}-${presentation.busy}',
                  ),
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => Material(
                        type: MaterialType.transparency,
                        child: _AppFailureOverlayLayer(
                          presentation: presentation,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.playback,
    this.audioHandler,
    this.libraryRepository,
    this.initialCatalog,
    this.webDavCache,
    this.enableFirstRunGuide = false,
    this.accentPreset,
    this.onAccentChanged,
    this.skinPreset,
    this.onSkinChanged,
    this.nowPlayingStyle = NowPlayingStyle.classic,
    this.onNowPlayingStyleChanged,
    this.failureOverlayController,
    super.key,
  });

  final SoundPlaybackController playback;
  final SoundAudioHandler? audioHandler;
  final LibraryRepository? libraryRepository;
  final LibraryCatalogSnapshot? initialCatalog;
  final WebDavCache? webDavCache;
  final bool enableFirstRunGuide;
  final AccentPreset? accentPreset;
  final ValueChanged<AccentPreset>? onAccentChanged;
  final SoundSkinPreset? skinPreset;
  final ValueChanged<SoundSkinPreset>? onSkinChanged;
  final NowPlayingStyle nowPlayingStyle;
  final ValueChanged<NowPlayingStyle>? onNowPlayingStyleChanged;
  final AppFailureOverlayController? failureOverlayController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  AppSection _section = AppSection.library;
  LibraryBrowseMode _libraryBrowseMode = LibraryBrowseMode.albums;
  LibraryUserBrowseMode? _libraryUserMode;
  int? _selectedPlaylistId;
  Album? _selectedAlbum;
  LibraryCollection? _selectedCollection;
  SettingsDestination _settingsDestination = SettingsDestination.overview;
  int _settingsNavigationRevision = 0;
  late final LibraryRepository _libraryRepository;
  late final bool _ownsLibraryRepository;
  late final LibraryCatalogController _libraryCatalog;
  late final LibrarySearchController _librarySearch;
  late final LibraryUserStateController _libraryUserState;
  late final FocusNode _keyboardFocusNode;
  late final FocusNode _searchFocusNode;
  late final WebDavConnectionService _webDavService;
  late final AppDiagnosticsController _diagnostics;
  late final PlaybackRecoveryController _playbackRecovery;
  late final SleepTimerController _sleepTimer;
  OfflineDownloadController? _offline;
  WebDavOfflineMediaProvider? _webDavOfflineProvider;
  late final StreamSubscription<List<WebDavConnectionRecord>>
  _webDavConnectionSubscription;
  late final StreamSubscription<List<LibrarySourceRecord>>
  _sourceHealthSubscription;
  late final StreamSubscription<Track> _trackStartedSubscription;
  LocalSourceService? _localSourceService;
  LocalLibraryScanner? _localLibraryScanner;
  final Map<String, String> _sourceProblemSignatures = {};
  final Map<String, String> _downloadProblemSignatures = {};
  String? _lastCatalogError;
  bool _firstRunCheckStarted = false;
  bool _firstRunDialogShown = false;
  late final AnimationController _nowPlayingExpansion;
  bool _mobileNowPlayingPresented = false;
  bool _dragStartedExpanded = false;

  @override
  void initState() {
    super.initState();
    _nowPlayingExpansion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _ownsLibraryRepository = widget.libraryRepository == null;
    _libraryRepository =
        widget.libraryRepository ?? DriftLibraryRepository.defaults();
    _libraryCatalog = LibraryCatalogController(
      repository: _libraryRepository,
      initialSnapshot: widget.initialCatalog,
    );
    _librarySearch = LibrarySearchController(catalog: _libraryCatalog);
    _keyboardFocusNode = FocusNode(
      debugLabel: 'Reverie application keyboard shortcuts',
    );
    _searchFocusNode = FocusNode(
      debugLabel: 'Library search',
      onKeyEvent: _handleSearchFocusKeyEvent,
    );
    _libraryUserState = LibraryUserStateController(
      repository: _libraryRepository,
      catalog: _libraryCatalog,
    );
    widget.audioHandler?.attachFavoriteController(_libraryUserState);
    _trackStartedSubscription = widget.playback.trackStarted.listen(
      (track) => unawaited(_libraryUserState.recordTrackStarted(track)),
    );
    _webDavService = WebDavConnectionService(repository: _libraryRepository);
    _diagnostics = AppDiagnosticsController();
    _sleepTimer = SleepTimerController(widget.playback);
    _playbackRecovery = PlaybackRecoveryController(
      widget.playback,
      _diagnostics,
      beforeRetry: _preparePlaybackRetry,
    );
    _diagnostics.addListener(_syncFailureOverlay);
    _playbackRecovery.addListener(_syncFailureOverlay);
    _syncFailureOverlay();
    final cache = widget.webDavCache;
    if (cache != null) {
      _webDavOfflineProvider = WebDavOfflineMediaProvider(cache: cache);
      _offline = OfflineDownloadController(
        providers: [_webDavOfflineProvider!],
      );
      _offline!.updateLibraryTracks(
        _libraryCatalog.albums.expand((album) => album.tracks),
      );
      _offline!.addListener(_observeOfflineFailures);
      unawaited(_offline!.refresh());
    }
    // Resolve security-scoped bookmarks at startup so that local files are
    // playable without the user first opening the source-settings screen.
    unawaited(_sources.restoreLocalFolders());
    // Reactively load WebDAV auth headers so remote tracks are playable.
    _webDavConnectionSubscription = _webDavService.watchConnections().listen((
      _,
    ) {
      unawaited(_refreshWebDavAuthHeaders());
    });
    _sourceHealthSubscription = _libraryRepository.watchSources().listen(
      _observeSourceHealth,
      onError: (Object error) => _diagnostics.record(
        area: DiagnosticArea.library,
        failure: AppFailure.from(error),
        context: '读取音乐来源状态',
      ),
    );
    unawaited(_refreshWebDavAuthHeaders());
    // Keep the selected album in sync when the catalog refreshes its objects.
    _libraryCatalog.addListener(_syncLibrarySelection);
  }

  void _syncLibrarySelection() {
    _offline?.updateLibraryTracks(
      _libraryCatalog.albums.expand((album) => album.tracks),
    );
    final selectedAlbum = _selectedAlbum;
    final selectedCollection = _selectedCollection;
    final freshAlbum = selectedAlbum == null
        ? null
        : _libraryCatalog.albums
              .where((album) => album.id == selectedAlbum.id)
              .firstOrNull;
    final freshCollection = selectedCollection == null
        ? null
        : switch (selectedCollection.kind) {
            LibraryCollectionKind.artist => buildArtistCollections(
              _libraryCatalog.albums,
            ),
            LibraryCollectionKind.genre => buildGenreCollections(
              _libraryCatalog.albums,
            ),
          }.where((item) => item.id == selectedCollection.id).firstOrNull;
    final albumChanged =
        selectedAlbum != null && !identical(freshAlbum, selectedAlbum);
    final collectionChanged =
        selectedCollection != null &&
        !identical(freshCollection, selectedCollection);
    if (albumChanged || collectionChanged) {
      setState(() {
        if (albumChanged) _selectedAlbum = freshAlbum;
        if (collectionChanged) _selectedCollection = freshCollection;
      });
    }
    final catalogError = _libraryCatalog.errorMessage;
    if (_libraryCatalog.status == LibraryCatalogStatus.error &&
        catalogError != null &&
        catalogError != _lastCatalogError) {
      _lastCatalogError = catalogError;
      _diagnostics.record(
        area: DiagnosticArea.library,
        failure: AppFailure.fromMessage(catalogError),
        context: '刷新资料库',
      );
    } else if (_libraryCatalog.status == LibraryCatalogStatus.ready) {
      _lastCatalogError = null;
      unawaited(_maybeShowFirstRun());
    }
  }

  void _observeSourceHealth(List<LibrarySourceRecord> sources) {
    for (final source in sources) {
      final problem = switch (source.status) {
        LibrarySourceStatus.permissionRequired =>
          source.lastError ?? '来源权限或登录凭据已失效',
        LibrarySourceStatus.unavailable => source.lastError ?? '音乐来源暂时不可用',
        LibrarySourceStatus.error => source.lastError ?? '音乐来源发生错误',
        _ => null,
      };
      if (problem == null) {
        _sourceProblemSignatures.remove(source.id);
        continue;
      }
      final signature = '${source.status.name}:$problem';
      if (_sourceProblemSignatures[source.id] == signature) continue;
      _sourceProblemSignatures[source.id] = signature;
      _diagnostics.record(
        area: DiagnosticArea.source,
        failure: AppFailure.fromMessage(problem),
        context: source.displayName,
      );
    }
  }

  void _observeOfflineFailures() {
    final offline = _offline;
    if (offline == null) return;
    for (final item in offline.offlineItems) {
      final error = item.task?.error;
      if (item.task?.state != OfflineDownloadTaskState.failed ||
          error == null) {
        _downloadProblemSignatures.remove(item.reference.storageKey);
        continue;
      }
      if (_downloadProblemSignatures[item.reference.storageKey] == error) {
        continue;
      }
      _downloadProblemSignatures[item.reference.storageKey] = error;
      _diagnostics.record(
        area: DiagnosticArea.download,
        failure: AppFailure.fromMessage(error),
        context: '${item.title} · ${item.providerLabel}',
      );
    }
  }

  Future<void> _maybeShowFirstRun() async {
    if (!widget.enableFirstRunGuide ||
        _firstRunCheckStarted ||
        _firstRunDialogShown ||
        _libraryCatalog.tracks.isNotEmpty) {
      return;
    }
    _firstRunCheckStarted = true;
    late final List<LibrarySourceRecord> sources;
    try {
      sources = await _libraryRepository.getSources();
    } catch (error) {
      _firstRunCheckStarted = false;
      _diagnostics.record(
        area: DiagnosticArea.library,
        failure: AppFailure.from(error),
        context: '检查首次使用状态',
      );
      return;
    }
    if (!mounted || sources.isNotEmpty || _libraryCatalog.tracks.isNotEmpty) {
      return;
    }
    _firstRunDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final manageSources = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const FirstRunDialog(),
      );
      if (mounted && manageSources == true) _openSourceSettings();
    });
  }

  Future<void> _refreshWebDavAuthHeaders() async {
    final connections = await _webDavService.listConnections();
    final headers = <String, Map<String, String>>{};
    final allowBadCertificateUrls = <String>{};
    for (final c in connections) {
      if (!c.isAvailable) continue;
      final creds = await _webDavService.readCredentials(c.id);
      if (creds == null) continue;
      headers[c.url] = creds.isEmpty
          ? const {}
          : {'Authorization': creds.basicHeaderValue};
      if (c.allowBadCertificate) allowBadCertificateUrls.add(c.url);
    }
    if (!mounted) return;
    widget.playback.updatePlaybackMediaAccess([
      for (final entry in headers.entries)
        if (Uri.tryParse(entry.key) case final baseUri?)
          PlaybackMediaAccessRule(
            baseUri: baseUri,
            headers: entry.value,
            allowBadCertificate: allowBadCertificateUrls.contains(entry.key),
          ),
    ]);
    _webDavOfflineProvider?.updateAccess(
      authHeaders: headers,
      allowBadCertificateUrls: allowBadCertificateUrls,
    );
  }

  Future<void> _preparePlaybackRetry() async {
    final mediaUri = widget.playback.displayTrack?.mediaUri;
    final matches = await _webDavService.connectionsForMediaUri(mediaUri);
    for (final connection in matches) {
      final result = await _webDavService.probeConnection(
        connection,
        allowBadCertificate: connection.allowBadCertificate,
      );
      if (result.error != null) {
        throw StateError(result.errorMessage ?? '音乐来源仍不可用');
      }
    }
    await _refreshWebDavAuthHeaders();
  }

  Future<void> _retryUnavailableSources() async {
    final connections = await _webDavService.listConnections();
    var failed = false;
    for (final connection in connections.where((item) => !item.isAvailable)) {
      final result = await _webDavService.probeConnection(
        connection,
        allowBadCertificate: connection.allowBadCertificate,
      );
      failed = failed || result.error != null;
    }
    await _refreshWebDavAuthHeaders();
    if (failed) throw StateError('部分音乐来源仍然不可用');
  }

  Future<void> _retryFailedDownloads() async {
    final offline = _offline;
    if (offline == null) return;
    final failed = offline.offlineItems
        .where((item) => item.canRetry)
        .toList(growable: false);
    Object? lastError;
    for (final item in failed) {
      try {
        await offline.retry(item.reference);
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) throw lastError;
  }

  LocalSourceService get _sources {
    return _localSourceService ??= LocalSourceService(
      repository: _libraryRepository,
      directoryAccess: createLocalDirectoryAccess(),
    );
  }

  LocalLibraryScanner get _scanner {
    return _localLibraryScanner ??= LocalLibraryScanner(
      repository: _libraryRepository,
      catalog: createLocalMediaCatalog(),
    );
  }

  void _selectSection(AppSection section) {
    setState(() {
      _section = section;
      if (section == AppSection.settings) {
        _settingsDestination = SettingsDestination.overview;
        _settingsNavigationRevision++;
      }
      _selectedAlbum = null;
      _selectedCollection = null;
      _libraryUserMode = null;
      _selectedPlaylistId = null;
    });
  }

  void _openSourceSettings() {
    setState(() {
      _section = AppSection.settings;
      _settingsDestination = SettingsDestination.sources;
      _settingsNavigationRevision++;
      _selectedAlbum = null;
      _selectedCollection = null;
      _libraryUserMode = null;
      _selectedPlaylistId = null;
    });
  }

  void _openOfflineSettings() {
    if (_offline == null) return;
    setState(() {
      _section = AppSection.settings;
      _settingsDestination = SettingsDestination.offline;
      _settingsNavigationRevision++;
      _selectedAlbum = null;
      _selectedCollection = null;
      _libraryUserMode = null;
      _selectedPlaylistId = null;
    });
  }

  Future<void> _handleFailureAction(DiagnosticEvent event) async {
    switch (event.failure.action) {
      case AppFailureAction.retry:
        try {
          if (event.area == DiagnosticArea.playback) {
            await _playbackRecovery.retryNow();
          } else if (event.area == DiagnosticArea.download) {
            await _retryFailedDownloads();
          } else {
            await _retryUnavailableSources();
          }
          _diagnostics.dismissActive();
        } catch (error) {
          _diagnostics.record(
            area: event.area,
            failure: AppFailure.from(error),
            context: '手动恢复',
          );
        }
        return;
      case AppFailureAction.editSource || AppFailureAction.locateFile:
        _diagnostics.dismissActive();
        _openSourceSettings();
        return;
      case AppFailureAction.manageStorage:
        _diagnostics.dismissActive();
        _openOfflineSettings();
        return;
      case AppFailureAction.none:
        _diagnostics.dismissActive();
        return;
    }
  }

  void _syncFailureOverlay() {
    final controller = widget.failureOverlayController;
    if (controller == null) return;
    final event = _diagnostics.activeEvent;
    if (event == null) {
      controller._hide();
      return;
    }
    controller._show(_failurePresentation(event));
  }

  _AppFailurePresentation _failurePresentation(DiagnosticEvent event) {
    return _AppFailurePresentation(
      event: event,
      busy: _playbackRecovery.isRetrying,
      onAction: event.failure.action == AppFailureAction.none
          ? null
          : () => unawaited(_handleFailureAction(event)),
      onDismiss: _diagnostics.dismissActive,
    );
  }

  void _selectLibraryMode(LibraryBrowseMode mode) {
    setState(() {
      _section = AppSection.library;
      _libraryBrowseMode = mode;
      _libraryUserMode = null;
      _selectedPlaylistId = null;
      _selectedAlbum = null;
      _selectedCollection = null;
    });
  }

  void _selectLibraryUserMode(LibraryUserBrowseMode mode) {
    setState(() {
      _section = AppSection.library;
      _libraryUserMode = mode;
      _selectedPlaylistId = null;
      _selectedAlbum = null;
      _selectedCollection = null;
    });
  }

  void _openNowPlaying() {
    if (widget.playback.displayTrack == null) return;
    if (context.soundUsesMobileShell) {
      _expandMobileNowPlaying();
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            NowPlayingScreen(
              playback: widget.playback,
              userState: _libraryUserState,
              style: widget.nowPlayingStyle,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    );
  }

  void _expandMobileNowPlaying() {
    if (!_mobileNowPlayingPresented) {
      setState(() => _mobileNowPlayingPresented = true);
    }
    unawaited(
      _nowPlayingExpansion.animateTo(
        1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _collapseMobileNowPlaying() async {
    await _nowPlayingExpansion.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (mounted && _mobileNowPlayingPresented) {
      setState(() => _mobileNowPlayingPresented = false);
    }
  }

  void _handleNowPlayingDragStart(DragStartDetails details) {
    _nowPlayingExpansion.stop();
    _dragStartedExpanded = _nowPlayingExpansion.value > 0.5;
    if (!_mobileNowPlayingPresented) {
      setState(() => _mobileNowPlayingPresented = true);
    }
  }

  void _handleNowPlayingDragUpdate(DragUpdateDetails details) {
    final height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return;
    _nowPlayingExpansion.value =
        (_nowPlayingExpansion.value - details.delta.dy / height).clamp(0, 1);
  }

  void _handleNowPlayingDragEnd(DragEndDetails details) {
    _settleNowPlayingDrag(details.primaryVelocity ?? 0);
  }

  void _handleNowPlayingDragCancel() {
    _settleNowPlayingDrag(0);
  }

  void _settleNowPlayingDrag(double velocity) {
    if (velocity <= -520) {
      _expandMobileNowPlaying();
      return;
    }
    if (velocity >= 520) {
      unawaited(_collapseMobileNowPlaying());
      return;
    }
    final shouldExpand = _dragStartedExpanded
        ? _nowPlayingExpansion.value >= 0.9
        : _nowPlayingExpansion.value >= 0.18;
    if (shouldExpand) {
      _expandMobileNowPlaying();
    } else {
      unawaited(_collapseMobileNowPlaying());
    }
  }

  void _openAlbum(Album album) {
    setState(() {
      _selectedAlbum =
          _libraryCatalog.albums
              .where((candidate) => candidate.id == album.id)
              .firstOrNull ??
          album;
    });
  }

  void _openCollection(LibraryCollection collection) {
    setState(() {
      _selectedAlbum = null;
      _selectedCollection = collection;
    });
  }

  void _openQueue() {
    if (widget.playback.queue.isEmpty) return;
    showPlaybackQueueSheet(context, widget.playback);
  }

  KeyEventResult _handleKeyboardEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final primaryModifier = keyboard.isMetaPressed || keyboard.isControlPressed;

    if (primaryModifier && key == LogicalKeyboardKey.keyF) {
      _openSearchFromKeyboard();
      return KeyEventResult.handled;
    }
    if (primaryModifier && key == LogicalKeyboardKey.digit1) {
      _selectLibraryMode(_libraryBrowseMode);
      _restoreApplicationFocus();
      return KeyEventResult.handled;
    }
    if (primaryModifier && key == LogicalKeyboardKey.digit2) {
      _openSearchFromKeyboard();
      return KeyEventResult.handled;
    }
    if (primaryModifier && key == LogicalKeyboardKey.digit3) {
      _selectSection(AppSection.settings);
      _restoreApplicationFocus();
      return KeyEventResult.handled;
    }
    if (primaryModifier && key == LogicalKeyboardKey.slash) {
      _showKeyboardShortcuts();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_isTextInputFocused && _section == AppSection.search) {
        if (_librarySearch.query.isNotEmpty) {
          _librarySearch.clear();
        } else {
          FocusManager.instance.primaryFocus?.unfocus();
          _navigateBackWithinApp();
        }
        return KeyEventResult.handled;
      }
      return _navigateBackWithinApp()
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    if (_isTextInputFocused) return KeyEventResult.ignored;
    if (primaryModifier && key == LogicalKeyboardKey.arrowRight) {
      unawaited(widget.playback.next());
      return KeyEventResult.handled;
    }
    if (primaryModifier && key == LogicalKeyboardKey.arrowLeft) {
      unawaited(widget.playback.previous());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSearchFocusKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (_librarySearch.query.isNotEmpty) {
      _librarySearch.clear();
    } else {
      node.unfocus();
      _navigateBackWithinApp();
    }
    return KeyEventResult.handled;
  }

  bool get _isTextInputFocused => _isTextEditingFocusActive();

  void _openSearchFromKeyboard() {
    _selectSection(AppSection.search);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _restoreApplicationFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  bool _navigateBackWithinApp() {
    if (_mobileNowPlayingPresented) {
      unawaited(_collapseMobileNowPlaying());
      return true;
    }
    if (_selectedAlbum != null) {
      setState(() => _selectedAlbum = null);
      return true;
    }
    if (_selectedCollection != null) {
      setState(() => _selectedCollection = null);
      return true;
    }
    if (_selectedPlaylistId != null) {
      setState(() => _selectedPlaylistId = null);
      return true;
    }
    if (_libraryUserMode != null) {
      _selectLibraryMode(_libraryBrowseMode);
      _restoreApplicationFocus();
      return true;
    }
    if (_section != AppSection.library) {
      _selectLibraryMode(_libraryBrowseMode);
      _restoreApplicationFocus();
      return true;
    }
    return false;
  }

  void _showKeyboardShortcuts() {
    showDialog<void>(
      context: context,
      builder: (context) => const _KeyboardShortcutDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _handleKeyboardEvent,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Android can briefly report a zero-sized surface while attaching a
            // cold-started Flutter view. Sliver grids require positive extents,
            // so wait for the first usable viewport instead of laying out content.
            if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
              return const SizedBox.shrink();
            }
            // Foldable inner displays use a medium content density while
            // retaining touch-first navigation. Only sufficiently wide tablet
            // windows and native desktop platforms promote to the sidebar.
            final desktop = !context.soundUsesMobileShell;
            final sidebarWidth = context.soundSidebarWidth;
            final mobileContentIdentity = _selectedAlbum != null
                ? 'album:${_selectedAlbum!.id}'
                : _selectedCollection != null
                ? 'collection:${_selectedCollection!.kind.name}:'
                      '${_selectedCollection!.id}'
                : 'root';
            final immersiveMobileContent =
                context.soundIsCompact &&
                (_selectedAlbum != null ||
                    _selectedCollection?.kind == LibraryCollectionKind.artist);
            final content = _selectedAlbum != null
                ? AlbumDetailScreen(
                    album: _selectedAlbum!,
                    playback: widget.playback,
                    userState: _libraryUserState,
                    offline: _offline,
                    onBack: () => setState(() => _selectedAlbum = null),
                  )
                : _selectedCollection != null
                ? LibraryCollectionScreen(
                    collection: _selectedCollection!,
                    playback: widget.playback,
                    userState: _libraryUserState,
                    onBack: () => setState(() => _selectedCollection = null),
                    onOpenAlbum: _openAlbum,
                  )
                : switch (_section) {
                    AppSection.library =>
                      _libraryUserMode == null
                          ? LibraryScreen(
                              catalog: _libraryCatalog,
                              userState: _libraryUserState,
                              mode: _libraryBrowseMode,
                              onModeChanged: _selectLibraryMode,
                              onOpenAlbum: _openAlbum,
                              onOpenCollection: _openCollection,
                              onPlayTrack: (track, queue) => unawaited(
                                widget.playback.playTrack(track, queue: queue),
                              ),
                              onOpenUserMode: _selectLibraryUserMode,
                              onManageSources: _openSourceSettings,
                            )
                          : LibraryUserScreen(
                              mode: _libraryUserMode!,
                              catalog: _libraryCatalog,
                              userState: _libraryUserState,
                              playback: widget.playback,
                              onModeChanged: _selectLibraryUserMode,
                              onBack: () =>
                                  _selectLibraryMode(_libraryBrowseMode),
                              onOpenAlbum: _openAlbum,
                              selectedPlaylistId: _selectedPlaylistId,
                              onSelectedPlaylistChanged: (playlistId) =>
                                  setState(
                                    () => _selectedPlaylistId = playlistId,
                                  ),
                            ),
                    AppSection.search => SearchScreen(
                      catalog: _libraryCatalog,
                      search: _librarySearch,
                      playback: widget.playback,
                      userState: _libraryUserState,
                      onOpenAlbum: _openAlbum,
                      focusNode: _searchFocusNode,
                    ),
                    AppSection.settings => SettingsScreen(
                      key: ValueKey(
                        'settings-screen-$_settingsNavigationRevision',
                      ),
                      playback: widget.playback,
                      localSources: _sources,
                      scanner: _scanner,
                      webDavService: _webDavService,
                      offline: _offline,
                      sleepTimer: _sleepTimer,
                      diagnostics: _diagnostics,
                      onShowKeyboardShortcuts: _showKeyboardShortcuts,
                      initialDestination: _settingsDestination,
                      accentPreset:
                          widget.accentPreset ??
                          SoundColors.defaultAccentPreset,
                      onAccentChanged: widget.onAccentChanged ?? (_) {},
                      skinPreset: widget.skinPreset ?? SoundSkins.defaultPreset,
                      onSkinChanged: widget.onSkinChanged ?? (_) {},
                      nowPlayingStyle: widget.nowPlayingStyle,
                      onNowPlayingStyleChanged:
                          widget.onNowPlayingStyleChanged ?? (_) {},
                    ),
                  };

            final shell = Scaffold(
              extendBody: !desktop,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).scaffoldBackgroundColor,
                            context.soundGlass.canvasHighlight,
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                          ],
                          stops: const [0, 0.46, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: desktop
                        ? Row(
                            children: [
                              SizedBox(
                                width: sidebarWidth,
                                child: _Sidebar(
                                  selection: _section,
                                  libraryMode: _libraryBrowseMode,
                                  userMode: _libraryUserMode,
                                  onSelectLibraryMode: _selectLibraryMode,
                                  onSelectUserMode: _selectLibraryUserMode,
                                ),
                              ),
                              Expanded(
                                child: SafeArea(
                                  left: false,
                                  right: false,
                                  bottom: false,
                                  minimum: EdgeInsets.only(
                                    top: context.soundTitlebarInset,
                                  ),
                                  child: content,
                                ),
                              ),
                            ],
                          )
                        : KeyedSubtree(
                            key: const ValueKey('mobile-content-safe-area'),
                            child: AnimatedSwitcher(
                              key: const ValueKey(
                                'mobile-detail-page-transition',
                              ),
                              duration: const Duration(milliseconds: 300),
                              reverseDuration: const Duration(
                                milliseconds: 220,
                              ),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.022),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: SafeArea(
                                key: ValueKey(
                                  'mobile-content-$mobileContentIdentity',
                                ),
                                top: !immersiveMobileContent,
                                bottom: false,
                                child: content,
                              ),
                            ),
                          ),
                  ),
                  if (desktop)
                    // macOS paints the search & settings buttons inside the
                    // transparent full-size titlebar alongside the native
                    // traffic-light controls.  Windows renders custom window
                    // controls (minimize / maximize / close) in the same row
                    // so the standard caption buttons can be hidden entirely.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        minimum: EdgeInsets.only(
                          top: defaultTargetPlatform == TargetPlatform.macOS
                              ? 1
                              : 0,
                        ),
                        child: _DesktopTitleBar(
                          selection: _section,
                          onSearch: _openSearchFromKeyboard,
                          onSettings: () => _selectSection(AppSection.settings),
                        ),
                      ),
                    ),
                  if (widget.failureOverlayController == null)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _diagnostics,
                          _playbackRecovery,
                        ]),
                        builder: (context, _) {
                          final event = _diagnostics.activeEvent;
                          if (event == null) {
                            return const IgnorePointer(
                              child: SizedBox.shrink(),
                            );
                          }
                          return _AppFailureOverlayLayer(
                            presentation: _failurePresentation(event),
                          );
                        },
                      ),
                    ),
                ],
              ),
              bottomNavigationBar: desktop
                  ? MiniPlayer(
                      playback: widget.playback,
                      userState: _libraryUserState,
                      compact: false,
                      docked: true,
                      onOpen: _openNowPlaying,
                      onOpenQueue: _openQueue,
                    )
                  : _CompactPlaybackDock(
                      playback: widget.playback,
                      userState: _libraryUserState,
                      selectedIndex: _section.index,
                      onDestinationSelected: (index) =>
                          _selectSection(AppSection.values[index]),
                      onOpenNowPlaying: _openNowPlaying,
                      onOpenQueue: _openQueue,
                    ),
            );
            if (desktop) return shell;
            final handlesInternalBack =
                _mobileNowPlayingPresented ||
                _selectedAlbum != null ||
                _selectedCollection != null ||
                _selectedPlaylistId != null ||
                _libraryUserMode != null;
            return PopScope<void>(
              canPop: !handlesInternalBack,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && handlesInternalBack) {
                  _navigateBackWithinApp();
                }
              },
              child: Stack(
                children: [
                  Positioned.fill(child: shell),
                  if (_mobileNowPlayingPresented)
                    Positioned.fill(
                      child: _MobileNowPlayingOverlay(
                        animation: _nowPlayingExpansion,
                        playback: widget.playback,
                        userState: _libraryUserState,
                        style: widget.nowPlayingStyle,
                        onClose: () => unawaited(_collapseMobileNowPlaying()),
                        onVerticalDragStart: _handleNowPlayingDragStart,
                        onVerticalDragUpdate: _handleNowPlayingDragUpdate,
                        onVerticalDragEnd: _handleNowPlayingDragEnd,
                        onVerticalDragCancel: _handleNowPlayingDragCancel,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ).withPlaybackShortcuts(widget.playback);
  }

  @override
  void dispose() {
    unawaited(_webDavConnectionSubscription.cancel());
    unawaited(_sourceHealthSubscription.cancel());
    unawaited(_trackStartedSubscription.cancel());
    _libraryCatalog.removeListener(_syncLibrarySelection);
    _librarySearch.dispose();
    _keyboardFocusNode.dispose();
    _searchFocusNode.dispose();
    widget.audioHandler?.detachFavoriteController(_libraryUserState);
    _libraryUserState.dispose();
    _offline?.removeListener(_observeOfflineFailures);
    _offline?.dispose();
    _diagnostics.removeListener(_syncFailureOverlay);
    _playbackRecovery.removeListener(_syncFailureOverlay);
    widget.failureOverlayController?._hide();
    _playbackRecovery.dispose();
    _sleepTimer.dispose();
    _diagnostics.dispose();
    _libraryCatalog.dispose();
    _nowPlayingExpansion.dispose();
    if (_ownsLibraryRepository) unawaited(_libraryRepository.close());
    super.dispose();
  }
}

class _MobileNowPlayingOverlay extends StatefulWidget {
  const _MobileNowPlayingOverlay({
    required this.animation,
    required this.playback,
    required this.userState,
    required this.style,
    required this.onClose,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
  });

  final Animation<double> animation;
  final SoundPlaybackController playback;
  final LibraryUserStateController userState;
  final NowPlayingStyle style;
  final VoidCallback onClose;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final GestureDragCancelCallback onVerticalDragCancel;

  @override
  State<_MobileNowPlayingOverlay> createState() =>
      _MobileNowPlayingOverlayState();
}

class _MobileNowPlayingOverlayState extends State<_MobileNowPlayingOverlay> {
  late bool _contentActive;

  @override
  void initState() {
    super.initState();
    _contentActive = widget.animation.status == AnimationStatus.completed;
    widget.animation.addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant _MobileNowPlayingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation) return;
    oldWidget.animation.removeStatusListener(_handleAnimationStatus);
    _contentActive = widget.animation.status == AnimationStatus.completed;
    widget.animation.addStatusListener(_handleAnimationStatus);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    final active = status == AnimationStatus.completed;
    if (_contentActive == active || !mounted) return;
    setState(() => _contentActive = active);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleAnimationStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final progress = widget.animation.value;
        final height = MediaQuery.sizeOf(context).height;
        return IgnorePointer(
          ignoring: progress <= 0,
          child: Transform.translate(
            offset: Offset(0, height * (1 - progress)),
            child: child,
          ),
        );
      },
      child: NowPlayingScreen(
        playback: widget.playback,
        userState: widget.userState,
        style: widget.style,
        isActive: _contentActive,
        onClose: widget.onClose,
        onVerticalDragStart: widget.onVerticalDragStart,
        onVerticalDragUpdate: widget.onVerticalDragUpdate,
        onVerticalDragEnd: widget.onVerticalDragEnd,
        onVerticalDragCancel: widget.onVerticalDragCancel,
      ),
    );
  }
}

class _AppFailurePresentation {
  const _AppFailurePresentation({
    required this.event,
    required this.busy,
    required this.onAction,
    required this.onDismiss,
  });

  final DiagnosticEvent event;
  final bool busy;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;
}

class _AppFailureOverlayLayer extends StatelessWidget {
  const _AppFailureOverlayLayer({required this.presentation});

  final _AppFailurePresentation presentation;

  @override
  Widget build(BuildContext context) {
    final desktop = !context.soundUsesMobileShell;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: context.soundTitlebarInset + 12,
          left: desktop ? context.soundSidebarWidth + 24 : 18,
          right: 18,
        ),
        child: _AppFailureBanner(
          event: presentation.event,
          busy: presentation.busy,
          onAction: presentation.onAction,
          onDismiss: presentation.onDismiss,
        ),
      ),
    );
  }
}

class _AppFailureBanner extends StatelessWidget {
  const _AppFailureBanner({
    required this.event,
    required this.busy,
    required this.onAction,
    required this.onDismiss,
  });

  final DiagnosticEvent event;
  final bool busy;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SoundGlassSurface(
        key: const ValueKey('global-failure-banner'),
        strong: true,
        color: context.soundChromeSurface,
        borderRadius: BorderRadius.circular(14),
        borderColor: Colors.transparent,
        shadowOffset: const Offset(0, 3),
        shadowBlur: 10,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: SoundColors.accent.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.failure.title,
                    style: TextStyle(
                      color: context.soundPrimaryText,
                      fontSize: 13.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    event.failure.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.soundMutedText,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (onAction != null)
              TextButton(
                key: const ValueKey('global-failure-action'),
                onPressed: busy ? null : onAction,
                style: TextButton.styleFrom(
                  foregroundColor: SoundColors.accent,
                  backgroundColor: Colors.transparent,
                  minimumSize: const Size(48, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: busy
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_failureActionLabel(event.failure.action)),
              ),
            IconButton(
              key: const ValueKey('global-failure-dismiss'),
              onPressed: onDismiss,
              tooltip: '暂时关闭',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              color: context.soundMutedText,
              icon: const Icon(Icons.close_rounded, size: 17),
            ),
          ],
        ),
      ),
    );
  }
}

String _failureActionLabel(AppFailureAction action) => switch (action) {
  AppFailureAction.retry => '重试',
  AppFailureAction.editSource => '更新来源',
  AppFailureAction.locateFile => '重新扫描',
  AppFailureAction.manageStorage => '管理空间',
  AppFailureAction.none => '知道了',
};

extension _PlaybackShortcutWrapper on Widget {
  Widget withPlaybackShortcuts(SoundPlaybackController playback) {
    return CallbackShortcuts(
      bindings: {
        const _PlaybackSpaceActivator(): () => unawaited(playback.toggle()),
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
            unawaited(playback.toggle()),
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
            unawaited(playback.next()),
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () =>
            unawaited(playback.previous()),
      },
      child: this,
    );
  }
}

class _PlaybackSpaceActivator extends ShortcutActivator {
  const _PlaybackSpaceActivator();

  static const _space = SingleActivator(LogicalKeyboardKey.space);

  @override
  Iterable<LogicalKeyboardKey> get triggers => const [LogicalKeyboardKey.space];

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) =>
      _space.accepts(event, state) && !_isTextEditingFocusActive();

  @override
  String debugDescribeKeys() => 'Space outside text input';
}

bool _isTextEditingFocusActive() {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  return focusContext.widget is EditableText ||
      focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
}

class _DesktopTitleBar extends StatefulWidget {
  const _DesktopTitleBar({
    required this.selection,
    required this.onSearch,
    required this.onSettings,
  });

  final AppSection selection;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  State<_DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<_DesktopTitleBar> {
  bool _maximized = false;
  StreamSubscription<bool>? _maximizedSubscription;

  /// Paint custom drag strip + min/max/close only on Windows target platform
  /// (respects [debugDefaultTargetPlatformOverride] in tests).
  bool get _usesCustomWindowChrome =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    if (_usesCustomWindowChrome) {
      unawaited(_refreshMaximized());
      _maximizedSubscription = windowMaximizedChanges.listen((maximized) {
        if (mounted) setState(() => _maximized = maximized);
      });
    }
  }

  @override
  void dispose() {
    unawaited(_maximizedSubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _refreshMaximized() async {
    final maximized = await isWindowMaximized();
    if (mounted) setState(() => _maximized = maximized);
  }

  Future<void> _toggleMaximize() async {
    final next = !_maximized;
    // Optimistic update so the icon flips immediately.
    if (mounted) setState(() => _maximized = next);
    if (next) {
      await maximizeWindow();
    } else {
      await restoreWindow();
    }
    await _refreshMaximized();
  }

  @override
  Widget build(BuildContext context) {
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    final titleBarHeight = platformTitleBarHeight;
    final customChrome = _usesCustomWindowChrome;

    return SizedBox(
      height: titleBarHeight,
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            // Left side: draggable title bar area (Windows custom chrome).
            if (customChrome)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => unawaited(_toggleMaximize()),
                  onPanStart: (_) => unawaited(startWindowDrag()),
                  child: SizedBox(height: titleBarHeight),
                ),
              ),
            // macOS: spacer to push buttons to the right of the traffic lights.
            if (isMacOS) const Spacer(),
            // App action buttons (search + settings).
            _TitleBarAction(
              key: const ValueKey('desktop-search-action'),
              icon: Icons.search_rounded,
              tooltip: '搜索',
              active: widget.selection == AppSection.search,
              onPressed: widget.onSearch,
            ),
            const SizedBox(width: 2),
            _TitleBarAction(
              key: const ValueKey('desktop-settings-action'),
              icon: Icons.settings_outlined,
              tooltip: '设置',
              active: widget.selection == AppSection.settings,
              onPressed: widget.onSettings,
            ),
            // Window control buttons — Windows custom chrome only.
            if (customChrome) ...[
              const SizedBox(width: 10),
              _WindowControlButton(
                key: const ValueKey('window-minimize'),
                icon: Icons.horizontal_rule_rounded,
                tooltip: '最小化',
                onPressed: () => unawaited(minimizeWindow()),
              ),
              const SizedBox(width: 2),
              _WindowControlButton(
                key: const ValueKey('window-maximize'),
                icon: _maximized
                    ? Icons.filter_none_rounded
                    : Icons.crop_square_rounded,
                tooltip: _maximized ? '向下还原' : '最大化',
                onPressed: () => unawaited(_toggleMaximize()),
              ),
              const SizedBox(width: 2),
              _WindowControlButton(
                key: const ValueKey('window-close'),
                icon: Icons.close_rounded,
                tooltip: '关闭',
                closeButton: true,
                onPressed: () => unawaited(closeWindow()),
              ),
            ],
            SizedBox(width: isMacOS ? 14 : 8),
          ],
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatelessWidget {
  const _WindowControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.closeButton = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool closeButton;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 32,
          height: 28,
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: closeButton
                  ? context.soundSecondaryText
                  : context.soundSecondaryText.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBarAction extends StatelessWidget {
  const _TitleBarAction({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      style: IconButton.styleFrom(
        foregroundColor: active
            ? SoundColors.accent
            : context.soundSecondaryText,
        backgroundColor: active ? context.soundTint(0.055) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selection,
    required this.libraryMode,
    required this.userMode,
    required this.onSelectLibraryMode,
    required this.onSelectUserMode,
  });

  final AppSection selection;
  final LibraryBrowseMode libraryMode;
  final LibraryUserBrowseMode? userMode;
  final ValueChanged<LibraryBrowseMode> onSelectLibraryMode;
  final ValueChanged<LibraryUserBrowseMode> onSelectUserMode;

  @override
  Widget build(BuildContext context) {
    return SoundGlassSurface(
      strong: true,
      color: context.soundChromeSurface,
      borderRadius: BorderRadius.zero,
      shadowOffset: const Offset(1, 0),
      shadowBlur: 6,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          minimum: EdgeInsets.only(top: context.soundTitlebarInset),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(10, 2, 10, 12),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/branding/app_icon_master-v6.png',
                        width: 28,
                        height: 28,
                        filterQuality: FilterQuality.high,
                        semanticLabel: 'Reverie',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reverie',
                        style: TextStyle(
                          color: context.soundPrimaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const _SidebarHeading('资料库'),
                      for (final mode in LibraryBrowseMode.values)
                        _SidebarRow(
                          label: mode.label,
                          icon: mode.icon,
                          active:
                              selection == AppSection.library &&
                              userMode == null &&
                              libraryMode == mode,
                          onTap: () => onSelectLibraryMode(mode),
                        ),
                      const _SidebarHeading('我的音乐'),
                      for (final mode in LibraryUserBrowseMode.values)
                        _SidebarRow(
                          label: mode.label,
                          icon: mode.icon,
                          active:
                              selection == AppSection.library &&
                              userMode == mode,
                          onTap: () => onSelectUserMode(mode),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarHeading extends StatelessWidget {
  const _SidebarHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 13, 10, 3),
      child: Text(
        label,
        style: TextStyle(
          color: context.soundMutedText,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SoundListRow(
      minHeight: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      selected: active,
      leading: Icon(
        icon,
        size: 18,
        color: active ? SoundColors.accent : context.soundSecondaryText,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: active ? context.soundPrimaryText : context.soundSecondaryText,
          fontSize: 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _CompactPlaybackDock extends StatelessWidget {
  const _CompactPlaybackDock({
    required this.playback,
    required this.userState,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onOpenNowPlaying,
    required this.onOpenQueue,
  });

  final SoundPlaybackController playback;
  final LibraryUserStateController userState;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenNowPlaying;
  final VoidCallback onOpenQueue;

  static const _destinations = [
    SoundNavigationItem(
      icon: Icons.library_music_outlined,
      selectedIcon: Icons.library_music_rounded,
      label: '资料库',
    ),
    SoundNavigationItem(
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
      label: '搜索',
    ),
    SoundNavigationItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: '设置',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final hasTrack = playback.displayTrack != null;
        return SoundGlassSurface(
          key: const ValueKey('compact-playback-dock'),
          borderRadius: BorderRadius.zero,
          shadowOffset: const Offset(0, -5),
          shadowBlur: 20,
          color: context.soundChromeSurface,
          borderColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTrack) ...[
                MiniPlayer(
                  playback: playback,
                  userState: userState,
                  compact: context.soundIsCompact,
                  embedded: true,
                  onOpen: onOpenNowPlaying,
                  onOpenQueue: onOpenQueue,
                ),
              ],
              SoundNavigationBar(
                embedded: true,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: _destinations,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KeyboardShortcutDialog extends StatelessWidget {
  const _KeyboardShortcutDialog();

  static const _shortcuts = <(String, String)>[
    ('空格', '播放或暂停'),
    ('⌘/Ctrl + ← / →', '上一首或下一首'),
    ('媒体播放键', '播放、暂停和切歌'),
    ('⌘/Ctrl + F', '打开搜索并聚焦输入框'),
    ('⌘/Ctrl + 1', '打开资料库'),
    ('⌘/Ctrl + 2', '打开搜索'),
    ('⌘/Ctrl + 3', '打开设置'),
    ('Tab / Shift + Tab', '向前或向后移动焦点'),
    ('方向键', '在相邻控件和列表项间移动'),
    ('Enter / 空格', '执行当前焦点操作'),
    ('Esc', '返回、关闭或清除搜索'),
    ('⌘/Ctrl + /', '显示此快捷键列表'),
  ];

  @override
  Widget build(BuildContext context) {
    return SoundDialog(
      maxWidth: 540,
      title: const Row(
        children: [
          Icon(Icons.keyboard_alt_outlined),
          SizedBox(width: 10),
          Text('键盘快捷键'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final (shortcut, description) in _shortcuts)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 7, 22, 7),
                      child: Text(
                        shortcut,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        description,
                        style: TextStyle(color: context.soundSecondaryText),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}
