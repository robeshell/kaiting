import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../controllers/library_user_state_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/progress_scrubber.dart';
import '../widgets/source_badge.dart';

enum LibraryCollectionTrackSort { libraryOrder, title, artist, album }

extension LibraryCollectionTrackSortPresentation on LibraryCollectionTrackSort {
  String get label => switch (this) {
    LibraryCollectionTrackSort.libraryOrder => '资料库顺序',
    LibraryCollectionTrackSort.title => '标题 A–Z',
    LibraryCollectionTrackSort.artist => '艺人 A–Z',
    LibraryCollectionTrackSort.album => '专辑与曲序',
  };
}

class LibraryCollectionScreen extends StatefulWidget {
  const LibraryCollectionScreen({
    required this.collection,
    required this.playback,
    this.userState,
    required this.onBack,
    required this.onOpenAlbum,
    super.key,
  });

  final LibraryCollection collection;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final VoidCallback onBack;
  final ValueChanged<Album> onOpenAlbum;

  @override
  State<LibraryCollectionScreen> createState() =>
      _LibraryCollectionScreenState();
}

class _LibraryCollectionScreenState extends State<LibraryCollectionScreen> {
  LibraryCollectionTrackSort _trackSort =
      LibraryCollectionTrackSort.libraryOrder;

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final sortedTracks = _sortTracks(collection.tracks);
    final albumByTrackId = {
      for (final album in collection.albums)
        for (final track in album.tracks) track.id: album,
    };
    return AnimatedBuilder(
      animation: Listenable.merge([?widget.userState]),
      builder: (context, _) => Material(
        color: Colors.transparent,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _CollectionHero(
                collection: collection,
                onBack: widget.onBack,
                onPlay: sortedTracks.isEmpty
                    ? null
                    : () => widget.playback.playTrack(
                        sortedTracks.first,
                        queue: sortedTracks,
                      ),
              ),
            ),
            if (collection.albums.isNotEmpty) ...[
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(32, 8, 32, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '专辑',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                sliver: SliverGrid.builder(
                  itemCount: collection.albums.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisExtent: 238,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemBuilder: (context, index) {
                    final album = collection.albums[index];
                    return _CollectionAlbumCard(
                      album: album,
                      onTap: () => widget.onOpenAlbum(album),
                    );
                  },
                ),
              ),
            ],
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
              sliver: SliverToBoxAdapter(
                child: _CollectionTrackHeader(
                  trackCount: sortedTracks.length,
                  sort: _trackSort,
                  onSortChanged: (value) => setState(() => _trackSort = value),
                ),
              ),
            ),
            if (sortedTracks.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
                sliver: SliverPrototypeExtentList.builder(
                  itemCount: sortedTracks.length,
                  prototypeItem: _CollectionTrackRow(
                    track: sortedTracks.first,
                    album: albumByTrackId[sortedTracks.first.id]!,
                    favorite:
                        widget.userState?.isFavorite(sortedTracks.first.id) ??
                        false,
                    onTap: () {},
                    onPlayNext: () {},
                    onToggleFavorite: null,
                    onAddToPlaylist: null,
                    onOpenAlbum: () {},
                  ),
                  itemBuilder: (context, index) {
                    final track = sortedTracks[index];
                    final album = albumByTrackId[track.id]!;
                    return _CollectionTrackRow(
                      track: track,
                      album: album,
                      favorite: widget.userState?.isFavorite(track.id) ?? false,
                      onTap: () =>
                          widget.playback.playTrack(track, queue: sortedTracks),
                      onPlayNext: () => widget.playback.playNext(track),
                      onToggleFavorite: widget.userState == null
                          ? null
                          : () => unawaited(
                              widget.userState!.toggleFavorite(track),
                            ),
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
          ],
        ),
      ),
    );
  }

  List<Track> _sortTracks(List<Track> tracks) {
    if (_trackSort == LibraryCollectionTrackSort.libraryOrder) return tracks;
    final sorted = [...tracks];
    sorted.sort(switch (_trackSort) {
      LibraryCollectionTrackSort.libraryOrder => (_, _) => 0,
      LibraryCollectionTrackSort.title => (left, right) => _compareText(
        left.title,
        right.title,
      ),
      LibraryCollectionTrackSort.artist => (left, right) => _compareThen(
        _compareText(left.artist, right.artist),
        () => _compareText(left.title, right.title),
      ),
      LibraryCollectionTrackSort.album => (left, right) => _compareThen(
        _compareText(left.albumTitle, right.albumTitle),
        () => _compareThen(
          left.trackNumber.compareTo(right.trackNumber),
          () => _compareText(left.title, right.title),
        ),
      ),
    });
    return sorted;
  }
}

