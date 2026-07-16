import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../controllers/library_catalog_controller.dart';
import '../controllers/library_user_state_controller.dart';
import '../models/library_source_filter.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/sound_components.dart';
import 'library_user_screen.dart';

enum LibraryBrowseMode { albums, artists, songs }

enum LibrarySortOrder {
  titleAscending,
  titleDescending,
  artistAscending,
  albumAscending,
  yearDescending,
  trackCountDescending,
}

extension LibraryBrowseModePresentation on LibraryBrowseMode {
  String get label => switch (this) {
    LibraryBrowseMode.albums => '专辑',
    LibraryBrowseMode.artists => '艺人',
    LibraryBrowseMode.songs => '歌曲',
  };

  IconData get icon => switch (this) {
    LibraryBrowseMode.albums => Icons.album_outlined,
    LibraryBrowseMode.artists => Icons.person_outline_rounded,
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
        final compact = context.soundIsCompact;
        final gutter = context.soundPageGutter;
        final bottomPadding = context.soundContentBottomPadding;
        final allAlbums = widget.catalog.albums;
        final albums = _sortAlbums(_filterAlbums(allAlbums));
        final albumByTrackId = {
          for (final album in albums)
            for (final track in album.tracks) track.id: album,
        };
        final tracks = _sortTracks([
          for (final album in albums) ...album.tracks,
        ]);
        final sourceOptions = LibrarySourceFilter.options(
          allAlbums.map((album) => album.source),
        );
        final artists = _sortCollections(buildArtistCollections(albums));
        final resultCount = switch (widget.mode) {
          LibraryBrowseMode.albums => albums.length,
          LibraryBrowseMode.artists => artists.length,
          LibraryBrowseMode.songs => tracks.length,
        };
        return CustomScrollView(
          slivers: [
            if (compact)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 10),
                sliver: SliverToBoxAdapter(
                  child: _CompactLibraryNavigation(
                    mode: widget.mode,
                    onModeChanged: widget.onModeChanged,
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
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  compact ? 0 : 24,
                  gutter,
                  12,
                ),
                sliver: SliverToBoxAdapter(
                  child: _LibraryToolbar(
                    mode: widget.mode,
                    resultCount: resultCount,
                    sortOrder: _sortOrder,
                    sortOptions: _sortOptions(widget.mode),
                    sourceFilter: _sourceFilter,
                    sourceOptions: sourceOptions,
                    onSortChanged: (value) =>
                        setState(() => _sortByMode[widget.mode] = value),
                    onSourceChanged: (value) =>
                        setState(() => _sourceFilter = value),
                    onPlayAll:
                        widget.mode == LibraryBrowseMode.songs &&
                            tracks.isNotEmpty
                        ? () => widget.onPlayTrack(tracks.first, tracks)
                        : null,
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
                  LibraryBrowseMode.albums => _albumSlivers(
                    albums,
                    gutter,
                    bottomPadding,
                    compact: compact,
                  ),
                  LibraryBrowseMode.artists => _collectionSlivers(
                    artists,
                    gutter: gutter,
                    bottomPadding: bottomPadding,
                    emptyMessage: '资料库中没有可浏览的艺人。',
                    compact: compact,
                  ),
                  LibraryBrowseMode.songs => _songSlivers(
                    tracks,
                    albumByTrackId,
                    gutter,
                    bottomPadding,
                    compact: compact,
                  ),
                },
            ],
          ],
        );
      },
    );
  }

  List<Album> _filterAlbums(List<Album> albums) {
    final source = _sourceFilter.source;
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

  List<Widget> _albumSlivers(
    List<Album> albums,
    double gutter,
    double bottomPadding, {
    required bool compact,
  }) {
    final spacing = compact ? 12.0 : 16.0;
    final maxCardWidth = compact ? 180.0 : 210.0;
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          gutter,
          compact ? 4 : 6,
          gutter,
          bottomPadding,
        ),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final columnCount =
                ((constraints.crossAxisExtent + spacing) /
                        (maxCardWidth + spacing))
                    .ceil()
                    .clamp(1, 12);
            final cardWidth =
                (constraints.crossAxisExtent - spacing * (columnCount - 1)) /
                columnCount;
            return SliverGrid.builder(
              itemCount: albums.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                // Two single-line labels, their internal gaps, and a small
                // rounding allowance for platform font metrics.
                mainAxisExtent: cardWidth + 46,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
              ),
              itemBuilder: (context, index) {
                final album = albums[index];
                return _AlbumCard(
                  album: album,
                  onTap: () => widget.onOpenAlbum(album),
                );
              },
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _collectionSlivers(
    List<LibraryCollection> collections, {
    required double gutter,
    required double bottomPadding,
    required String emptyMessage,
    required bool compact,
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
        padding: EdgeInsets.fromLTRB(
          gutter,
          compact ? 4 : 6,
          gutter,
          bottomPadding,
        ),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final spacing = compact ? 12.0 : 16.0;
            final maxCardWidth = compact ? 180.0 : 220.0;
            final columnCount =
                ((constraints.crossAxisExtent + spacing) /
                        (maxCardWidth + spacing))
                    .ceil()
                    .clamp(1, 12);
            final cardWidth =
                (constraints.crossAxisExtent - spacing * (columnCount - 1)) /
                columnCount;
            return SliverGrid.builder(
              itemCount: collections.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                mainAxisExtent: cardWidth + 46,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
              ),
              itemBuilder: (context, index) {
                final collection = collections[index];
                return _CollectionCard(
                  collection: collection,
                  compact: compact,
                  onTap: () => widget.onOpenCollection(collection),
                );
              },
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _songSlivers(
    List<Track> tracks,
    Map<String, Album> albumByTrackId,
    double gutter,
    double bottomPadding, {
    required bool compact,
  }) {
    return [
      if (!compact)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
          sliver: SliverToBoxAdapter(
            child: _SongHeader(
              trackCount: tracks.length,
              onPlayAll: () => widget.onPlayTrack(tracks.first, tracks),
            ),
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottomPadding),
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
  LibraryBrowseMode.artists => const [
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
    final compact = context.soundIsCompact;
    return SoundTrackListRow(
      key: ValueKey('library-track-row-${track.id}'),
      leading: AlbumArt(album: album, borderRadius: compact ? 8 : 6),
      title: track.title,
      subtitle: '${track.artist} · ${track.albumTitle}',
      onActivate: onTap,
      compactTrailing: PopupMenuButton<String>(
        key: ValueKey('library-track-actions-${track.id}'),
        tooltip: '更多操作 ${track.title}',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_horiz_rounded, size: 21),
        onSelected: (value) {
          if (value == 'favorite') onToggleFavorite?.call();
          if (value == 'playlist') onAddToPlaylist?.call();
          if (value == 'album') onOpenAlbum();
        },
        itemBuilder: (_) => [
          if (onToggleFavorite != null)
            PopupMenuItem(
              value: 'favorite',
              child: Text(favorite ? '取消收藏' : '收藏'),
            ),
          if (onAddToPlaylist != null)
            const PopupMenuItem(value: 'playlist', child: Text('添加到播放列表')),
          const PopupMenuItem(value: 'album', child: Text('打开专辑')),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onToggleFavorite != null)
            IconButton(
              key: ValueKey('favorite-library-${track.id}'),
              onPressed: onToggleFavorite,
              tooltip: favorite ? '取消收藏 ${track.title}' : '收藏 ${track.title}',
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
    );
  }
}

class _CompactLibraryNavigation extends StatelessWidget {
  const _CompactLibraryNavigation({
    required this.mode,
    required this.onModeChanged,
    required this.onOpenUserMode,
  });

  final LibraryBrowseMode mode;
  final ValueChanged<LibraryBrowseMode> onModeChanged;
  final ValueChanged<LibraryUserBrowseMode>? onOpenUserMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('compact-library-navigation'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final candidate in LibraryBrowseMode.values) ...[
            _CompactLibraryModeItem(
              mode: candidate,
              selected: mode == candidate,
              onTap: () => onModeChanged(candidate),
            ),
            const SizedBox(width: 8),
          ],
          if (onOpenUserMode case final openUserMode?)
            PopupMenuButton<LibraryUserBrowseMode>(
              key: const ValueKey('mobile-library-user-menu'),
              tooltip: '我的音乐',
              onSelected: openUserMode,
              itemBuilder: (_) => [
                for (final candidate in LibraryUserBrowseMode.values)
                  PopupMenuItem(
                    value: candidate,
                    child: Row(
                      children: [
                        Icon(candidate.icon, size: 18),
                        const SizedBox(width: 10),
                        Text(candidate.label),
                      ],
                    ),
                  ),
              ],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.soundTint(0.025),
                  borderRadius: BorderRadius.circular(SoundRadii.pill),
                ),
                child: SizedBox(
                  width: 42,
                  height: 34,
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: context.soundSecondaryText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactLibraryModeItem extends StatelessWidget {
  const _CompactLibraryModeItem({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final LibraryBrowseMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('library-mode-${mode.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(SoundRadii.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected
                ? SoundColors.accent.withValues(alpha: 0.09)
                : context.soundTint(0.025),
            borderRadius: BorderRadius.circular(SoundRadii.pill),
          ),
          alignment: Alignment.center,
          child: Text(
            mode.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? SoundColors.accent : context.soundSecondaryText,
            ),
          ),
        ),
      ),
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
    required this.sourceOptions,
    required this.onSortChanged,
    required this.onSourceChanged,
    required this.onPlayAll,
  });

  final LibraryBrowseMode mode;
  final int resultCount;
  final LibrarySortOrder sortOrder;
  final List<LibrarySortOrder> sortOptions;
  final LibrarySourceFilter sourceFilter;
  final List<LibrarySourceFilter> sourceOptions;
  final ValueChanged<LibrarySortOrder> onSortChanged;
  final ValueChanged<LibrarySourceFilter> onSourceChanged;
  final VoidCallback? onPlayAll;

  String get _resultLabel => switch (mode) {
    LibraryBrowseMode.albums => '$resultCount 张专辑',
    LibraryBrowseMode.artists => '$resultCount 位艺人',
    LibraryBrowseMode.songs => '$resultCount 首歌曲',
  };

  @override
  Widget build(BuildContext context) {
    if (context.soundIsCompact) {
      return SizedBox(
        key: const ValueKey('compact-library-toolbar'),
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Text(
                _resultLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.soundMutedText, fontSize: 12),
              ),
            ),
            if (onPlayAll != null) ...[
              _CompactPlayAllButton(onPressed: onPlayAll!),
              const SizedBox(width: 6),
            ],
            _sortMenu(
              child: _ToolbarIconButton(
                icon: Icons.sort_rounded,
                tooltip: '排序：${sortOrder.label}',
              ),
            ),
            const SizedBox(width: 6),
            _sourceMenu(
              child: _ToolbarIconButton(
                icon: Icons.filter_alt_outlined,
                tooltip: '来源：${sourceFilter.label}',
              ),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _resultLabel,
          style: TextStyle(color: context.soundMutedText, fontSize: 12),
        ),
        _sortMenu(
          child: _ToolbarIconButton(
            icon: Icons.sort_rounded,
            tooltip: '排序：${sortOrder.label}',
          ),
        ),
        _sourceMenu(
          child: _ToolbarIconButton(
            icon: Icons.filter_alt_outlined,
            tooltip: '来源：${sourceFilter.label}',
          ),
        ),
      ],
    );
  }

  Widget _sortMenu({required Widget child}) {
    return PopupMenuButton<LibrarySortOrder>(
      key: const ValueKey('library-sort-menu'),
      tooltip: '排序：${sortOrder.label}',
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
      child: child,
    );
  }

  Widget _sourceMenu({required Widget child}) {
    return PopupMenuButton<LibrarySourceFilter>(
      key: const ValueKey('library-source-menu'),
      tooltip: '来源：${sourceFilter.label}',
      initialValue: sourceFilter,
      onSelected: onSourceChanged,
      itemBuilder: (context) => [
        for (final option in sourceOptions)
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
      child: child,
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.soundTint(0.035),
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 36,
          child: Icon(icon, size: 18, color: context.soundSecondaryText),
        ),
      ),
    );
  }
}

class _CompactPlayAllButton extends StatelessWidget {
  const _CompactPlayAllButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('compact-library-play-all'),
      onPressed: onPressed,
      icon: const Icon(Icons.play_arrow_rounded, size: 17),
      label: const Text('播放全部'),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: SoundColors.accent,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
        padding: EdgeInsets.fromLTRB(
          context.soundPageGutter,
          40,
          context.soundPageGutter,
          context.soundContentBottomPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                Icon(
                  icon,
                  size: 48,
                  color: context.soundSecondaryText.withValues(alpha: 0.65),
                ),
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
                style: TextStyle(
                  color: context.soundSecondaryText,
                  height: 1.5,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(actionLabel!),
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
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlbumArt(
            key: ValueKey('library-album-art-${album.id}'),
            album: album,
            borderRadius: 6,
            showShadow: false,
          ),
          const SizedBox(height: 7),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: context.soundSecondaryText),
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.compact,
    required this.onTap,
  });

  final LibraryCollection collection;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final album = collection.albums.first;
    return InkWell(
      key: ValueKey('library-collection-${collection.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AlbumArt(
                key: ValueKey('library-collection-art-${collection.id}'),
                album: album,
                borderRadius: 6,
                showShadow: false,
              ),
              if (!compact)
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
          const SizedBox(height: 7),
          Text(
            collection.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${collection.albums.length} 张专辑 · ${collection.tracks.length} 首歌',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: context.soundSecondaryText),
          ),
        ],
      ),
    );
  }
}
