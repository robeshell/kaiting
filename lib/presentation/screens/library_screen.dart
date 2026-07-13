import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../controllers/library_catalog_controller.dart';
import '../controllers/library_user_state_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/source_badge.dart';
import '../widgets/sound_components.dart';
import 'library_user_screen.dart';

enum LibraryBrowseMode { albums, artists, genres, songs }

enum LibrarySortOrder {
  titleAscending,
  titleDescending,
  artistAscending,
  albumAscending,
  yearDescending,
  trackCountDescending,
}

enum LibrarySourceFilter { all, local, webDav }

extension LibraryBrowseModePresentation on LibraryBrowseMode {
  String get label => switch (this) {
    LibraryBrowseMode.albums => '专辑',
    LibraryBrowseMode.artists => '艺人',
    LibraryBrowseMode.genres => '流派',
    LibraryBrowseMode.songs => '歌曲',
  };

  IconData get icon => switch (this) {
    LibraryBrowseMode.albums => Icons.album_outlined,
    LibraryBrowseMode.artists => Icons.person_outline_rounded,
    LibraryBrowseMode.genres => Icons.grid_view_rounded,
    LibraryBrowseMode.songs => Icons.music_note_outlined,
  };
}

extension LibrarySortOrderPresentation on LibrarySortOrder {
  String get label => switch (this) {
    LibrarySortOrder.titleAscending => '标题 A–Z',
    LibrarySortOrder.titleDescending => '标题 Z–A',
    LibrarySortOrder.artistAscending => '艺人 A–Z',
    LibrarySortOrder.albumAscending => '专辑 A–Z',
    LibrarySortOrder.yearDescending => '年份（新到旧）',
    LibrarySortOrder.trackCountDescending => '歌曲数量（多到少）',
  };
}

extension LibrarySourceFilterPresentation on LibrarySourceFilter {
  String get label => switch (this) {
    LibrarySourceFilter.all => '全部来源',
    LibrarySourceFilter.local => '本地',
    LibrarySourceFilter.webDav => 'WebDAV',
  };

