import 'dart:async';

import 'package:flutter/material.dart';

import '../core/sound_theme.dart';
import '../domain/library_models.dart';
import '../library/library_repository.dart';
import '../library/persistence/drift_library_repository.dart';
import '../library/scanning/local_library_scanner.dart';
import '../library/scanning/local_media_catalog_factory.dart';
import '../playback/playback_controller.dart';
import '../sources/local/local_directory_access_factory.dart';
import '../sources/local/local_source_service.dart';
import '../sources/webdav/webdav_connection_service.dart';
import 'controllers/library_catalog_controller.dart';
import 'controllers/library_search_controller.dart';
import 'controllers/library_user_state_controller.dart';
import 'screens/album_detail_screen.dart';
import 'screens/library_collection_screen.dart';
import 'screens/library_screen.dart';
import 'screens/library_user_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/search_screen.dart';
import 'screens/source_settings_screen.dart';
import 'widgets/mini_player.dart';
import 'widgets/playback_queue_sheet.dart';

enum AppSection { library, search, sources }

const _compactMiniPlayerBottomGap = 10.0;

class AppShell extends StatefulWidget {
  const AppShell({required this.playback, this.libraryRepository, super.key});

  final SoundPlaybackController playback;
  final LibraryRepository? libraryRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.library;
  LibraryBrowseMode _libraryBrowseMode = LibraryBrowseMode.albums;
  LibraryUserBrowseMode? _libraryUserMode;
  Album? _selectedAlbum;
  LibraryCollection? _selectedCollection;
  late final LibraryRepository _libraryRepository;
  late final bool _ownsLibraryRepository;
  late final LibraryCatalogController _libraryCatalog;
  late final LibrarySearchController _librarySearch;
  late final LibraryUserStateController _libraryUserState;
  late final WebDavConnectionService _webDavService;
  late final StreamSubscription<List<WebDavConnectionRecord>>
  _webDavConnectionSubscription;
  late final StreamSubscription<Track> _trackStartedSubscription;
  LocalSourceService? _localSourceService;
  LocalLibraryScanner? _localLibraryScanner;

  @override
  void initState() {
    super.initState();
    _ownsLibraryRepository = widget.libraryRepository == null;
    _libraryRepository =
        widget.libraryRepository ?? DriftLibraryRepository.defaults();
    _libraryCatalog = LibraryCatalogController(repository: _libraryRepository);
    _librarySearch = LibrarySearchController(catalog: _libraryCatalog);
    _libraryUserState = LibraryUserStateController(
      repository: _libraryRepository,
      catalog: _libraryCatalog,
    );
    _trackStartedSubscription = widget.playback.trackStarted.listen(
      (track) => unawaited(_libraryUserState.recordTrackStarted(track)),
    );
    _webDavService = WebDavConnectionService(repository: _libraryRepository);
    // Resolve security-scoped bookmarks at startup so that local files are
    // playable without the user first opening the source-settings screen.
    unawaited(_sources.restoreLocalFolders());
    // Reactively load WebDAV auth headers so remote tracks are playable.
    _webDavConnectionSubscription = _webDavService.watchConnections().listen((
      _,
    ) {
      unawaited(_refreshWebDavAuthHeaders());
    });
    unawaited(_refreshWebDavAuthHeaders());
    // Keep the selected album in sync when the catalog refreshes its objects.
    _libraryCatalog.addListener(_syncLibrarySelection);
  }

