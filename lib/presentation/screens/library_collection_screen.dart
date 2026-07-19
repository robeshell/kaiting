import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import '../controllers/library_user_state_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/animated_artwork_background.dart';
import '../widgets/progress_scrubber.dart';
import '../widgets/sound_components.dart';
import '../widgets/sound_metadata_line.dart';

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
    this.onOpenArtist,
    super.key,
  });

  final LibraryCollection collection;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final VoidCallback onBack;
  final ValueChanged<Album> onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;

  @override
  State<LibraryCollectionScreen> createState() =>
      _LibraryCollectionScreenState();
}

class _LibraryCollectionScreenState extends State<LibraryCollectionScreen> {
  LibraryCollectionTrackSort _trackSort =
      LibraryCollectionTrackSort.libraryOrder;
  late List<Color> _backgroundColors = artworkPageBackgroundColors(
    _collectionFallbackColors(widget.collection, Brightness.light),
    Brightness.light,
  );
  Brightness? _paletteBrightness;
  bool? _paletteCompact;
  String? _paletteRequest;
  Timer? _paletteLoadTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    final compact = context.soundIsCompact;
    if (_paletteBrightness != brightness || _paletteCompact != compact) {
      _paletteBrightness = brightness;
      _paletteCompact = compact;
      _refreshPalette(brightness: brightness, extractArtwork: compact);
    }
  }

  @override
  void didUpdateWidget(LibraryCollectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldArtwork = oldWidget.collection.albums.firstOrNull?.artworkUri;
    final newArtwork = widget.collection.albums.firstOrNull?.artworkUri;
    if (oldWidget.collection.id != widget.collection.id ||
        oldArtwork != newArtwork) {
      _refreshPalette(
        brightness: _paletteBrightness ?? Theme.of(context).brightness,
        extractArtwork: _paletteCompact ?? context.soundIsCompact,
      );
    }
  }

  void _refreshPalette({
    required Brightness brightness,
    required bool extractArtwork,
  }) {
    final collection = widget.collection;
    final artworkAlbum = collection.albums.firstOrNull;
    final request =
        '${collection.id}|${artworkAlbum?.artworkUri}|${brightness.name}';
    _paletteRequest = request;
    _backgroundColors = artworkPageBackgroundColors(
      _collectionFallbackColors(collection, brightness),
      brightness,
    );
    _paletteLoadTimer?.cancel();
    final artworkUri = artworkAlbum?.artworkUri?.trim();
    if (extractArtwork &&
        collection.kind == LibraryCollectionKind.artist &&
        artworkAlbum != null &&
        artworkUri != null &&
        artworkUri.isNotEmpty) {
      _paletteLoadTimer = Timer(const Duration(milliseconds: 320), () {
        if (!mounted || _paletteRequest != request) return;
        unawaited(_loadArtworkPalette(request, artworkAlbum, brightness));
      });
    }
  }

  @override
  void dispose() {
    _paletteLoadTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadArtworkPalette(
    String request,
    Album album,
    Brightness brightness,
  ) async {
    try {
      final scheme = await AnimatedArtworkBackground.colorSchemeForAlbum(
        album: album,
        brightness: brightness,
      );
      if (scheme == null || !mounted || _paletteRequest != request) return;
      final colors = artworkPageBackgroundColors(
        artworkGradientColorsFromScheme(scheme, brightness),
        brightness,
      );
      if (listEquals(colors, _backgroundColors)) return;
      setState(() => _backgroundColors = colors);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Artist artwork palette extraction failed: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final compact = context.soundIsCompact;
    final gutter = context.soundPageGutter;
    final bottomPadding = context.soundContentBottomPadding;
    final sortedTracks = _sortTracks(collection.tracks);
    final albumByTrackId = {
      for (final album in collection.albums)
        for (final track in album.tracks) track.id: album,
    };
    return AnimatedBuilder(
      animation: Listenable.merge([?widget.userState]),
      builder: (context, _) {
        final immersiveArtist =
            compact && collection.kind == LibraryCollectionKind.artist;
        final pagePalette = immersiveArtist
            ? ArtworkPagePalette.fromBackground(_backgroundColors)
            : null;
        final scrollView = CustomScrollView(
          key: PageStorageKey<String>(
            'library-collection-${collection.kind.name}-${collection.id}',
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _CollectionHero(
                collection: collection,
                onBack: widget.onBack,
                pagePalette: pagePalette,
                onPlay: sortedTracks.isEmpty
                    ? null
                    : () => widget.playback.playTrack(
                        sortedTracks.first,
                        queue: sortedTracks,
                      ),
                onShuffle: sortedTracks.isEmpty
                    ? null
                    : () {
                        widget.playback.setPlaybackMode(PlaybackMode.shuffle);
                        unawaited(
                          widget.playback.playTrack(
                            sortedTracks.first,
                            queue: sortedTracks,
                          ),
                        );
                      },
                onQueue: sortedTracks.isEmpty
                    ? null
                    : () {
                        for (final track in sortedTracks.reversed) {
                          widget.playback.playNext(track);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已添加到接下来播放')),
                        );
                      },
              ),
            ),
            if (collection.albums.isNotEmpty) ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  compact ? 4 : 8,
                  gutter,
                  compact ? 8 : 12,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '专辑',
                    style: TextStyle(
                      color: pagePalette?.primaryText,
                      fontSize: compact ? 17 : 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  0,
                  gutter,
                  compact ? 20 : 28,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final spacing = compact ? 12.0 : 16.0;
                    final maxCardWidth = compact ? 180.0 : 210.0;
                    final columnCount =
                        ((constraints.crossAxisExtent + spacing) /
                                (maxCardWidth + spacing))
                            .ceil()
                            .clamp(1, 12);
                    final cardWidth =
                        (constraints.crossAxisExtent -
                            spacing * (columnCount - 1)) /
                        columnCount;
                    return SliverGrid.builder(
                      itemCount: collection.albums.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columnCount,
                        mainAxisExtent: cardWidth + 46,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                      ),
                      itemBuilder: (context, index) {
                        final album = collection.albums[index];
                        return _CollectionAlbumCard(
                          album: album,
                          pagePalette: pagePalette,
                          onTap: () => widget.onOpenAlbum(album),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
              sliver: SliverToBoxAdapter(
                child: _CollectionTrackHeader(
                  trackCount: sortedTracks.length,
                  sort: _trackSort,
                  pagePalette: pagePalette,
                  onSortChanged: (value) => setState(() => _trackSort = value),
                ),
              ),
            ),
            if (sortedTracks.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottomPadding),
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
                    onOpenArtist: () {},
                    pagePalette: pagePalette,
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
                      onOpenArtist: widget.onOpenArtist == null
                          ? null
                          : () => widget.onOpenArtist!(track.artist),
                      pagePalette: pagePalette,
                    );
                  },
                ),
              ),
          ],
        );
        final content = Material(color: Colors.transparent, child: scrollView);
        if (!immersiveArtist || pagePalette == null) return content;

        final overlayStyle =
            (pagePalette.useLightText
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  systemStatusBarContrastEnforced: false,
                );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  key: const ValueKey('artist-detail-background'),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _backgroundColors,
                      stops: const [0, 0.56, 1],
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: content),
            ],
          ),
        );
      },
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