  IconData get icon => switch (this) {
    LibrarySourceFilter.all => Icons.library_music_outlined,
    LibrarySourceFilter.local => SourceKind.local.icon,
    LibrarySourceFilter.webDav => SourceKind.webDav.icon,
  };
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.catalog,
    required this.mode,
    required this.onModeChanged,
    required this.onOpenAlbum,
    required this.onOpenCollection,
    required this.onPlayTrack,
    this.userState,
    this.onOpenUserMode,
    required this.onManageSources,
    super.key,
  });

  final LibraryCatalogController catalog;
  final LibraryBrowseMode mode;
  final ValueChanged<LibraryBrowseMode> onModeChanged;
  final ValueChanged<Album> onOpenAlbum;
  final ValueChanged<LibraryCollection> onOpenCollection;
  final void Function(Track track, List<Track> queue) onPlayTrack;
  final LibraryUserStateController? userState;
  final ValueChanged<LibraryUserBrowseMode>? onOpenUserMode;
  final VoidCallback onManageSources;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final Map<LibraryBrowseMode, LibrarySortOrder> _sortByMode = {
    for (final mode in LibraryBrowseMode.values)
      mode: LibrarySortOrder.titleAscending,
  };
  LibrarySourceFilter _sourceFilter = LibrarySourceFilter.all;

  LibrarySortOrder get _sortOrder => _sortByMode[widget.mode]!;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.catalog, ?widget.userState]),
      builder: (context, _) {
        final allAlbums = widget.catalog.albums;
        final albums = _sortAlbums(_filterAlbums(allAlbums));
        final albumByTrackId = {
          for (final album in albums)
            for (final track in album.tracks) track.id: album,
        };
        final tracks = _sortTracks([
          for (final album in albums) ...album.tracks,
        ]);
        final artists = _sortCollections(buildArtistCollections(albums));
        final genres = _sortCollections(buildGenreCollections(albums));
        final resultCount = switch (widget.mode) {
          LibraryBrowseMode.albums => albums.length,
          LibraryBrowseMode.artists => artists.length,
          LibraryBrowseMode.genres => genres.length,
          LibraryBrowseMode.songs => tracks.length,
        };
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 34, 32, 20),
              sliver: SliverToBoxAdapter(
                child: _LibraryHeader(
                  mode: widget.mode,
                  onModeChanged: widget.onModeChanged,
                  albumCount: allAlbums.length,
                  trackCount: widget.catalog.tracks.length,
                  onOpenUserMode: widget.onOpenUserMode,
                ),
              ),
            ),
            if (widget.catalog.status == LibraryCatalogStatus.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _CatalogMessage.loading(),
              )
            else if (widget.catalog.status == LibraryCatalogStatus.error)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CatalogMessage.error(
                  message: widget.catalog.errorMessage ?? '无法读取资料库。',
                  onAction: widget.catalog.refresh,
                ),
              )
            else if (allAlbums.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CatalogMessage.empty(onAction: widget.onManageSources),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                sliver: SliverToBoxAdapter(
                  child: _LibraryToolbar(
                    mode: widget.mode,
                    resultCount: resultCount,
                    sortOrder: _sortOrder,
                    sortOptions: _sortOptions(widget.mode),
                    sourceFilter: _sourceFilter,
                    onSortChanged: (value) =>
                        setState(() => _sortByMode[widget.mode] = value),
                    onSourceChanged: (value) =>
                        setState(() => _sourceFilter = value),
                  ),
                ),
              ),
              if (albums.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CatalogMessage.filtered(),
                )
              else
                ...switch (widget.mode) {
                  LibraryBrowseMode.albums => _albumSlivers(albums),
                  LibraryBrowseMode.artists => _collectionSlivers(
                    artists,
                    emptyMessage: '资料库中没有可浏览的艺人。',
                  ),
                  LibraryBrowseMode.genres => _collectionSlivers(
                    genres,
                    emptyMessage: '资料库中没有流派信息。',
                  ),
                  LibraryBrowseMode.songs => _songSlivers(
                    tracks,
                    albumByTrackId,
                  ),
                },
            ],
          ],
        );
      },
    );
  }

  List<Album> _filterAlbums(List<Album> albums) {
    final source = switch (_sourceFilter) {
      LibrarySourceFilter.all => null,
      LibrarySourceFilter.local => SourceKind.local,
      LibrarySourceFilter.webDav => SourceKind.webDav,
    };
    if (source == null) return albums;
    return [
      for (final album in albums)
        if (album.source == source) album,
    ];
  }

  List<Album> _sortAlbums(List<Album> albums) {
    final sorted = [...albums];
    sorted.sort(switch (_sortOrder) {
      LibrarySortOrder.titleAscending => (left, right) => _compareText(
        left.title,
        right.title,
      ),
      LibrarySortOrder.titleDescending => (left, right) => _compareText(
        right.title,
        left.title,
      ),
      LibrarySortOrder.artistAscending => (left, right) => _compareThen(
        _compareText(left.artist, right.artist),
        () => _compareText(left.title, right.title),
      ),
      LibrarySortOrder.yearDescending => (left, right) => _compareThen(
        _compareNullableYearDescending(left.year, right.year),
        () => _compareText(left.title, right.title),
      ),
      LibrarySortOrder.albumAscending ||
      LibrarySortOrder.trackCountDescending => (left, right) => _compareText(
        left.title,
        right.title,
      ),
    });
    return sorted;
  }

  List<Track> _sortTracks(List<Track> tracks) {
    final sorted = [...tracks];
    sorted.sort(switch (_sortOrder) {
      LibrarySortOrder.titleAscending => (left, right) => _compareText(
        left.title,
        right.title,
      ),
      LibrarySortOrder.titleDescending => (left, right) => _compareText(
        right.title,
        left.title,
      ),
      LibrarySortOrder.artistAscending => (left, right) => _compareThen(
        _compareText(left.artist, right.artist),
        () => _compareText(left.title, right.title),
      ),
      LibrarySortOrder.albumAscending => (left, right) => _compareThen(
        _compareText(left.albumTitle, right.albumTitle),
        () => left.trackNumber.compareTo(right.trackNumber),
      ),
      LibrarySortOrder.yearDescending => (left, right) => _compareThen(
        _compareNullableYearDescending(left.year, right.year),
        () => _compareText(left.title, right.title),
      ),
      LibrarySortOrder.trackCountDescending => (left, right) => _compareText(
        left.title,
        right.title,
      ),
    });
    return sorted;
  }

  List<LibraryCollection> _sortCollections(
    List<LibraryCollection> collections,
  ) {
    final sorted = [...collections];
    sorted.sort(switch (_sortOrder) {
      LibrarySortOrder.titleAscending => (left, right) => _compareText(
        left.title,
        right.title,
      ),
      LibrarySortOrder.titleDescending => (left, right) => _compareText(
        right.title,
        left.title,
      ),
      LibrarySortOrder.trackCountDescending => (left, right) => _compareThen(
        right.tracks.length.compareTo(left.tracks.length),
        () => _compareText(left.title, right.title),
      ),
      LibrarySortOrder.artistAscending ||
      LibrarySortOrder.albumAscending ||
      LibrarySortOrder.yearDescending => (left, right) => _compareText(
        left.title,
        right.title,
      ),
    });
    return sorted;
  }

  List<Widget> _albumSlivers(List<Album> albums) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 140),
        sliver: SliverGrid.builder(
          itemCount: albums.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            mainAxisExtent: 280,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemBuilder: (context, index) {
            final album = albums[index];
            return _AlbumCard(
              album: album,
              onTap: () => widget.onOpenAlbum(album),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _collectionSlivers(
    List<LibraryCollection> collections, {
    required String emptyMessage,
  }) {
    if (collections.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CatalogMessage._(
            icon: Icons.category_outlined,
            title: '暂无内容',
            message: emptyMessage,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 140),
        sliver: SliverGrid.builder(
          itemCount: collections.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisExtent: 300,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemBuilder: (context, index) {
            final collection = collections[index];
            return _CollectionCard(
              collection: collection,
              onTap: () => widget.onOpenCollection(collection),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _songSlivers(
    List<Track> tracks,
    Map<String, Album> albumByTrackId,
  ) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
        sliver: SliverToBoxAdapter(
          child: _SongHeader(
            trackCount: tracks.length,
            onPlayAll: () => widget.onPlayTrack(tracks.first, tracks),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
        sliver: SliverPrototypeExtentList.builder(
          itemCount: tracks.length,
          prototypeItem: _LibraryTrackRow(
            track: tracks.first,
            album: albumByTrackId[tracks.first.id]!,
            favorite: widget.userState?.isFavorite(tracks.first.id) ?? false,
            onTap: () {},
            onToggleFavorite: null,
            onAddToPlaylist: null,
            onOpenAlbum: () {},
          ),
          itemBuilder: (context, index) {
            final track = tracks[index];
            final album = albumByTrackId[track.id]!;
            return _LibraryTrackRow(
              track: track,
              album: album,
              favorite: widget.userState?.isFavorite(track.id) ?? false,
              onTap: () => widget.onPlayTrack(track, tracks),
              onToggleFavorite: widget.userState == null
                  ? null
                  : () => unawaited(widget.userState!.toggleFavorite(track)),
              onAddToPlaylist: widget.userState == null
                  ? null
                  : () => showAddToPlaylistSheet(
                      context,
                      userState: widget.userState!,
                      track: track,
                    ),
              onOpenAlbum: () => widget.onOpenAlbum(album),
            );
          },
        ),
      ),
    ];
  }
}

List<LibrarySortOrder> _sortOptions(LibraryBrowseMode mode) => switch (mode) {
  LibraryBrowseMode.albums => const [
    LibrarySortOrder.titleAscending,
    LibrarySortOrder.titleDescending,
    LibrarySortOrder.artistAscending,
    LibrarySortOrder.yearDescending,
  ],
  LibraryBrowseMode.artists || LibraryBrowseMode.genres => const [
    LibrarySortOrder.titleAscending,
    LibrarySortOrder.titleDescending,
    LibrarySortOrder.trackCountDescending,
  ],
  LibraryBrowseMode.songs => const [
    LibrarySortOrder.titleAscending,
    LibrarySortOrder.titleDescending,
    LibrarySortOrder.artistAscending,
    LibrarySortOrder.albumAscending,
    LibrarySortOrder.yearDescending,
  ],
};

int _compareText(String left, String right) =>
    left.toLowerCase().compareTo(right.toLowerCase());

int _compareThen(int comparison, int Function() next) =>
    comparison == 0 ? next() : comparison;

int _compareNullableYearDescending(int? left, int? right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return right.compareTo(left);
}

class _LibraryTrackRow extends StatelessWidget {
  const _LibraryTrackRow({
    required this.track,
    required this.album,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.onOpenAlbum,
  });

  final Track track;
  final Album album;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    return SoundTrackActivation(
      onActivate: onTap,
      semanticLabel: track.title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 5),
          leading: SizedBox.square(
            dimension: 48,
            child: AlbumArt(album: album, borderRadius: 6),
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${track.artist} · ${track.albumTitle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SourceBadge(track.source),
              if (onToggleFavorite != null)
                IconButton(
                  key: ValueKey('favorite-library-${track.id}'),
                  onPressed: onToggleFavorite,
                  tooltip: favorite
                      ? '取消收藏 ${track.title}'
                      : '收藏 ${track.title}',
                  color: favorite ? SoundColors.accent : null,
                  icon: Icon(
                    favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                ),
              if (onAddToPlaylist != null)
                IconButton(
                  key: ValueKey('add-library-${track.id}-to-playlist'),
                  onPressed: onAddToPlaylist,
                  tooltip: '将 ${track.title} 添加到播放列表',
                  icon: const Icon(Icons.playlist_add_rounded),
                ),
              IconButton(
                onPressed: onOpenAlbum,
                tooltip: '打开专辑 ${album.title}',
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.mode,
    required this.onModeChanged,
    required this.albumCount,
    required this.trackCount,
    required this.onOpenUserMode,
  });

  final LibraryBrowseMode mode;
  final ValueChanged<LibraryBrowseMode> onModeChanged;
  final int albumCount;
  final int trackCount;
  final ValueChanged<LibraryUserBrowseMode>? onOpenUserMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '资料库',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$albumCount 张专辑 · $trackCount 首歌曲',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final candidate in LibraryBrowseMode.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('library-mode-${candidate.name}'),
                    avatar: Icon(candidate.icon, size: 17),
                    label: Text(candidate.label),
                    selected: mode == candidate,
                    onSelected: (_) => onModeChanged(candidate),
                    selectedColor: SoundColors.accent.withValues(alpha: 0.24),
                  ),
                ),
              if (onOpenUserMode case final openUserMode?)
                for (final candidate in LibraryUserBrowseMode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      key: ValueKey('open-user-library-${candidate.name}'),
                      avatar: Icon(candidate.icon, size: 17),
                      label: Text(candidate.label),
                      onPressed: () => openUserMode(candidate),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryToolbar extends StatelessWidget {
  const _LibraryToolbar({
    required this.mode,
    required this.resultCount,
    required this.sortOrder,
    required this.sortOptions,
    required this.sourceFilter,
    required this.onSortChanged,
    required this.onSourceChanged,
  });

  final LibraryBrowseMode mode;
  final int resultCount;
  final LibrarySortOrder sortOrder;
  final List<LibrarySortOrder> sortOptions;
  final LibrarySourceFilter sourceFilter;
  final ValueChanged<LibrarySortOrder> onSortChanged;
  final ValueChanged<LibrarySourceFilter> onSourceChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(switch (mode) {
          LibraryBrowseMode.albums => '$resultCount 张专辑',
          LibraryBrowseMode.artists => '$resultCount 位艺人',
          LibraryBrowseMode.genres => '$resultCount 个流派',
          LibraryBrowseMode.songs => '$resultCount 首歌曲',
        }, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        PopupMenuButton<LibrarySortOrder>(
          key: const ValueKey('library-sort-menu'),
          tooltip: '选择排序方式',
          initialValue: sortOrder,
          onSelected: onSortChanged,
          itemBuilder: (context) => [
            for (final option in sortOptions)
              PopupMenuItem(
                value: option,
                child: _MenuItemLabel(
                  label: option.label,
                  selected: option == sortOrder,
                ),
              ),
          ],
          child: _ToolbarButton(
            icon: Icons.sort_rounded,
            label: sortOrder.label,
          ),
        ),
        PopupMenuButton<LibrarySourceFilter>(
          key: const ValueKey('library-source-menu'),
          tooltip: '筛选音乐来源',
          initialValue: sourceFilter,
          onSelected: onSourceChanged,
          itemBuilder: (context) => [
            for (final option in LibrarySourceFilter.values)
              PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    Icon(option.icon, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MenuItemLabel(
                        label: option.label,
                        selected: option == sourceFilter,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: _ToolbarButton(
            icon: sourceFilter.icon,
            label: sourceFilter.label,
          ),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: Colors.white70),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MenuItemLabel extends StatelessWidget {
  const _MenuItemLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        if (selected) ...[
          const SizedBox(width: 12),
          const Icon(Icons.check_rounded, size: 18, color: SoundColors.accent),
        ],
      ],
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage._({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  const _CatalogMessage.loading()
    : this._(
        icon: Icons.library_music_outlined,
        title: '正在读取资料库',
        message: '正在加载已索引的专辑和歌曲。',
        loading: true,
      );

  const _CatalogMessage.empty({required VoidCallback onAction})
    : this._(
        icon: Icons.create_new_folder_outlined,
        title: '资料库还是空的',
        message: '添加一个本地音乐文件夹，扫描完成后歌曲会显示在这里。',
        actionLabel: '管理音乐来源',
        onAction: onAction,
      );

  const _CatalogMessage.filtered()
    : this._(
        icon: Icons.filter_alt_off_outlined,
        title: '当前筛选没有内容',
        message: '这个来源中没有已索引的音乐，可以切换到其他来源继续浏览。',
      );

  const _CatalogMessage.error({
    required String message,
    required VoidCallback onAction,
  }) : this._(
         icon: Icons.error_outline_rounded,
         title: '无法读取资料库',
         message: message,
         actionLabel: '重试',
         onAction: onAction,
       );

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 150),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                Icon(icon, size: 48, color: Colors.white38),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, height: 1.5),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(actionLabel!),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoundColors.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SongHeader extends StatelessWidget {
  const _SongHeader({required this.trackCount, required this.onPlayAll});

  final int trackCount;
  final VoidCallback onPlayAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$trackCount 首歌曲',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: onPlayAll,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('播放全部'),
          style: FilledButton.styleFrom(
            backgroundColor: SoundColors.accent,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlbumArt(album: album),
          const SizedBox(height: 10),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  album.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
              SourceBadge(album.source),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, required this.onTap});

  final LibraryCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final album = collection.albums.first;
    return InkWell(
      key: ValueKey('library-collection-${collection.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AlbumArt(album: album),
              Positioned(
                right: 10,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      collection.kind == LibraryCollectionKind.artist
                          ? Icons.person_rounded
                          : Icons.grid_view_rounded,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            collection.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            '${collection.albums.length} 张专辑 · ${collection.tracks.length} 首歌',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
