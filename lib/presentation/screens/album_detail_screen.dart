import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../offline/offline_media_provider.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import '../controllers/library_user_state_controller.dart';
import '../controllers/offline_download_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/animated_artwork_background.dart';
import '../widgets/progress_scrubber.dart';
import '../widgets/sound_components.dart';

class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({
    required this.album,
    required this.playback,
    this.userState,
    this.offline,
    required this.onBack,
    this.onOpenArtist,
    super.key,
  });

  final Album album;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final OfflineDownloadController? offline;
  final VoidCallback onBack;
  final ValueChanged<String>? onOpenArtist;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  late List<Color> _backgroundColors = artworkPageBackgroundColors(
    artworkFallbackGradientColors(widget.album, Brightness.light),
    Brightness.light,
  );
  Brightness? _paletteBrightness;
  bool? _paletteCompact;
  String? _paletteRequest;
  Timer? _paletteLoadTimer;

  Album get album => widget.album;
  SoundPlaybackController get playback => widget.playback;
  LibraryUserStateController? get userState => widget.userState;
  OfflineDownloadController? get offline => widget.offline;
  VoidCallback get onBack => widget.onBack;

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
  void didUpdateWidget(AlbumDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.album.id != widget.album.id ||
        oldWidget.album.artworkUri != widget.album.artworkUri) {
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
    final request = '${album.id}|${album.artworkUri}|${brightness.name}';
    _paletteRequest = request;
    _backgroundColors = artworkPageBackgroundColors(
      artworkFallbackGradientColors(album, brightness),
      brightness,
    );
    _paletteLoadTimer?.cancel();
    final artworkUri = album.artworkUri?.trim();
    if (extractArtwork && artworkUri != null && artworkUri.isNotEmpty) {
      _paletteLoadTimer = Timer(const Duration(milliseconds: 320), () {
        if (!mounted || _paletteRequest != request) return;
        unawaited(_loadArtworkPalette(request, brightness));
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
        debugPrint('Album artwork palette extraction failed: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([playback, ?userState, ?offline]),
        builder: (context, _) {
          final compact = context.soundIsCompact;
          final pagePalette = compact
              ? ArtworkPagePalette.fromBackground(_backgroundColors)
              : null;
          final discNumbers = {
            for (final track in album.tracks) _effectiveDiscNumber(track),
          };
          final showDiscSections = discNumbers.length > 1;
          final scrollView = CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  album: album,
                  playback: playback,
                  offline: offline,
                  onBack: onBack,
                  onOpenArtist: widget.onOpenArtist,
                  pagePalette: pagePalette,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  context.soundPageGutter,
                  8,
                  context.soundPageGutter,
                  context.soundContentBottomPadding,
                ),
                sliver: SliverList.builder(
                  itemCount: album.tracks.length,
                  itemBuilder: (context, index) {
                    final track = album.tracks[index];
                    final active = playback.currentTrack?.id == track.id;
                    final discNumber = _effectiveDiscNumber(track);
                    final startsDisc =
                        showDiscSections &&
                        (index == 0 ||
                            _effectiveDiscNumber(album.tracks[index - 1]) !=
                                discNumber);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (startsDisc)
                          _DiscHeader(
                            number: discNumber,
                            pagePalette: pagePalette,
                          ),
                        _TrackRow(
                          track: track,
                          active: active,
                          favorite: userState?.isFavorite(track.id) ?? false,
                          onTap: () =>
                              playback.playTrack(track, queue: album.tracks),
                          onPlayNext: () => playback.playNext(track),
                          onToggleFavorite: userState == null
                              ? null
                              : () =>
                                    unawaited(userState!.toggleFavorite(track)),
                          onAddToPlaylist: userState == null
                              ? null
                              : () => showAddToPlaylistSheet(
                                  context,
                                  userState: userState!,
                                  track: track,
                                ),
                          offline: offline,
                          pagePalette: pagePalette,
                          onToggleOffline:
                              offline == null || !offline!.supports(track)
                              ? null
                              : () => unawaited(
                                  _toggleTrackOffline(context, offline!, track),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
          if (!compact || pagePalette == null) return scrollView;

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
                    key: const ValueKey('album-detail-background'),
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
                Positioned.fill(child: scrollView),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.album,
    required this.playback,
    required this.offline,
    required this.onBack,
    required this.pagePalette,
    this.onOpenArtist,
  });

  final Album album;
  final SoundPlaybackController playback;
  final OfflineDownloadController? offline;
  final VoidCallback onBack;
  final ArtworkPagePalette? pagePalette;
  final ValueChanged<String>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = context.soundIsCompact;
        final discCount = {
          for (final track in album.tracks) _effectiveDiscNumber(track),
        }.length;
        final metadata = [
          if (album.genre?.trim().isNotEmpty == true) album.genre!,
          if (album.year != null) '${album.year}',
          if (discCount > 1) '$discCount 张碟',
          '${album.tracks.length} 首歌',
        ].join(' · ');
        final supportedTracks = offline == null
            ? const <Track>[]
            : album.tracks.where(offline!.supports).toList(growable: false);
        final allOffline =
            supportedTracks.isNotEmpty &&
            offline!.areAllPinned(supportedTracks);
        final downloading =
            supportedTracks.isNotEmpty &&
            offline!.isDownloadingAny(supportedTracks);
        final offlineProgress = supportedTracks.isEmpty
            ? null
            : offline!.progressFor(supportedTracks);
        final offlineCount = supportedTracks.isEmpty
            ? 0
            : offline!.pinnedCount(supportedTracks);
        final offlineLabel = downloading
            ? '取消下载 ${((offlineProgress ?? 0) * 100).round()}%'
            : allOffline
            ? '已离线'
            : offlineCount > 0
            ? '继续下载 $offlineCount/${supportedTracks.length}'
            : '离线保存';

        if (compact) {
          final palette = pagePalette!;
          final artworkSize = (constraints.maxWidth * 0.59)
              .clamp(204.0, 244.0)
              .toDouble();
          final artworkCacheExtent = quantizedArtworkCacheExtent(
            (constraints.maxWidth - context.soundPageGutter * 2 - 12) / 2,
            MediaQuery.devicePixelRatioOf(context),
          );
          return Container(
            key: const ValueKey('album-detail-hero'),
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
                Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      tooltip: '返回',
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: palette.primaryText,
                        minimumSize: const Size.square(40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const Spacer(),
                    if (supportedTracks.isNotEmpty)
                      IconButton(
                        key: const ValueKey('album-offline-action'),
                        onPressed: () => unawaited(
                          _toggleAlbumOffline(context, offline!, album),
                        ),
                        tooltip: offlineLabel,
                        icon: downloading
                            ? const Icon(Icons.close_rounded)
                            : Icon(
                                allOffline
                                    ? Icons.cloud_done_rounded
                                    : Icons.download_for_offline_outlined,
                              ),
                        style: IconButton.styleFrom(
                          foregroundColor: palette.primaryText,
                          backgroundColor: palette.controlSurface,
                          minimumSize: const Size.square(40),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: AlbumArt(
                    key: const ValueKey('album-detail-artwork'),
                    album: album,
                    size: artworkSize,
                    borderRadius: 14,
                    cacheExtent: artworkCacheExtent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  key: const ValueKey('album-detail-title'),
                  album.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 25,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.75,
                  ),
                ),
                const SizedBox(height: 7),
                InkWell(
                  onTap: onOpenArtist == null
                      ? null
                      : () => onOpenArtist!(album.artist),
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    key: const ValueKey('album-detail-artist'),
                    album.artist,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 15,
                      height: 1.22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  metadata,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 19),
                Row(
                  children: [
                    _ImmersiveAlbumAction(
                      tooltip: '随机播放',
                      icon: Icons.shuffle_rounded,
                      onPressed: album.tracks.isEmpty
                          ? null
                          : () {
                              playback.setPlaybackMode(PlaybackMode.shuffle);
                              unawaited(
                                playback.playTrack(
                                  album.tracks.first,
                                  queue: album.tracks,
                                ),
                              );
                            },
                      palette: palette,
                    ),
                    const Spacer(),
                    _ImmersiveAlbumAction(
                      key: const ValueKey('album-detail-play'),
                      tooltip: '播放整张专辑',
                      icon: Icons.play_arrow_rounded,
                      onPressed: album.tracks.isEmpty
                          ? null
                          : () => playback.playTrack(
                              album.tracks.first,
                              queue: album.tracks,
                            ),
                      palette: palette,
                      dimension: 60,
                      iconSize: 30,
                      emphasized: true,
                    ),
                    const Spacer(),
                    _ImmersiveAlbumAction(
                      tooltip: '接下来播放整张专辑',
                      icon: Icons.queue_music_rounded,
                      onPressed: album.tracks.isEmpty
                          ? null
                          : () {
                              for (final track in album.tracks.reversed) {
                                playback.playNext(track);
                              }
                              _showAlbumMessage(context, '已添加到接下来播放');
                            },
                      palette: palette,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final artworkSize = (constraints.maxWidth * 0.36)
            .clamp(280.0, 420.0)
            .toDouble();
        final buttonWidth = constraints.maxWidth >= 1040 ? 146.0 : 132.0;
        final horizontalGap = constraints.maxWidth >= 1000 ? 48.0 : 32.0;

        return Container(
          key: const ValueKey('album-detail-hero'),
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
                    key: const ValueKey('desktop-album-back'),
                    onPressed: onBack,
                    tooltip: '返回',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  if (supportedTracks.isNotEmpty)
                    IconButton.filledTonal(
                      key: const ValueKey('album-offline-action'),
                      onPressed: () => unawaited(
                        _toggleAlbumOffline(context, offline!, album),
                      ),
                      tooltip: offlineLabel,
                      icon: downloading
                          ? const Icon(Icons.close_rounded)
                          : Icon(
                              allOffline
                                  ? Icons.cloud_done_rounded
                                  : Icons.download_for_offline_outlined,
                            ),
                    ),
                  const SizedBox(width: 8),
                  SoundMenuButton<String>(
                    key: const ValueKey('desktop-album-actions'),
                    tooltip: '更多专辑操作',
                    menuTitle: album.title,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) {
                      if (value == 'shuffle' && album.tracks.isNotEmpty) {
                        playback.setPlaybackMode(PlaybackMode.shuffle);
                        unawaited(
                          playback.playTrack(
                            album.tracks.first,
                            queue: album.tracks,
                          ),
                        );
                      }
                      if (value == 'offline' && supportedTracks.isNotEmpty) {
                        unawaited(
                          _toggleAlbumOffline(context, offline!, album),
                        );
                      }
                    },
                    actions: [
                      const SoundMenuAction(
                        value: 'shuffle',
                        label: '随机播放',
                        icon: Icons.shuffle_rounded,
                      ),
                      if (supportedTracks.isNotEmpty)
                        SoundMenuAction(
                          value: 'offline',
                          label: offlineLabel,
                          icon: allOffline
                              ? Icons.cloud_done_rounded
                              : Icons.download_for_offline_outlined,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AlbumArt(
                    key: const ValueKey('album-detail-artwork'),
                    album: album,
                    size: artworkSize,
                    borderRadius: 12,
                  ),
                  SizedBox(width: horizontalGap),
                  Expanded(
                    child: SizedBox(
                      height: artworkSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 38,
                              height: 1.04,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: onOpenArtist == null
                                ? null
                                : () => onOpenArtist!(album.artist),
                            borderRadius: BorderRadius.circular(8),
                            child: Text(
                              key: const ValueKey('album-detail-artist-desktop'),
                              album.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: SoundColors.accent,
                                fontSize: 28,
                                height: 1.08,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            metadata,
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
                                  buttonConstraints.maxWidth <
                                  buttonWidth * 2 + 16;
                              final playButton = _DesktopAlbumActionButton(
                                key: const ValueKey('desktop-album-play'),
                                label: '播放',
                                icon: Icons.play_arrow_rounded,
                                showIcon: !condensed,
                                onPressed: album.tracks.isEmpty
                                    ? null
                                    : () => playback.playTrack(
                                        album.tracks.first,
                                        queue: album.tracks,
                                      ),
                              );
                              final shuffleButton = _DesktopAlbumActionButton(
                                key: const ValueKey('desktop-album-shuffle'),
                                label: '随机播放',
                                icon: Icons.shuffle_rounded,
                                showIcon: !condensed,
                                onPressed: album.tracks.isEmpty
                                    ? null
                                    : () {
                                        playback.setPlaybackMode(
                                          PlaybackMode.shuffle,
                                        );
                                        unawaited(
                                          playback.playTrack(
                                            album.tracks.first,
                                            queue: album.tracks,
                                          ),
                                        );
                                      },
                              );
                              return Row(
                                children: [
                                  if (condensed)
                                    Expanded(child: playButton)
                                  else
                                    SizedBox(
                                      width: buttonWidth,
                                      child: playButton,
                                    ),
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
      },
    );
  }
}

class _ImmersiveAlbumAction extends StatelessWidget {
  const _ImmersiveAlbumAction({
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
    return SizedBox.square(
      dimension: dimension,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: iconSize),
        style: IconButton.styleFrom(
          foregroundColor: palette.primaryText,
          backgroundColor: emphasized
              ? palette.primaryText.withValues(
                  alpha: palette.useLightText ? 0.20 : 0.14,
                )
              : palette.controlSurface,
          disabledForegroundColor: palette.primaryText.withValues(alpha: 0.3),
          disabledBackgroundColor: palette.controlSurface.withValues(
            alpha: 0.45,
          ),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _DesktopAlbumActionButton extends StatelessWidget {
  const _DesktopAlbumActionButton({
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

class _DiscHeader extends StatelessWidget {
  const _DiscHeader({required this.number, required this.pagePalette});

  final int number;
  final ArtworkPagePalette? pagePalette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 8),
      child: Row(
        children: [
          Text(
            '第 $number 碟',
            style: TextStyle(
              color: SoundColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: pagePalette?.divider ?? context.soundDivider),
          ),
        ],
      ),
    );
  }
}

int _effectiveDiscNumber(Track track) =>
    track.discNumber > 0 ? track.discNumber : 1;

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.active,
    required this.favorite,
    required this.onTap,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.offline,
    required this.onToggleOffline,
    required this.pagePalette,
  });

  final Track track;
  final bool active;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onPlayNext;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToPlaylist;
  final OfflineDownloadController? offline;
  final VoidCallback? onToggleOffline;
  final ArtworkPagePalette? pagePalette;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    final offlineTask = offline?.taskFor(track);
    final downloading =
        offlineTask?.state == OfflineDownloadTaskState.downloading;
    final failed = offlineTask?.state == OfflineDownloadTaskState.failed;
    return SoundTrackActivation(
      onActivate: onTap,
      semanticLabel: track.title,
      child: Container(
        key: ValueKey('album-track-row-${track.id}'),
        constraints: BoxConstraints.tightFor(height: compact ? 64 : 68),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 18),
        decoration: BoxDecoration(
          color: active
              ? compact && pagePalette != null
                    ? pagePalette!.controlSurface
                    : SoundColors.accent.withValues(alpha: 0.035)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: pagePalette?.divider ?? context.soundDivider,
            ),
          ),
        ),
        child: compact
            ? SoundCompactMediaRow(
                leading: active
                    ? Icon(
                        Icons.graphic_eq_rounded,
                        color: SoundColors.accent,
                        size: 18,
                      )
                    : Text(
                        track.trackNumber > 0 ? '${track.trackNumber}' : '–',
                        style: TextStyle(
                          color:
                              pagePalette?.secondaryText ??
                              context.soundSecondaryText,
                        ),
                      ),
                title: track.title,
                titleColor: active
                    ? SoundColors.accent
                    : pagePalette?.primaryText,
                subtitle: '${track.artist} — ${formatDuration(track.duration)}',
                subtitleColor: pagePalette?.mutedText,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onToggleOffline != null)
                      _TrackOfflineIndicator(track: track, offline: offline!),
                    _actions(
                      compact: true,
                      downloading: downloading,
                      failed: failed,
                      iconColor: pagePalette?.primaryText,
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: active
                        ? Icon(
                            Icons.graphic_eq_rounded,
                            color: SoundColors.accent,
                            size: 18,
                          )
                        : Text(
                            track.trackNumber > 0
                                ? '${track.trackNumber}'
                                : '–',
                            style: TextStyle(color: context.soundSecondaryText),
                          ),
                  ),
                  Expanded(
                    child: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? SoundColors.accent
                            : pagePalette?.primaryText ??
                                  context.soundPrimaryText,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (onToggleOffline != null) ...[
                    _TrackOfflineIndicator(track: track, offline: offline!),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    formatDuration(track.duration),
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          pagePalette?.secondaryText ??
                          context.soundSecondaryText,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  _actions(
                    compact: false,
                    downloading: downloading,
                    failed: failed,
                    iconColor: pagePalette?.primaryText,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _actions({
    required bool compact,
    required bool downloading,
    required bool failed,
    required Color? iconColor,
  }) {
    return SoundMenuButton<String>(
      key: ValueKey('track-actions-${track.id}'),
      tooltip: '更多操作 ${track.title}',
      menuTitle: track.title,
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz_rounded, size: 21, color: iconColor),
      onSelected: (value) {
        if (value == 'play-next') onPlayNext();
        if (value == 'favorite') onToggleFavorite?.call();
        if (value == 'playlist') onAddToPlaylist?.call();
        if (value == 'offline') onToggleOffline?.call();
      },
      actions: [
        const SoundMenuAction(
          value: 'play-next',
          label: '下一首播放',
          icon: Icons.playlist_play_rounded,
        ),
        if (onToggleFavorite != null)
          SoundMenuAction(
            value: 'favorite',
            label: favorite ? '取消收藏' : '收藏',
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
        if (onToggleOffline != null)
          SoundMenuAction(
            value: 'offline',
            label: downloading
                ? '取消下载'
                : offline!.isPinned(track)
                ? '移除离线下载'
                : failed
                ? '重试下载'
                : '离线保存',
            icon: downloading
                ? Icons.close_rounded
                : offline!.isPinned(track)
                ? Icons.cloud_off_outlined
                : failed
                ? Icons.refresh_rounded
                : Icons.download_for_offline_outlined,
            destructive: downloading || offline!.isPinned(track),
            dividerBefore: true,
          ),
      ],
    );
  }
}

class _TrackOfflineIndicator extends StatelessWidget {
  const _TrackOfflineIndicator({required this.track, required this.offline});

  final Track track;
  final OfflineDownloadController offline;

  @override
  Widget build(BuildContext context) {
    final task = offline.taskFor(track);
    if (task?.state == OfflineDownloadTaskState.downloading) {
      return SizedBox(
        width: 15,
        height: 15,
        child: CircularProgressIndicator(
          value: task?.progress,
          strokeWidth: 1.8,
          color: SoundColors.webDav,
        ),
      );
    }
    if (task?.state == OfflineDownloadTaskState.failed) {
      return Icon(
        Icons.error_outline_rounded,
        size: 16,
        color: SoundColors.accent,
      );
    }
    if (offline.isPinned(track)) {
      return const Icon(
        Icons.cloud_done_rounded,
        size: 16,
        color: SoundColors.webDav,
      );
    }
    return const SizedBox.shrink();
  }
}

Future<void> _toggleTrackOffline(
  BuildContext context,
  OfflineDownloadController offline,
  Track track,
) async {
  try {
    if (offline.isDownloading(track)) {
      offline.cancelTrack(track);
      if (context.mounted) {
        _showAlbumMessage(context, '已取消「${track.title}」的下载');
      }
    } else if (offline.isPinned(track)) {
      await offline.removeTrack(track);
      if (context.mounted) {
        _showAlbumMessage(context, '已移除「${track.title}」的离线下载');
      }
    } else {
      await offline.pinTrack(track);
      if (context.mounted) {
        _showAlbumMessage(context, '「${track.title}」已可离线播放');
      }
    }
  } on OfflineDownloadCancelledException {
    // The explicit cancel action already provided user feedback.
  } catch (_) {
    if (!context.mounted) return;
    final message = offline.taskFor(track)?.error ?? '下载失败，请检查网络与来源设置';
    _showAlbumMessage(context, message);
  }
}

Future<void> _toggleAlbumOffline(
  BuildContext context,
  OfflineDownloadController offline,
  Album album,
) async {
  if (offline.isDownloadingAny(album.tracks)) {
    offline.cancelTracks(album.tracks);
    _showAlbumMessage(context, '已取消「${album.title}」的剩余下载');
    return;
  }
  if (offline.areAllPinned(album.tracks)) {
    final confirmed = await _confirmRemoveOfflineAlbum(context, album.title);
    if (!confirmed || !context.mounted) return;
    await offline.removeTracks(album.tracks);
    if (context.mounted) {
      _showAlbumMessage(context, '已移除「${album.title}」的离线下载');
    }
    return;
  }

  final result = await offline.pinTracks(album.tracks);
  if (!context.mounted) return;
  if (result.wasCancelled) {
    return;
  } else if (result.hasFailures) {
    _showAlbumMessage(
      context,
      '已下载 ${result.completed} 首，${result.failed} 首失败，可稍后继续',
    );
  } else {
    _showAlbumMessage(context, '「${album.title}」已可离线播放');
  }
}

Future<bool> _confirmRemoveOfflineAlbum(
  BuildContext context,
  String albumTitle,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => SoundDialog(
          maxWidth: 400,
          title: const Text('移除离线下载？'),
          content: Text(
            '将删除「$albumTitle」已下载的音频，不会影响音乐来源中的原文件。',
            style: TextStyle(color: dialogContext.soundMutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: dialogContext.soundDestructiveButtonStyle,
              child: const Text('移除'),
            ),
          ],
        ),
      ) ??
      false;
}

void _showAlbumMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
