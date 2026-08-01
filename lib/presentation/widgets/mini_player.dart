import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/brand_tokens.g.dart';
import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import '../controllers/library_user_state_controller.dart';
import 'album_art.dart';
import 'animated_artwork_background.dart';
import 'artwork_image_provider.dart';
import 'playback_visual_state.dart';
import 'progress_scrubber.dart';
import 'sound_components.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    required this.playback,
    this.userState,
    required this.onOpen,
    required this.compact,
    this.docked = false,
    this.embedded = false,
    this.onOpenQueue,
    super.key,
  });

  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final VoidCallback onOpen;
  final bool compact;
  final bool docked;
  final bool embedded;
  final VoidCallback? onOpenQueue;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([playback, ?userState]),
      builder: (context, _) {
        final track = playback.displayTrack;
        if (track == null) return const SizedBox.shrink();
        final visual = PlaybackVisualState.fromSnapshot(
          playback.snapshot,
          hasDisplayTrack: true,
        );
        final album = albumForTrack(track);
        final position = playback.displayPosition;
        final duration = playback.displayDuration;

        return _NowPlayingArtworkWarmup(
          album: album,
          compact: compact,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = docked
                  ? 76.0
                  : (compact
                        ? (embedded ? 66.0 : 72.0)
                        : (embedded ? 70.0 : 82.0));
              final content = SizedBox(
                height: height,
                child: docked
                    ? _DockedMiniPlayer(
                        track: track,
                        album: album,
                        visual: visual,
                        playback: playback,
                        userState: userState,
                        onOpen: onOpen,
                        onOpenQueue: onOpenQueue,
                        position: position,
                        duration: duration,
                      )
                    : _CondensedMiniPlayer(
                        track: track,
                        album: album,
                        visual: visual,
                        playback: playback,
                        onOpen: onOpen,
                        onOpenQueue: onOpenQueue,
                        position: position,
                        duration: duration,
                        compact: compact,
                        embedded: embedded,
                        availableWidth: constraints.maxWidth,
                      ),
              );
              if (embedded) return content;
              // Docked (desktop bottom bar): flush with the shell — no
              // perimeter border and no upward shadow. Both read as a
              // "lid" hairline on top of the bar. Mobile's compact dock
              // already uses a transparent border for the same reason.
              final retryBorder =
                  visual.primaryVisual == PlaybackPrimaryVisual.retry
                  ? context.soundColors.error
                  : null;
              return SoundGlassSurface(
                strong: true,
                // Docked bar sits over the extended body gradient; keep the
                // chrome slightly translucent so the canvas reads continuous
                // instead of a hard slab of solid surface.
                color: context.soundChromeSurface,
                showShadow: !docked,
                shadowOffset: const Offset(0, 10),
                borderRadius: docked
                    ? BorderRadius.zero
                    : BorderRadius.circular(compact ? 14 : 18),
                borderColor:
                    retryBorder ?? (docked ? Colors.transparent : null),
                child: content,
              );
            },
          ),
        );
      },
    );
  }
}

class _NowPlayingArtworkWarmup extends StatefulWidget {
  const _NowPlayingArtworkWarmup({
    required this.album,
    required this.compact,
    required this.child,
  });

  final Album album;
  final bool compact;
  final Widget child;

  @override
  State<_NowPlayingArtworkWarmup> createState() =>
      _NowPlayingArtworkWarmupState();
}