  void _syncLibrarySelection() {
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
    _libraryCatalog.webDavAuthHeaders = headers;
    unawaited(_libraryCatalog.refresh());
    widget.playback.setEngineAuthHeaders(
      headers,
      allowBadCertificateUrls: allowBadCertificateUrls,
    );
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
      _selectedAlbum = null;
      _selectedCollection = null;
      _libraryUserMode = null;
    });
  }

  void _selectLibraryMode(LibraryBrowseMode mode) {
    setState(() {
      _section = AppSection.library;
      _libraryBrowseMode = mode;
      _libraryUserMode = null;
      _selectedAlbum = null;
      _selectedCollection = null;
    });
  }

  void _selectLibraryUserMode(LibraryUserBrowseMode mode) {
    setState(() {
      _section = AppSection.library;
      _libraryUserMode = mode;
      _selectedAlbum = null;
      _selectedCollection = null;
    });
  }

  void _openNowPlaying() {
    if (widget.playback.displayTrack == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NowPlayingScreen(
          playback: widget.playback,
          userState: _libraryUserState,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Android can briefly report a zero-sized surface while attaching a
        // cold-started Flutter view. Sliver grids require positive extents,
        // so wait for the first usable viewport instead of laying out content.
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        // A landscape phone can exceed the desktop width breakpoint while
        // remaining far too short for the full sidebar. Require enough
        // vertical room as well so iPhone landscape keeps mobile navigation.
        final desktop =
            constraints.maxWidth >= 820 && constraints.maxHeight >= 600;
        final content = _selectedAlbum != null
            ? AlbumDetailScreen(
                album: _selectedAlbum!,
                playback: widget.playback,
                userState: _libraryUserState,
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
                          onManageSources: () =>
                              _selectSection(AppSection.sources),
                        )
                      : LibraryUserScreen(
                          mode: _libraryUserMode!,
                          catalog: _libraryCatalog,
                          userState: _libraryUserState,
                          playback: widget.playback,
                          onModeChanged: _selectLibraryUserMode,
                          onBack: () => _selectLibraryMode(_libraryBrowseMode),
                          onOpenAlbum: _openAlbum,
                        ),
                AppSection.search => SearchScreen(
                  catalog: _libraryCatalog,
                  search: _librarySearch,
                  playback: widget.playback,
                  userState: _libraryUserState,
                  onOpenAlbum: _openAlbum,
                ),
                AppSection.sources => SourceSettingsScreen(
                  localSources: _sources,
                  scanner: _scanner,
                  webDavService: _webDavService,
                ),
              };

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: desktop
                    ? Row(
                        children: [
                          SizedBox(
                            width: 236,
                            child: _Sidebar(
                              selection: _section,
                              libraryMode: _libraryBrowseMode,
                              userMode: _libraryUserMode,
                              onSelect: _selectSection,
                              onSelectLibraryMode: _selectLibraryMode,
                              onSelectUserMode: _selectLibraryUserMode,
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          Expanded(child: content),
                        ],
                      )
                    : content,
              ),
              Positioned(
                left: desktop ? 258 : 10,
                right: desktop ? 22 : 10,
                bottom: desktop ? 18 : _compactMiniPlayerBottomGap,
                child: MiniPlayer(
                  playback: widget.playback,
                  userState: _libraryUserState,
                  compact: !desktop,
                  onOpen: _openNowPlaying,
                  onOpenQueue: _openQueue,
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _section.index,
                  onDestinationSelected: (index) =>
                      _selectSection(AppSection.values[index]),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.library_music_outlined),
                      selectedIcon: Icon(Icons.library_music_rounded),
                      label: '资料库',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search_rounded),
                      label: '搜索',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: '设置',
                    ),
                  ],
                ),
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_webDavConnectionSubscription.cancel());
    unawaited(_trackStartedSubscription.cancel());
    _libraryCatalog.removeListener(_syncLibrarySelection);
    _librarySearch.dispose();
    _libraryUserState.dispose();
    _libraryCatalog.dispose();
    if (_ownsLibraryRepository) unawaited(_libraryRepository.close());
    super.dispose();
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selection,
    required this.libraryMode,
    required this.userMode,
    required this.onSelect,
    required this.onSelectLibraryMode,
    required this.onSelectUserMode,
  });

  final AppSection selection;
  final LibraryBrowseMode libraryMode;
  final LibraryUserBrowseMode? userMode;
  final ValueChanged<AppSection> onSelect;
  final ValueChanged<LibraryBrowseMode> onSelectLibraryMode;
  final ValueChanged<LibraryUserBrowseMode> onSelectUserMode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoundColors.darkSurface.withValues(alpha: 0.96),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 18, 10, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 4, 10, 18),
                child: Text(
                  'Sound',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _SidebarRow(
                      label: '搜索',
                      icon: Icons.search_rounded,
                      active: selection == AppSection.search,
                      onTap: () => onSelect(AppSection.search),
                    ),
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
                            selection == AppSection.library && userMode == mode,
                        onTap: () => onSelectUserMode(mode),
                      ),
                  ],
                ),
              ),
              _SidebarRow(
                label: '设置',
                icon: Icons.settings_outlined,
                active: selection == AppSection.sources,
                onTap: () => onSelect(AppSection.sources),
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 5),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: ListTile(
        dense: true,
        minLeadingWidth: 20,
        horizontalTitleGap: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        selected: active,
        selectedTileColor: Colors.white.withValues(alpha: 0.08),
        leading: Icon(
          icon,
          size: 18,
          color: active ? SoundColors.accent : Colors.white70,
        ),
        title: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onTap: onTap,
      ),
    );
  }
}
