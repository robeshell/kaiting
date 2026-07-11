import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'controllers/library_catalog_controller.dart';
import 'screens/album_detail_screen.dart';
import 'screens/library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/playback_validation_screen.dart';
import 'screens/source_settings_screen.dart';
import 'widgets/mini_player.dart';

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
  Album? _selectedAlbum;
  bool _showPlaybackValidation = false;
  late final LibraryRepository _libraryRepository;
  late final bool _ownsLibraryRepository;
  late final LibraryCatalogController _libraryCatalog;
  LocalSourceService? _localSourceService;
  LocalLibraryScanner? _localLibraryScanner;

  @override
  void initState() {
    super.initState();
    _ownsLibraryRepository = widget.libraryRepository == null;
    _libraryRepository =
        widget.libraryRepository ?? DriftLibraryRepository.defaults();
    _libraryCatalog = LibraryCatalogController(repository: _libraryRepository);
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
      _showPlaybackValidation = false;
    });
  }

  void _openNowPlaying() {
    if (widget.playback.currentTrack == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NowPlayingScreen(playback: widget.playback),
      ),
    );
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
        final desktop = constraints.maxWidth >= 820;
        final content = _showPlaybackValidation
            ? PlaybackValidationScreen(
                playback: widget.playback,
                onBack: () => setState(() => _showPlaybackValidation = false),
              )
            : _selectedAlbum != null
            ? AlbumDetailScreen(
                album: _selectedAlbum!,
                playback: widget.playback,
                onBack: () => setState(() => _selectedAlbum = null),
              )
            : switch (_section) {
                AppSection.library => LibraryScreen(
                  catalog: _libraryCatalog,
                  onOpenAlbum: (album) =>
                      setState(() => _selectedAlbum = album),
                  onManageSources: () => _selectSection(AppSection.sources),
                ),
                AppSection.search => const _SearchPlaceholder(),
                AppSection.sources => SourceSettingsScreen(
                  localSources: _sources,
                  scanner: _scanner,
                  onOpenPlaybackValidation: () =>
                      setState(() => _showPlaybackValidation = true),
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
                              onSelect: _selectSection,
                              onOpenPlaybackValidation: () => setState(() {
                                _section = AppSection.sources;
                                _selectedAlbum = null;
                                _showPlaybackValidation = true;
                              }),
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
                  compact: !desktop,
                  onOpen: _openNowPlaying,
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
    _libraryCatalog.dispose();
    if (_ownsLibraryRepository) unawaited(_libraryRepository.close());
    super.dispose();
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selection,
    required this.onSelect,
    required this.onOpenPlaybackValidation,
  });

  final AppSection selection;
  final ValueChanged<AppSection> onSelect;
  final VoidCallback onOpenPlaybackValidation;

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
              _SidebarRow(
                label: '搜索',
                icon: Icons.search_rounded,
                active: selection == AppSection.search,
                onTap: () => onSelect(AppSection.search),
              ),
              _SidebarRow(
                label: '正在收听',
                icon: Icons.music_note_rounded,
                accent: true,
                onTap: () => onSelect(AppSection.library),
              ),
              const _SidebarHeading('资料库'),
              _SidebarRow(
                label: '最近添加',
                icon: Icons.access_time_rounded,
                active: selection == AppSection.library,
                onTap: () => onSelect(AppSection.library),
              ),
              _SidebarRow(
                label: '专辑',
                icon: Icons.album_outlined,
                onTap: () => onSelect(AppSection.library),
              ),
              _SidebarRow(
                label: '歌曲',
                icon: Icons.music_note_outlined,
                onTap: () => onSelect(AppSection.library),
              ),
              _SidebarRow(
                label: '艺人',
                icon: Icons.person_outline_rounded,
                onTap: () => onSelect(AppSection.library),
              ),
              _SidebarRow(
                label: '流派',
                icon: Icons.grid_view_rounded,
                onTap: () => onSelect(AppSection.library),
              ),
              const Spacer(),
              if (kDebugMode)
                _SidebarRow(
                  label: '播放验证（Debug）',
                  icon: Icons.science_outlined,
                  accent: true,
                  onTap: onOpenPlaybackValidation,
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
    this.accent = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool accent;

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
          color: accent || active ? SoundColors.accent : Colors.white70,
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

class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '搜索',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            autofocus: false,
            decoration: InputDecoration(
              hintText: '歌曲、专辑、艺人或文件路径',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const Spacer(),
          const Center(
            child: Text(
              '搜索索引将在播放验证完成后接入',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