class _NowPlayingArtworkWarmupState extends State<_NowPlayingArtworkWarmup> {
  String? _warmupKey;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleWarmup();
  }

  @override
  void didUpdateWidget(covariant _NowPlayingArtworkWarmup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleWarmup();
  }

  void _scheduleWarmup() {
    final media = MediaQuery.of(context);
    final brightness = Theme.of(context).brightness;
    final dpr = media.devicePixelRatio;
    // Mini tile + now-playing hero sizes so the first open does not re-decode.
    final extents = <int>{
      quantizedArtworkCacheExtent(
        widget.compact
            ? math.min(120.0, math.max(1.0, media.size.width * 0.18))
            : 56.0,
        dpr,
      ),
      quantizedArtworkCacheExtent(280, dpr),
      quantizedArtworkCacheExtent(480, dpr),
    };
    final key = [
      widget.album.id,
      widget.album.artworkUri,
      brightness.name,
      ...extents,
    ].join('|');
    if (_warmupKey == key) return;
    _warmupKey = key;
    final generation = ++_generation;
    // Start after the visible frame, then decode sequentially. Fast devices
    // populate the cache early; slower devices avoid a burst of parallel work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      unawaited(
        _warmArtwork(
          album: widget.album,
          brightness: brightness,
          cacheExtents: extents,
        ),
      );
    });
  }

  Future<void> _warmArtwork({
    required Album album,
    required Brightness brightness,
    required Set<int> cacheExtents,
  }) async {
    try {
      await AnimatedArtworkBackground.prewarm(
        album: album,
        brightness: brightness,
      );
      for (final extent in cacheExtents) {
        if (!mounted) return;
        if (artworkImageProvider(
              album.artworkUri,
              cacheWidth: extent,
              cacheHeight: extent,
            )
            case final provider?) {
          await precacheImage(
            provider,
            context,
            // onError swallows PathNotFound / codec errors without the
            // IMAGE RESOURCE SERVICE red banner; AlbumArt has its own
            // errorBuilder placeholder.
            onError: (Object error, StackTrace? stackTrace) {},
          );
        }
      }
    } catch (_) {
      // The visible album art and background already have deterministic
      // fallbacks. Warmup failure must never affect playback or navigation.
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('now-playing-artwork-warmup'),
      child: widget.child,
    );
  }
}

class _DockedMiniPlayer extends StatelessWidget {
  const _DockedMiniPlayer({
    required this.track,
    required this.album,
    required this.visual,
    required this.playback,
    required this.userState,
    required this.onOpen,
    required this.onOpenQueue,
    required this.position,
    required this.duration,
  });

  final Track track;
  final Album album;
  final PlaybackVisualState visual;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final VoidCallback onOpen;
  final VoidCallback? onOpenQueue;
  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // The hover scrubber's time bubble overflows above the bar.
      clipBehavior: Clip.none,
      children: [
        // Whole bar opens now-playing; nested buttons win the arena.
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('mini-player-open-now-playing'),
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 16, 6),
              child: Row(
                children: [
                  _MiniArtwork(album: album, dimension: 48),
                  const SizedBox(width: 12),
                  // Title/artist + favorite stay together as one shrink-wrapped
                  // unit on the left; Expanded keeps the right-side controls
                  // pinned to the bar edge (a loose Flexible would leave slack
                  // that drags volume/lyrics toward the center).
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: _TrackIdentity(
                              track: track,
                              visual: visual,
                              prominent: false,
                              titleSize: 16,
                            ),
                          ),
                          if (userState case final state?) ...[
                            const SizedBox(width: 4),
                            _MiniIconButton(
                              icon: state.isFavorite(track.id)
                                  ? KaitingIcons.favoriteFilled
                                  : KaitingIcons.favorite,
                              color: state.isFavorite(track.id)
                                  ? SoundColors.accent
                                  : null,
                              tooltip: state.isFavorite(track.id)
                                  ? '取消收藏'
                                  : '收藏歌曲',
                              onTap: () =>
                                  unawaited(state.toggleFavorite(track)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _VolumeControl(playback: playback),
                  _MiniIconButton(
                    icon: KaitingIcons.lyrics,
                    tooltip: '打开歌词',
                    onTap: onOpen,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, 0.12),
            child: _TransportControls(
              playback: playback,
              visual: visual,
              onOpen: onOpen,
              onOpenQueue: onOpenQueue,
            ),
          ),
        ),
        // Top progress flush to the bar edge. Hovering grows the track,
        // reveals a thumb, and floats the scrub time above it.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 20,
          child: ProgressScrubber(
            key: const ValueKey('mini-player-progress'),
            position: position,
            duration: duration,
            onSeek: playback.seek,
            activeColor: SoundColors.accent,
            inactiveColor: context.soundTint(0.1),
            trackHeight: 3,
            hoverTrackHeight: 6,
            thumbRadius: 5,
            minInteractiveHeight: 20,
            // The 3px track must start exactly at the dock edge; -7 leaves a
            // 1.5px gap above it inside the 20px hit band.
            trackVerticalOffset: -8.5,
            padding: EdgeInsets.zero,
            interactive: true,
            hoverReveal: true,
            timeBubbleBuilder: (context, time) =>
                _MiniPlayerTimeBubble(time: time),
          ),
        ),
      ],
    );
  }
}