int _compareText(String left, String right) =>
    left.toLowerCase().compareTo(right.toLowerCase());

int _compareThen(int comparison, int Function() next) =>
    comparison == 0 ? next() : comparison;

class _CollectionTrackHeader extends StatelessWidget {
  const _CollectionTrackHeader({
    required this.trackCount,
    required this.sort,
    required this.onSortChanged,
  });

  final int trackCount;
  final LibraryCollectionTrackSort sort;
  final ValueChanged<LibraryCollectionTrackSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(
          '$trackCount 首歌曲',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        PopupMenuButton<LibraryCollectionTrackSort>(
          key: const ValueKey('library-collection-track-sort-menu'),
          tooltip: '排序歌曲',
          initialValue: sort,
          onSelected: onSortChanged,
          itemBuilder: (context) => [
            for (final option in LibraryCollectionTrackSort.values)
              PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    Expanded(child: Text(option.label)),
                    if (option == sort) ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: SoundColors.accent,
                      ),
                    ],
                  ],
                ),
              ),
          ],
          child: DecoratedBox(
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
                  const Icon(Icons.sort_rounded, size: 17),
                  const SizedBox(width: 7),
                  Text(
                    sort.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CollectionHero extends StatelessWidget {
  const _CollectionHero({
    required this.collection,
    required this.onBack,
    required this.onPlay,
  });

  final LibraryCollection collection;
  final VoidCallback onBack;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              collection.kind == LibraryCollectionKind.artist ? '艺人' : '流派',
              style: TextStyle(
                color: collection.palette.first,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              collection.title,
              style: TextStyle(
                fontSize: compact ? 30 : 40,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${collection.albums.length} 张专辑 · ${collection.tracks.length} 首歌曲',
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('播放全部'),
              style: FilledButton.styleFrom(
                backgroundColor: SoundColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
            ),
          ],
        );
        final artwork = collection.albums.isEmpty
            ? const SizedBox.square(dimension: 220)
            : AlbumArt(
                album: collection.albums.first,
                size: compact ? 210 : 230,
              );

        return Container(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 34),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.65, 0.8),
              radius: 1.2,
              colors: [
                collection.palette.first.withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(height: 18),
              if (compact) ...[
                Center(child: artwork),
                const SizedBox(height: 28),
                details,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    artwork,
                    const SizedBox(width: 30),
                    Expanded(child: details),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CollectionAlbumCard extends StatelessWidget {
  const _CollectionAlbumCard({required this.album, required this.onTap});

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
          const SizedBox(height: 9),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _CollectionTrackRow extends StatelessWidget {
  const _CollectionTrackRow({
    required this.track,
    required this.album,
    required this.favorite,
    required this.onTap,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.onOpenAlbum,
  });

  final Track track;
  final Album album;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onPlayNext;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: ListTile(
        onTap: onTap,
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
          '${track.artist} · ${album.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SourceBadge(track.source),
            Text(
              formatDuration(track.duration),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '歌曲操作',
              onSelected: (value) {
                if (value == 'play-next') onPlayNext();
                if (value == 'open-album') onOpenAlbum();
                if (value == 'favorite') onToggleFavorite?.call();
                if (value == 'playlist') onAddToPlaylist?.call();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'play-next', child: Text('下一首播放')),
                const PopupMenuItem(value: 'open-album', child: Text('打开专辑')),
                if (onToggleFavorite != null)
                  PopupMenuItem(
                    value: 'favorite',
                    child: Row(
                      children: [
                        Icon(
                          favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: favorite ? SoundColors.accent : null,
                        ),
                        const SizedBox(width: 10),
                        Text(favorite ? '取消收藏' : '收藏歌曲'),
                      ],
                    ),
                  ),
                if (onAddToPlaylist != null)
                  const PopupMenuItem(
                    value: 'playlist',
                    child: Text('添加到播放列表'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
