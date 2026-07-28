import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
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
              final wide = docked || (!compact && constraints.maxWidth >= 900);
              final height = docked
                  ? 76.0
                  : (compact ? (embedded ? 66.0 : 72.0) : (wide ? 58.0 : 82.0));
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
                    : wide
                    ? _WideMiniPlayer(
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
      await Future.wait([
        AnimatedArtworkBackground.prewarm(album: album, brightness: brightness),
        for (final extent in cacheExtents)
          if (artworkImageProvider(
                album.artworkUri,
                cacheWidth: extent,
                cacheHeight: extent,
              )
              case final provider?)
            precacheImage(
              provider,
              context,
              // onError swallows PathNotFound / codec errors without the
              // IMAGE RESOURCE SERVICE red banner; AlbumArt has its own
              // errorBuilder placeholder.
              onError: (Object error, StackTrace? stackTrace) {},
            ),
      ]);
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

class _WideMiniPlayer extends StatelessWidget {
  const _WideMiniPlayer({
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
    // Blank chrome opens now-playing; transport / action buttons keep their
    // own handlers and win the gesture arena.
    return GestureDetector(
      key: const ValueKey('mini-player-open-now-playing'),
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _MiniArtwork(album: album, dimension: 58),
            const SizedBox(width: 13),
            Expanded(
              flex: 34,
              child: _TrackIdentity(
                track: track,
                visual: visual,
                prominent: true,
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              flex: 42,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TransportControls(playback: playback, visual: visual),
                    _MiniProgressRow(
                      playback: playback,
                      position: position,
                      duration: duration,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Container(width: 1, height: 38, color: context.soundDivider),
            const SizedBox(width: 9),
            SizedBox(
              width: 158,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (userState case final state?)
                    _MiniIconButton(
                      icon: state.isFavorite(track.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: state.isFavorite(track.id)
                          ? SoundColors.accent
                          : null,
                      tooltip: state.isFavorite(track.id) ? '取消收藏' : '收藏歌曲',
                      onTap: () => unawaited(state.toggleFavorite(track)),
                    ),
                  _VolumeControl(playback: playback),
                  _MiniIconButton(
                    icon: Icons.lyrics_outlined,
                    tooltip: '打开歌词',
                    onTap: onOpen,
                  ),
                  _MiniIconButton(
                    icon: Icons.queue_music_rounded,
                    tooltip: '打开播放队列',
                    onTap: onOpenQueue ?? onOpen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final identityWidth = (constraints.maxWidth * 0.22)
            .clamp(170.0, 320.0)
            .toDouble();
        return Stack(
          clipBehavior: Clip.hardEdge,
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
                      SizedBox(
                        width: identityWidth,
                        child: _TrackIdentity(
                          track: track,
                          visual: visual,
                          prominent: false,
                        ),
                      ),
                      if (userState case final state?) ...[
                        const SizedBox(width: 5),
                        _MiniIconButton(
                          icon: state.isFavorite(track.id)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: state.isFavorite(track.id)
                              ? SoundColors.accent
                              : null,
                          tooltip: state.isFavorite(track.id) ? '取消收藏' : '收藏歌曲',
                          onTap: () => unawaited(state.toggleFavorite(track)),
                        ),
                      ],
                      const Spacer(),
                      _VolumeControl(playback: playback),
                      _MiniIconButton(
                        icon: Icons.lyrics_outlined,
                        tooltip: '打开歌词',
                        onTap: onOpen,
                      ),
                      _MiniIconButton(
                        icon: Icons.queue_music_rounded,
                        tooltip: '打开播放队列',
                        onTap: onOpenQueue ?? onOpen,
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
                  accentPrimary: true,
                ),
              ),
            ),
            // Top progress is active-only and flush to the bar edge.
            // Container height must match trackHeight: a taller box + center
            // alignment leaves a white hairline above the accent fill.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 3,
              child: ProgressScrubber(
                key: const ValueKey('mini-player-progress'),
                position: position,
                duration: duration,
                onSeek: playback.seek,
                activeColor: SoundColors.accent,
                inactiveColor: Colors.transparent,
                trackHeight: 3,
                padding: EdgeInsets.zero,
                interactive: false,
              ),
            ),
          ],
        );
      },
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
                  padding: EdgeInsets.all(
                    compact ? 6 : (availableWidth < 800 ? 8 : 14),
                  ),
                  child: Row(
                    children: [
                      _MiniArtwork(album: album, dimension: compact ? 44 : 50),
                      const SizedBox(width: 11),
                      Expanded(
                        child: _TrackIdentity(
                          track: track,
                          visual: visual,
                          prominent: false,
                        ),
                      ),
                      if (showPrevious)
                        _MiniIconButton(
                          icon: Icons.skip_previous_rounded,
                          tooltip: '上一首',
                          onTap: playback.previous,
                        ),
                      _MiniIconButton(
                        key: const ValueKey('mini-player-playback-toggle'),
                        icon: visual.primaryIcon,
                        tooltip: visual.primaryTooltip,
                        onTap: visual.primaryEnabled ? playback.toggle : null,
                        // Match now-playing: loading uses a spinner, not hourglass.
                        busy: visual.busy && !visual.primaryEnabled,
                        prominent: !embedded,
                        color: embedded ? SoundColors.accent : null,
                        size: compact ? (embedded ? 25 : 22) : 23,
                      ),
                      _MiniIconButton(
                        icon: Icons.skip_next_rounded,
                        tooltip: '下一首',
                        onTap: playback.next,
                        size: 23,
                      ),
                      if (showQueue)
                        _MiniIconButton(
                          icon: Icons.queue_music_rounded,
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
  });

  final Track track;
  final PlaybackVisualState visual;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final metaSize = prominent ? 12.0 : 11.0;
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
            style: TextStyle(
              color: context.soundPrimaryText,
              fontSize: prominent ? 15 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${track.artist} — ${track.albumTitle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.soundSecondaryText,
              fontSize: metaSize,
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
    this.accentPrimary = false,
  });

  final SoundPlaybackController playback;
  final PlaybackVisualState visual;
  final bool accentPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MiniIconButton(
            icon: Icons.skip_previous_rounded,
            tooltip: '上一首',
            onTap: playback.previous,
            size: 23,
          ),
          const SizedBox(width: 4),
          _MiniIconButton(
            key: const ValueKey('mini-player-playback-toggle'),
            icon: visual.primaryIcon,
            tooltip: visual.primaryTooltip,
            onTap: visual.primaryEnabled ? playback.toggle : null,
            busy: visual.busy && !visual.primaryEnabled,
            prominent: true,
            accentProminent: accentPrimary,
            size: 24,
          ),
          const SizedBox(width: 4),
          _MiniIconButton(
            icon: Icons.skip_next_rounded,
            tooltip: '下一首',
            onTap: playback.next,
            size: 23,
          ),
        ],
      ),
    );
  }
}

class _MiniProgressRow extends StatelessWidget {
  const _MiniProgressRow({
    required this.playback,
    required this.position,
    required this.duration,
  });

  final SoundPlaybackController playback;
  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final remaining = duration - position;
    final remainingLabel = duration > Duration.zero
        ? '-${formatDuration(remaining.isNegative ? Duration.zero : remaining)}'
        : '0:00';
    return SizedBox(
      height: 4,
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Align(
              alignment: Alignment.center,
              child: Text(formatDuration(position), style: _timeStyle(context)),
            ),
          ),
          Expanded(
            child: ProgressScrubber(
              key: const ValueKey('mini-player-progress'),
              position: position,
              duration: duration,
              onSeek: playback.seek,
              activeColor: context.soundPrimaryText,
              inactiveColor: context.soundTint(0.12),
              trackHeight: 3,
              padding: EdgeInsets.zero,
              interactive: false,
            ),
          ),
          SizedBox(
            width: 42,
            child: Align(
              alignment: Alignment.center,
              child: Text(
                remainingLabel,
                textAlign: TextAlign.end,
                style: _timeStyle(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    this.accentProminent = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final Color? color;
  final bool busy;
  final bool prominent;
  final bool accentProminent;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = prominent
        ? context.soundGlass.canvasHighlight.withValues(
            alpha: enabled || busy ? 1 : 0.45,
          )
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
          : Icon(icon, color: foreground, size: size),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: prominent
          ? IconButton.styleFrom(
              backgroundColor: onTap == null && !busy
                  ? context.soundTint(0.16)
                  : accentProminent
                  ? SoundColors.accent
                  : context.soundPrimaryText,
              hoverColor: accentProminent
                  ? SoundColors.accentHover
                  : context.soundTint(0.08),
              highlightColor: accentProminent
                  ? SoundColors.accentPressed
                  : context.soundTint(0.12),
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

TextStyle _timeStyle(BuildContext context) => TextStyle(
  color: context.soundMutedText,
  fontSize: 10,
  fontFeatures: const [FontFeature.tabularFigures()],
);

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
    if (v == 0) return Icons.volume_off_rounded;
    if (v < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
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