class _MiniPlayerTimeBubble extends StatelessWidget {
  const _MiniPlayerTimeBubble({required this.time});

  final Duration time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.soundGlass.strongSurface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: context.soundGlass.border),
        boxShadow: [
          BoxShadow(
            color: context.soundGlass.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        formatDuration(time),
        style: TextStyle(
          color: context.soundPrimaryText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _CondensedMiniPlayer extends StatelessWidget {
  const _CondensedMiniPlayer({
    required this.track,
    required this.album,
    required this.visual,
    required this.playback,
    required this.onOpen,
    required this.onOpenQueue,
    required this.position,
    required this.duration,
    required this.compact,
    required this.embedded,
    required this.availableWidth,
  });

  final Track track;
  final Album album;
  final PlaybackVisualState visual;
  final SoundPlaybackController playback;
  final VoidCallback onOpen;
  final VoidCallback? onOpenQueue;
  final Duration position;
  final Duration duration;
  final bool compact;
  final bool embedded;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final showPrevious = !compact && availableWidth >= 600;
    final showQueue = !compact && availableWidth >= 690;
    final foldableEmbedded = embedded && !compact;
    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            button: true,
            label: '打开正在播放',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('mini-player-open-now-playing'),
                onTap: onOpen,
                child: Padding(
                  key: const ValueKey('mini-player-condensed-content-padding'),
                  padding: compact
                      ? const EdgeInsets.all(6)
                      : foldableEmbedded
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
                      : EdgeInsets.all(availableWidth < 800 ? 8 : 14),
                  child: Row(
                    children: [
                      _MiniArtwork(album: album, dimension: compact ? 44 : 50),
                      const SizedBox(width: 11),
                      Expanded(
                        child: _TrackIdentity(
                          track: track,
                          visual: visual,
                          prominent: foldableEmbedded,
                        ),
                      ),
                      if (showPrevious)
                        _MiniIconButton(
                          icon: KaitingIcons.previousMini,
                          tooltip: '上一首',
                          onTap: playback.previous,
                          size: 23,
                        ),
                      _MiniIconButton(
                        key: const ValueKey('mini-player-playback-toggle'),
                        icon: _miniPrimaryIcon(visual),
                        tooltip: visual.primaryTooltip,
                        onTap: visual.primaryEnabled ? playback.toggle : null,
                        // Match now-playing: loading uses a spinner, not hourglass.
                        busy: visual.busy && !visual.primaryEnabled,
                        prominent: true,
                        size: _miniPrimaryIconSize(visual, compact: compact),
                        opticalOffset: _miniPrimaryOpticalOffset(visual),
                      ),
                      if (compact) const SizedBox(width: 6),
                      _MiniIconButton(
                        icon: KaitingIcons.nextMini,
                        tooltip: '下一首',
                        onTap: playback.next,
                        size: compact ? 20 : 23,
                      ),
                      if (showQueue)
                        _MiniIconButton(
                          icon: KaitingIcons.queue,
                          tooltip: '打开播放队列',
                          onTap: onOpenQueue ?? onOpen,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ProgressScrubber(
            key: const ValueKey('mini-player-progress'),
            position: position,
            duration: duration,
            onSeek: playback.seek,
            activeColor: embedded
                ? SoundColors.accent.withValues(alpha: 0.88)
                : context.soundPrimaryText,
            inactiveColor: context.soundTint(embedded ? 0.075 : 0.12),
            trackHeight: embedded ? 1.5 : 2.5,
            padding: EdgeInsets.zero,
            interactive: false,
          ),
        ),
      ],
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({required this.album, required this.dimension});

  final Album album;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: AlbumArt(album: album, borderRadius: 7),
    );
  }
}

class _TrackIdentity extends StatelessWidget {
  const _TrackIdentity({
    required this.track,
    required this.visual,
    required this.prominent,
    this.titleSize,
  });

  final Track track;
  final PlaybackVisualState visual;
  final bool prominent;
  final double? titleSize;

  @override
  Widget build(BuildContext context) {
    final componentProfile = context.soundComponentProfile;
    final titleFontSize =
        titleSize ??
        (prominent
            ? KaiProductTokens.typographyMiniPlayerTitleDocked
            : KaiProductTokens.typographyMiniPlayerTitleCondensed);
    final metadataFontSize = prominent
        ? KaiProductTokens.typographyMiniPlayerMetadataDocked
        : KaiProductTokens.typographyMiniPlayerMetadataCondensed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: componentProfile
                .listTitleStyle(
                  context.soundTheme.textTheme.bodyMedium,
                  color: context.soundPrimaryText,
                )
                .copyWith(fontSize: titleFontSize),
          ),
          const SizedBox(height: 2),
          Text(
            '${track.artist} — ${track.albumTitle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.soundSecondaryText,
              fontSize: metadataFontSize,
              height: componentProfile == SoundComponentProfile.mobile
                  ? KaiBrandMobileType.captionSmallLineHeight /
                        KaiBrandMobileType.captionSmallSize
                  : KaiBrandDesktopType.captionSmallLineHeight /
                        KaiBrandDesktopType.captionSmallSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.playback,
    required this.visual,
    required this.onOpen,
    this.onOpenQueue,
  });

  final SoundPlaybackController playback;
  final PlaybackVisualState visual;
  final VoidCallback onOpen;
  final VoidCallback? onOpenQueue;

  @override
  Widget build(BuildContext context) {
    final sideColor = context.soundPrimaryText.withValues(alpha: 0.60);
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MiniIconButton(
            key: const ValueKey('mini-player-mode-cycle'),
            icon: playback.playbackMode.icon,
            tooltip: playback.playbackMode.label,
            color: sideColor,
            onTap: () {
              playback.cycleCombinedPlaybackMode();
              showSoundSnackBar(context, playback.playbackMode.label);
            },
            size: 18,
          ),
          const SizedBox(width: 4),
          _MiniIconButton(
            icon: KaitingIcons.previousMini,
            tooltip: '上一首',
            onTap: playback.previous,
            size: 20,
          ),
          const SizedBox(width: 4),
          _MiniIconButton(
            key: const ValueKey('mini-player-playback-toggle'),
            icon: _miniPrimaryIcon(visual),
            tooltip: visual.primaryTooltip,
            onTap: visual.primaryEnabled ? playback.toggle : null,
            busy: visual.busy && !visual.primaryEnabled,
            prominent: true,
            size: _dockedPrimaryIconSize(visual),
            opticalOffset: _miniPrimaryOpticalOffset(visual),
          ),
          const SizedBox(width: 4),
          _MiniIconButton(
            icon: KaitingIcons.nextMini,
            tooltip: '下一首',
            onTap: playback.next,
            size: 20,
          ),
          const SizedBox(width: 4),
          _MiniIconButton(
            key: const ValueKey('mini-player-queue'),
            icon: KaitingIcons.queue,
            tooltip: '播放清单',
            color: sideColor,
            onTap: onOpenQueue ?? onOpen,
            size: 18,
          ),
        ],
      ),
    );
  }
}