List<Color> _collectionFallbackColors(
  LibraryCollection collection,
  Brightness brightness,
) {
  final album = collection.albums.firstOrNull;
  if (album != null) return artworkFallbackGradientColors(album, brightness);
  final first = collection.palette.first;
  final last = collection.palette.last;
  return [first, Color.lerp(first, last, 0.42)!, last];
}

class _CollectionTrackHeader extends StatelessWidget {
  const _CollectionTrackHeader({
    required this.trackCount,
    required this.sort,
    required this.onSortChanged,
    required this.pagePalette,
  });

  final int trackCount;
  final LibraryCollectionTrackSort sort;
  final ValueChanged<LibraryCollectionTrackSort> onSortChanged;
  final ArtworkPagePalette? pagePalette;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(
          '$trackCount 首歌曲',
          style: TextStyle(
            color: pagePalette?.primaryText,
            fontSize: compact ? 17 : 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        SoundMenuButton<LibraryCollectionTrackSort>(
          key: const ValueKey('library-collection-track-sort-menu'),
          tooltip: '排序歌曲',
          onSelected: onSortChanged,
          actions: [
            for (final option in LibraryCollectionTrackSort.values)
              SoundMenuAction(
                value: option,
                label: option.label,
                icon: Icons.sort_rounded,
                selected: option == sort,
              ),
          ],
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: pagePalette?.controlSurface ?? context.soundTint(0.045),
              border: Border.all(
                color: pagePalette?.divider ?? context.soundDivider,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 7 : 9,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sort_rounded,
                    size: 17,
                    color: pagePalette?.primaryText,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    sort.label,
                    style: TextStyle(
                      color: pagePalette?.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: pagePalette?.primaryText,
                  ),
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
    required this.onShuffle,
    required this.onQueue,
    required this.pagePalette,
  });

  final LibraryCollection collection;
  final VoidCallback onBack;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;
  final VoidCallback? onQueue;
  final ArtworkPagePalette? pagePalette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final desktopArtist =
            collection.kind == LibraryCollectionKind.artist &&
            !context.soundIsCompact;
        if (desktopArtist) {
          return _buildDesktopArtist(context, constraints);
        }
        if (compact && collection.kind == LibraryCollectionKind.artist) {
          return _buildCompactArtist(context, constraints);
        }
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!compact) ...[
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
            ],
            Text(
              collection.title,
              style: TextStyle(
                fontSize: compact ? 24 : 34,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              '${collection.albums.length} 张专辑 · ${collection.tracks.length} 首歌曲',
              style: TextStyle(fontSize: 12, color: context.soundMutedText),
            ),
            SizedBox(height: compact ? 14 : 20),
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('播放全部'),
              style: FilledButton.styleFrom(
                minimumSize: Size(0, compact ? 40 : 44),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 20,
                  vertical: compact ? 8 : 11,
                ),
              ),
            ),
          ],
        );
        final artwork = collection.albums.isEmpty
            ? SizedBox.square(dimension: compact ? 156 : 220)
            : AlbumArt(
                key: const ValueKey('collection-detail-artwork'),
                album: collection.albums.first,
                size: compact ? 156 : 220,
              );

        return Container(
          key: const ValueKey('collection-detail-hero'),
          padding: EdgeInsets.fromLTRB(
            context.soundPageGutter,
            compact ? 8 : 20,
            context.soundPageGutter,
            compact ? 18 : 30,
          ),
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
                style: compact
                    ? IconButton.styleFrom(
                        minimumSize: const Size.square(40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                    : null,
              ),
              SizedBox(height: compact ? 4 : 18),
              if (compact) ...[
                Center(child: artwork),
                const SizedBox(height: 16),
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

  Widget _buildCompactArtist(BuildContext context, BoxConstraints constraints) {
    final palette = pagePalette!;
    final artworkSize = (constraints.maxWidth * 0.59)
        .clamp(204.0, 244.0)
        .toDouble();
    final artworkCacheExtent = quantizedArtworkCacheExtent(
      (constraints.maxWidth - context.soundPageGutter * 2 - 12) / 2,
      MediaQuery.devicePixelRatioOf(context),
    );
    final artwork = collection.albums.isEmpty
        ? Container(
            key: const ValueKey('collection-detail-artwork'),
            width: artworkSize,
            height: artworkSize,
            decoration: BoxDecoration(
              color: palette.controlSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_rounded,
              size: artworkSize * 0.34,
              color: palette.mutedText,
            ),
          )
        : AlbumArt(
            key: const ValueKey('collection-detail-artwork'),
            album: collection.albums.first,
            size: artworkSize,
            borderRadius: 14,
            cacheExtent: artworkCacheExtent,
          );

    return Container(
      key: const ValueKey('collection-detail-hero'),
      padding: EdgeInsets.fromLTRB(
        context.soundPageGutter,
        MediaQuery.paddingOf(context).top + 4,
        context.soundPageGutter,
        22,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              tooltip: '返回',
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                foregroundColor: palette.primaryText,
                minimumSize: const Size.square(40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: artwork),
          const SizedBox(height: 18),
          Text(
            collection.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 28,
              height: 1.06,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${collection.albums.length} 张专辑 · '
            '${collection.tracks.length} 首歌曲',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              _CollectionImmersiveAction(
                tooltip: '随机播放',
                icon: Icons.shuffle_rounded,
                onPressed: onShuffle,
                palette: palette,
              ),
              const Spacer(),
              _CollectionImmersiveAction(
                key: const ValueKey('mobile-artist-play'),
                tooltip: '播放全部',
                icon: Icons.play_arrow_rounded,
                onPressed: onPlay,
                palette: palette,
                dimension: 60,
                iconSize: 30,
                emphasized: true,
              ),
              const Spacer(),
              _CollectionImmersiveAction(
                tooltip: '接下来播放全部歌曲',
                icon: Icons.queue_music_rounded,
                onPressed: onQueue,
                palette: palette,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopArtist(BuildContext context, BoxConstraints constraints) {
    final artworkSize = (constraints.maxWidth * 0.36)
        .clamp(280.0, 420.0)
        .toDouble();
    final buttonWidth = constraints.maxWidth >= 1040 ? 146.0 : 132.0;
    final horizontalGap = constraints.maxWidth >= 1000 ? 48.0 : 32.0;
    final artwork = collection.albums.isEmpty
        ? Container(
            key: const ValueKey('collection-detail-artwork'),
            width: artworkSize,
            height: artworkSize,
            decoration: BoxDecoration(
              color: context.soundTint(0.045),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_rounded,
              size: artworkSize * 0.34,
              color: context.soundMutedText,
            ),
          )
        : AlbumArt(
            key: const ValueKey('collection-detail-artwork'),
            album: collection.albums.first,
            size: artworkSize,
            borderRadius: 12,
          );

    return Container(
      key: const ValueKey('collection-detail-hero'),
      padding: EdgeInsets.fromLTRB(
        context.soundPageGutter,
        8,
        context.soundPageGutter,
        30,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.soundDivider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('desktop-artist-back'),
                onPressed: onBack,
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              SoundMenuButton<String>(
                key: const ValueKey('desktop-artist-actions'),
                enabled: onPlay != null,
                tooltip: '更多艺人操作',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  if (value == 'play') onPlay?.call();
                  if (value == 'shuffle') onShuffle?.call();
                },
                actions: const [
                  SoundMenuAction(
                    value: 'play',
                    label: '播放全部',
                    icon: Icons.play_arrow_rounded,
                  ),
                  SoundMenuAction(
                    value: 'shuffle',
                    label: '随机播放',
                    icon: Icons.shuffle_rounded,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              artwork,
              SizedBox(width: horizontalGap),
              Expanded(
                child: SizedBox(
                  height: artworkSize,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 38,
                          height: 1.04,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${collection.albums.length} 张专辑 · '
                        '${collection.tracks.length} 首歌曲',
                        style: TextStyle(
                          color: context.soundMutedText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      LayoutBuilder(
                        builder: (context, buttonConstraints) {
                          final condensed =
                              buttonConstraints.maxWidth < buttonWidth * 2 + 16;
                          final playButton = _DesktopCollectionActionButton(
                            key: const ValueKey('desktop-artist-play'),
                            label: '播放全部',
                            icon: Icons.play_arrow_rounded,
                            showIcon: !condensed,
                            onPressed: onPlay,
                          );
                          final shuffleButton = _DesktopCollectionActionButton(
                            key: const ValueKey('desktop-artist-shuffle'),
                            label: '随机播放',
                            icon: Icons.shuffle_rounded,
                            showIcon: !condensed,
                            onPressed: onShuffle,
                          );
                          return Row(
                            children: [
                              if (condensed)
                                Expanded(child: playButton)
                              else
                                SizedBox(width: buttonWidth, child: playButton),
                              SizedBox(width: condensed ? 8 : 16),
                              if (condensed)
                                Expanded(child: shuffleButton)
                              else
                                SizedBox(
                                  width: buttonWidth,
                                  child: shuffleButton,
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionImmersiveAction extends StatelessWidget {
  const _CollectionImmersiveAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.palette,
    this.dimension = 52,
    this.iconSize = 24,
    this.emphasized = false,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final ArtworkPagePalette palette;
  final double dimension;
  final double iconSize;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final surface = emphasized
        ? palette.primaryText.withValues(
            alpha: palette.useLightText ? 0.20 : 0.14,
          )
        : palette.controlSurface;
    return SizedBox.square(
      dimension: dimension,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: iconSize),
        style: IconButton.styleFrom(
          foregroundColor: palette.primaryText,
          backgroundColor: surface,
          disabledForegroundColor: palette.primaryText.withValues(alpha: 0.3),
          disabledBackgroundColor: surface.withValues(alpha: 0.45),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _DesktopCollectionActionButton extends StatelessWidget {
  const _DesktopCollectionActionButton({
    required this.label,
    required this.icon,
    required this.showIcon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool showIcon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: EdgeInsets.symmetric(horizontal: showIcon ? 14 : 8),
    );
    if (!showIcon) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label, maxLines: 1),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, maxLines: 1),
      style: style,
    );
  }
}

class _CollectionAlbumCard extends StatelessWidget {
  const _CollectionAlbumCard({
    required this.album,
    required this.onTap,
    required this.pagePalette,
  });

  final Album album;
  final VoidCallback onTap;
  final ArtworkPagePalette? pagePalette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlbumArt(album: album),
          const SizedBox(height: 7),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: pagePalette?.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: pagePalette?.secondaryText ?? context.soundSecondaryText,
            ),
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
    this.onOpenArtist,
    required this.pagePalette,
  });

  final Track track;
  final Album album;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onPlayNext;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback onOpenAlbum;
  final VoidCallback? onOpenArtist;
  final ArtworkPagePalette? pagePalette;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    final metaStyle = TextStyle(
      fontSize: compact ? 12 : 12,
      color: pagePalette?.mutedText ?? context.soundSecondaryText,
    );
    final metadata = SoundMetadataLine(
      artist: track.artist,
      album: album.title,
      separator: compact ? ' — ' : ' · ',
      onOpenArtist: onOpenArtist,
      onOpenAlbum: onOpenAlbum,
      style: metaStyle,
    );
    return SoundTrackActivation(
      onActivate: onTap,
      semanticLabel: track.title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: pagePalette?.divider ?? context.soundDivider,
              ),
            ),
          ),
          child: compact
              ? SoundCompactMediaRow(
                  key: ValueKey('collection-track-row-${track.id}'),
                  leading: AlbumArt(album: album, borderRadius: 8),
                  title: track.title,
                  titleColor: pagePalette?.primaryText,
                  subtitleWidget: metadata,
                  subtitleColor: pagePalette?.mutedText,
                  trailing: _actions(compact: true),
                )
              : SoundListRow(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  leading: SizedBox.square(
                    dimension: 48,
                    child: AlbumArt(album: album, borderRadius: 6),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: metadata,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatDuration(track.duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.soundSecondaryText,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _actions(compact: false),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _actions({required bool compact}) {
    return SoundMenuButton<String>(
      key: ValueKey('collection-track-actions-${track.id}'),
      tooltip: '更多操作 ${track.title}',
      menuTitle: track.title,
      padding: EdgeInsets.zero,
      icon: Icon(
        compact ? Icons.more_horiz_rounded : Icons.more_vert_rounded,
        size: compact ? 21 : 20,
        color: compact ? pagePalette?.primaryText : null,
      ),
      onSelected: (value) {
        if (value == 'play-next') onPlayNext();
        if (value == 'open-album') onOpenAlbum();
        if (value == 'favorite') onToggleFavorite?.call();
        if (value == 'playlist') onAddToPlaylist?.call();
      },
      actions: [
        const SoundMenuAction(
          value: 'play-next',
          label: '下一首播放',
          icon: Icons.playlist_play_rounded,
        ),
        const SoundMenuAction(
          value: 'open-album',
          label: '打开专辑',
          icon: Icons.album_outlined,
        ),
        if (onToggleFavorite != null)
          SoundMenuAction(
            value: 'favorite',
            label: favorite ? '取消收藏' : '收藏歌曲',
            icon: favorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            selected: favorite,
          ),
        if (onAddToPlaylist != null)
          const SoundMenuAction(
            value: 'playlist',
            label: '添加到播放列表',
            icon: Icons.playlist_add_rounded,
          ),
      ],
    );
  }
}