IconData _miniPrimaryIcon(PlaybackVisualState visual) {
  return switch (visual.primaryVisual) {
    PlaybackPrimaryVisual.play => KaitingIcons.playMini,
    PlaybackPrimaryVisual.pause => KaitingIcons.pauseMini,
    _ => visual.primaryIcon,
  };
}

double _miniPrimaryIconSize(
  PlaybackVisualState visual, {
  bool compact = false,
}) {
  return switch (visual.primaryVisual) {
    PlaybackPrimaryVisual.play => compact ? 24 : 28,
    // Two solid pause bars carry more visual mass than the play triangle.
    PlaybackPrimaryVisual.pause => compact ? 20 : 23,
    PlaybackPrimaryVisual.replay ||
    PlaybackPrimaryVisual.retry => compact ? 20 : 22,
    PlaybackPrimaryVisual.none => compact ? 18 : 20,
  };
}

double _dockedPrimaryIconSize(PlaybackVisualState visual) {
  return switch (visual.primaryVisual) {
    PlaybackPrimaryVisual.play => 32,
    // Two solid pause bars carry more visual mass than the play triangle.
    PlaybackPrimaryVisual.pause => 26,
    PlaybackPrimaryVisual.replay || PlaybackPrimaryVisual.retry => 25,
    PlaybackPrimaryVisual.none => 22,
  };
}

Offset _miniPrimaryOpticalOffset(PlaybackVisualState visual) {
  return visual.primaryVisual == PlaybackPrimaryVisual.play
      ? const Offset(1, 0)
      : Offset.zero;
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onTap,
    this.size = 20,
    this.tooltip,
    this.color,
    this.busy = false,
    this.prominent = false,
    this.opticalOffset = Offset.zero,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final Color? color;
  final bool busy;
  final bool prominent;
  final Offset opticalOffset;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = prominent
        ? SoundColors.accent.withValues(alpha: enabled || busy ? 0.96 : 0.38)
        : color ??
              context.soundPrimaryText.withValues(
                alpha: enabled || busy ? 0.84 : 0.38,
              );
    return IconButton(
      onPressed: onTap,
      icon: busy
          ? SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : Transform.translate(
              offset: opticalOffset,
              child: Icon(icon, color: foreground, size: size),
            ),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: prominent
          ? IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              hoverColor: SoundColors.accent.withValues(alpha: 0.10),
              highlightColor: SoundColors.accent.withValues(alpha: 0.16),
              minimumSize: const Size.square(40),
              maximumSize: const Size.square(40),
              padding: EdgeInsets.zero,
            )
          : IconButton.styleFrom(
              minimumSize: const Size.square(40),
              maximumSize: const Size.square(40),
              padding: EdgeInsets.zero,
            ),
    );
  }
}

class _VolumeControl extends StatefulWidget {
  const _VolumeControl({required this.playback});

  final SoundPlaybackController playback;

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _removalTimer;
  bool _iconHovered = false;
  bool _overlayHovered = false;
  double _lastAudibleVolume = 1.0;

  IconData get _icon {
    final v = widget.playback.volume;
    if (v == 0) return KaitingIcons.mute;
    if (v < 0.5) return KaitingIcons.volumeLow;
    return KaitingIcons.volumeHigh;
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    _removalTimer?.cancel();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 44,
        height: 132,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -6),
          child: MouseRegion(
            onEnter: (_) {
              _removalTimer?.cancel();
              _overlayHovered = true;
            },
            onExit: (_) {
              _overlayHovered = false;
              _scheduleRemoval();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                key: const ValueKey('mini-player-volume-popup'),
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: context.soundGlass.strongSurface,
                  borderRadius: BorderRadius.circular(SoundRadii.menu),
                  border: Border.all(color: context.soundGlass.border),
                  boxShadow: [
                    BoxShadow(
                      color: context.soundGlass.shadow,
                      blurRadius: 24 * context.soundSkinEffects.shadowScale,
                      offset: Offset(
                        0,
                        10 * context.soundSkinEffects.shadowScale,
                      ),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: SoundColors.accent,
                        inactiveTrackColor: context.soundTint(0.12),
                      ),
                      child: AnimatedBuilder(
                        animation: widget.playback,
                        builder: (context, _) => Slider(
                          key: const ValueKey('mini-player-volume-slider'),
                          value: widget.playback.volume,
                          onChanged: _setVolume,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _setVolume(double value) {
    if (value > 0.001) _lastAudibleVolume = value;
    unawaited(widget.playback.setVolume(value));
  }

  void _scheduleRemoval() {
    _removalTimer?.cancel();
    _removalTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (!_iconHovered && !_overlayHovered) _removeOverlay();
    });
  }

  void _removeOverlay() {
    _removalTimer?.cancel();
    _removalTimer = null;
    final entry = _overlayEntry;
    _overlayEntry = null;
    entry?.remove();
  }

  void _toggleMute() {
    final volume = widget.playback.volume;
    if (volume > 0.001) {
      _lastAudibleVolume = volume;
      _setVolume(0);
    } else {
      _setVolume(_lastAudibleVolume.clamp(0.05, 1.0));
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.playback,
      builder: (context, _) {
        return CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            onEnter: (_) {
              _removalTimer?.cancel();
              _iconHovered = true;
              _showOverlay();
            },
            onExit: (_) {
              _iconHovered = false;
              _scheduleRemoval();
            },
            child: IconButton(
              key: const ValueKey('mini-player-volume-button'),
              icon: Icon(_icon),
              iconSize: 20,
              tooltip: '音量',
              onPressed: _toggleMute,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(40),
                maximumSize: const Size.square(40),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        );
      },
    );
  }
}
