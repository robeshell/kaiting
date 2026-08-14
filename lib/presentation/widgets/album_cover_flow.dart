import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import 'album_art.dart';

/// Cover Flow angles. iCarousel uses tilt 0.9 (≈81°) in Core Animation,
/// where the Y-rotation sign is the opposite of Flutter's `Matrix4.rotateY`.
/// 0.72 ≈ 65° matches the iPod screenshot: side covers face the center.
const double kCoverFlowTilt = 0.72;
const double kCoverFlowSpacing = 0.22;
const double kCoverFlowMaxAngle = math.pi / 2 * kCoverFlowTilt;
const double kCoverFlowGutter = 20;

const double kCoverFlowBottomBarHeight = 52;
const double kCoverFlowCaptionHeight = 56;

/// Visible albums on each side of the focused cover.
const int kCoverFlowSideCount = 7;

/// Fraction of the cover height used for the floor reflection.
const double kCoverFlowReflectionRatio = 0.40;

/// Geometry for one album at a signed offset from the focused page.
@immutable
class CoverFlowPlacement {
  const CoverFlowPlacement({
    required this.translateX,
    required this.rotateY,
    required this.translateZ,
    required this.opacity,
    this.scale = 1,
  });

  final double translateX;
  final double rotateY;
  final double translateZ;
  final double opacity;
  final double scale;
}

/// Port of nicklockwood/iCarousel CoverFlow, with Z flipped for Flutter.
///
/// iCarousel uses negative Z for "into the screen". Flutter's
/// `setEntry(3, 2, +p)` treats negative Z as toward the camera, which
/// stretched side covers into the window edges. Positive Z sends them back.
///
/// [offset] is `index - page` (negative = left).
CoverFlowPlacement coverFlowPlacement({
  required double offset,
  required double coverSize,
  bool reduceMotion = false,
  double toggle = 0,
}) {
  if (reduceMotion) {
    return CoverFlowPlacement(
      translateX: offset * coverSize * (kCoverFlowSpacing + 0.55),
      rotateY: 0,
      translateZ: 0,
      opacity: (1.0 - offset.abs() * 0.16).clamp(0.32, 1.0),
      scale: (1.0 - offset.abs() * 0.04).clamp(0.82, 1.0),
    );
  }

  // CoverFlow2: while dragging, the front cover leans immediately in the
  // drag direction instead of staying face-on until the page crosses 0.5.
  var clamped = offset.clamp(-1.0, 1.0);
  if (toggle.abs() > 0.001) {
    if (toggle > 0) {
      if (offset <= -0.5) {
        clamped = -1;
      } else if (offset <= 0.5) {
        clamped = -toggle;
      } else if (offset <= 1.5) {
        clamped = 1 - toggle;
      }
    } else {
      if (offset > 0.5) {
        clamped = 1;
      } else if (offset > -0.5) {
        clamped = -toggle;
      } else if (offset > -1.5) {
        clamped = -1 - toggle;
      }
    }
    clamped = clamped.clamp(-1.0, 1.0);
  }
  final x =
      (clamped * 0.5 * kCoverFlowTilt + offset * kCoverFlowSpacing) * coverSize;
  // Away from the camera under Flutter's +m34 perspective.
  final z = clamped.abs() * coverSize * 0.28;
  // Flutter rotateY(+θ) brings the left edge forward. Right-hand albums
  // (offset > 0) therefore need +θ so their inner edge faces the center.
  // iCarousel's minus sign is for Core Animation, not Flutter.
  final angle = clamped * kCoverFlowMaxAngle;
  return CoverFlowPlacement(
    translateX: x,
    rotateY: angle,
    translateZ: z,
    opacity: (1.0 - (offset.abs() - 1).clamp(0.0, 8.0) * 0.05).clamp(0.55, 1.0),
    scale: (1.0 - clamped.abs() * 0.04).clamp(0.9, 1.0),
  );
}

/// Nearest visible cover to a stage-local X, so tapping a side album
/// selects that album instead of only stepping by one.
int coverFlowIndexAtX({
  required double localX,
  required double stageWidth,
  required double page,
  required int albumCount,
  required double coverSize,
  bool reduceMotion = false,
}) {
  if (albumCount <= 0) return 0;
  final origin = stageWidth / 2;
  final focused = page.round().clamp(0, albumCount - 1);
  final focusedX =
      origin +
      coverFlowPlacement(
        offset: focused - page,
        coverSize: coverSize,
        reduceMotion: reduceMotion,
      ).translateX;
  if ((localX - focusedX).abs() <= coverSize / 2) return focused;

  var bestIndex = focused;
  var bestDist = (localX - focusedX).abs();
  final start = math.max(0, focused - kCoverFlowSideCount);
  final end = math.min(albumCount - 1, focused + kCoverFlowSideCount);
  for (var i = start; i <= end; i++) {
    if (i == focused) continue;
    final x =
        origin +
        coverFlowPlacement(
          offset: i - page,
          coverSize: coverSize,
          reduceMotion: reduceMotion,
        ).translateX;
    final dist = (localX - x).abs();
    if (dist < bestDist) {
      bestDist = dist;
      bestIndex = i;
    }
  }
  return bestIndex;
}

/// Insets for chrome **and** the cover stage.
///
/// Covers are clipped to this rect so they cannot paint under the macOS
/// title bar / traffic lights, the iPhone notch, or the home indicator.
EdgeInsets coverFlowSafeInsets(BuildContext context) {
  final media = MediaQuery.of(context);
  // Prefer viewPadding: a fullscreen route can zero [padding] after the
  // parent consumes it, but the notch / home indicator still live here.
  final view = media.viewPadding;
  final padding = media.padding;
  final left = math.max(padding.left, view.left);
  final right = math.max(padding.right, view.right);
  final top = math.max(
    math.max(padding.top, view.top),
    context.soundTitlebarInset,
  );
  final bottom = math.max(padding.bottom, view.bottom);
  final compact = context.soundUsesMobileShell;
  final gutter = compact ? 12.0 : kCoverFlowGutter;
  return EdgeInsets.fromLTRB(
    left + gutter,
    top + (compact ? 4 : 8),
    right + gutter,
    math.max(bottom, compact ? 12.0 : 16.0),
  );
}

/// Cover edge that still fits the stage after reflection.
double coverFlowCoverSize({
  required Size stageSize,
  required bool landscape,
  bool compact = false,
}) {
  if (stageSize.width <= 0 || stageSize.height <= 0) return 160;
  final fromHeight = stageSize.height / (1 + kCoverFlowReflectionRatio + 0.08);
  final widthFactor = landscape ? 0.38 : (compact ? 0.56 : 0.46);
  final fromWidth = stageSize.width * widthFactor;
  return fromHeight.clamp(148.0, 300.0).clamp(148.0, fromWidth);
}

/// iPhone Taptic Engine / Android vibrator. Selection ticks follow the
/// click-wheel: one pulse each time the focused album changes.
Future<void> coverFlowSelectionTick() => HapticFeedback.selectionClick();

Future<void> coverFlowPlayTick() => HapticFeedback.mediumImpact();

Future<void> coverFlowOpenTick() => HapticFeedback.lightImpact();

/// Full-screen iPod Cover Flow: black stage, turned covers, floor reflections.
Future<void> showAlbumCoverFlow(
  BuildContext context, {
  required List<Album> albums,
  int initialIndex = 0,
  required ValueChanged<Album> onPlayAlbum,
  ValueChanged<Album>? onOpenAlbum,
}) {
  if (albums.isEmpty) return Future<void>.value();
  final safeIndex = initialIndex.clamp(0, albums.length - 1);
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      // Avoid the iOS edge-swipe back gesture stealing horizontal Cover Flow
      // drags on the left side of the screen.
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlbumCoverFlowPage(
          albums: albums,
          initialIndex: safeIndex,
          onPlayAlbum: onPlayAlbum,
          onOpenAlbum: onOpenAlbum,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class AlbumCoverFlowPage extends StatefulWidget {
  const AlbumCoverFlowPage({
    required this.albums,
    required this.onPlayAlbum,
    this.initialIndex = 0,
    this.onOpenAlbum,
    super.key,
  });

  final List<Album> albums;
  final int initialIndex;
  final ValueChanged<Album> onPlayAlbum;
  final ValueChanged<Album>? onOpenAlbum;

  @override
  State<AlbumCoverFlowPage> createState() => _AlbumCoverFlowPageState();
}

class _AlbumCoverFlowPageState extends State<AlbumCoverFlowPage>
    with SingleTickerProviderStateMixin {
  late double _page;
  late final AnimationController _snap;
  int _announcedIndex = -1;
  double _dismiss = 0;
  double _toggle = 0;
  double _dragUnit = 140;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.toDouble().clamp(
      0,
      math.max(0, widget.albums.length - 1).toDouble(),
    );
    _announcedIndex = _focusedIndex;
    _snap = AnimationController.unbounded(vsync: this)
      ..addListener(_handleSnapTick);
  }

  @override
  void didUpdateWidget(covariant AlbumCoverFlowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.albums.isEmpty) return;
    final max = (widget.albums.length - 1).toDouble();
    if (_page > max) {
      _page = max;
    }
  }

  @override
  void dispose() {
    _snap
      ..removeListener(_handleSnapTick)
      ..dispose();
    super.dispose();
  }

  int get _focusedIndex {
    if (widget.albums.isEmpty) return 0;
    return _page.round().clamp(0, widget.albums.length - 1);
  }

  Album get _focusedAlbum => widget.albums[_focusedIndex];

  double get _maxPage => math.max(0, widget.albums.length - 1).toDouble();

  void _handleSnapTick() {
    setState(() => _page = _snap.value);
    _announceIfSettled();
  }

  void _announceIfSettled() {
    final next = _focusedIndex;
    if (next == _announcedIndex) return;
    _announcedIndex = next;
    unawaited(coverFlowSelectionTick());
  }

  void _stopSnap() {
    _snap.stop();
  }

  void _setPage(double value, {bool rubber = false}) {
    var next = value;
    if (rubber) {
      if (next < 0) {
        next *= 0.32;
      } else if (next > _maxPage) {
        next = _maxPage + (next - _maxPage) * 0.32;
      }
    } else {
      next = next.clamp(0.0, _maxPage);
    }
    if (next == _page) return;
    setState(() => _page = next);
    _announceIfSettled();
  }

  void _animateTo(double target, {double velocity = 0}) {
    final clamped = target.clamp(0.0, _maxPage);
    _stopSnap();
    if ((clamped - _page).abs() < 0.001) {
      _setPage(clamped);
      return;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _setPage(clamped);
      return;
    }
    final simulation = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 210, damping: 22),
      _page,
      clamped,
      velocity,
    );
    unawaited(_snap.animateWith(simulation));
  }

  void _nudge(double direction) {
    if (direction == 0) return;
    _animateTo(_focusedIndex + direction.sign);
  }

  void _close() {
    Navigator.of(context).maybePop();
  }

  void _playFocused() {
    final album = _focusedAlbum;
    if (album.tracks.isEmpty) return;
    unawaited(coverFlowPlayTick());
    widget.onPlayAlbum(album);
    // Full-screen Cover Flow hides the mini player; leave so playback is
    // visible, the same way the iPod left Cover Flow for Now Playing.
    if (mounted) Navigator.of(context).maybePop();
  }

  void _openFocused() {
    final open = widget.onOpenAlbum;
    if (open == null) return;
    unawaited(coverFlowOpenTick());
    final album = _focusedAlbum;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      open(album);
    });
  }

  void _handleStageTap(Offset local, Size stageSize, double coverSize) {
    final index = coverFlowIndexAtX(
      localX: local.dx,
      stageWidth: stageSize.width,
      page: _page,
      albumCount: widget.albums.length,
      coverSize: coverSize,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
    if (index == _focusedIndex) {
      _playFocused();
      return;
    }
    unawaited(coverFlowSelectionTick());
    _animateTo(index.toDouble());
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _stopSnap();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _setPage(_page - details.delta.dx / _dragUnit, rubber: true);
    final nextToggle = (_page - _page.roundToDouble()).clamp(-1.0, 1.0);
    if (nextToggle != _toggle) {
      setState(() => _toggle = nextToggle);
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = -details.velocity.pixelsPerSecond.dx / _dragUnit;
    var target = _page.roundToDouble();
    if (velocity.abs() > 0.85) {
      target = velocity < 0 ? _page.floorToDouble() : _page.ceilToDouble();
      target += (velocity.abs() / 6).floor() * velocity.sign;
    }
    setState(() => _toggle = 0);
    _animateTo(target, velocity: velocity);
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _stopSnap();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final next = (_dismiss + details.delta.dy).clamp(0.0, 280.0);
    if (next == _dismiss) return;
    setState(() => _dismiss = next);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final vy = details.velocity.pixelsPerSecond.dy;
    if (_dismiss > 96 || vy > 780) {
      _close();
      return;
    }
    setState(() => _dismiss = 0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _nudge(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _nudge(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _playFocused();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    final size = media.size;
    final insets = coverFlowSafeInsets(context);
    final stageHeight = math.max(
      160.0,
      size.height -
          insets.top -
          insets.bottom -
          kCoverFlowCaptionHeight -
          kCoverFlowBottomBarHeight,
    );
    final coverSize = coverFlowCoverSize(
      stageSize: Size(
        math.max(0, size.width - insets.left - insets.right),
        stageHeight,
      ),
      landscape: size.aspectRatio > 1.15,
      compact: context.soundUsesMobileShell,
    );
    _dragUnit = math.max(
      48.0,
      coverFlowPlacement(offset: 1, coverSize: coverSize).translateX.abs(),
    );
    final dismissProgress = (_dismiss / 220).clamp(0.0, 1.0);
    final album = widget.albums.isEmpty ? null : _focusedAlbum;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            final delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
                ? event.scrollDelta.dx
                : event.scrollDelta.dy;
            if (delta.abs() < 4) return;
            _nudge(delta.sign);
          },
          child: Material(
            key: const ValueKey('album-cover-flow'),
            color: const Color(0xFF050505),
            child: Opacity(
              opacity: 1 - dismissProgress * 0.35,
              child: Transform.translate(
                offset: Offset(0, _dismiss * 0.72),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF141414), Color(0xFF000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      key: const ValueKey('album-cover-flow-stage'),
                      top: insets.top,
                      left: insets.left,
                      right: insets.right,
                      bottom: insets.bottom +
                          kCoverFlowCaptionHeight +
                          kCoverFlowBottomBarHeight,
                      child: ClipRect(
                        child: MediaQuery(
                          data: media.copyWith(
                            gestureSettings: const DeviceGestureSettings(
                              touchSlop: 2,
                            ),
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) => _handleStageTap(
                              details.localPosition,
                              Size(
                                math.max(
                                  0,
                                  size.width - insets.left - insets.right,
                                ),
                                stageHeight,
                              ),
                              coverSize,
                            ),
                            onLongPress: widget.onOpenAlbum == null
                                ? null
                                : _openFocused,
                            onHorizontalDragStart: _onHorizontalDragStart,
                            onHorizontalDragUpdate: _onHorizontalDragUpdate,
                            onHorizontalDragEnd: _onHorizontalDragEnd,
                            onVerticalDragStart: _onVerticalDragStart,
                            onVerticalDragUpdate: _onVerticalDragUpdate,
                            onVerticalDragEnd: _onVerticalDragEnd,
                            child: _CoverFlowStage(
                              albums: widget.albums,
                              page: _page,
                              coverSize: coverSize,
                              reduceMotion: reduceMotion,
                              playingPulse: false,
                              toggle: _toggle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: insets.top,
                      left: insets.left,
                      child: IconButton(
                        key: const ValueKey('album-cover-flow-close'),
                        tooltip: '关闭',
                        onPressed: _close,
                        color: const Color(0xFFE8E8E8),
                        icon: const Icon(KaitingIcons.close, size: 20),
                      ),
                    ),
                    Positioned(
                      left: insets.left,
                      right: insets.right,
                      bottom: insets.bottom + kCoverFlowBottomBarHeight,
                      height: kCoverFlowCaptionHeight,
                      child: album == null
                          ? const SizedBox.shrink()
                          : _CoverFlowCaption(album: album),
                    ),
                    Positioned(
                      left: insets.left,
                      right: insets.right,
                      bottom: insets.bottom,
                      height: kCoverFlowBottomBarHeight,
                      child: _CoverFlowControls(
                        onPlay: album == null || album.tracks.isEmpty
                            ? null
                            : _playFocused,
                        onInfo: widget.onOpenAlbum == null
                            ? null
                            : _openFocused,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverFlowControls extends StatelessWidget {
  const _CoverFlowControls({this.onPlay, this.onInfo});

  final VoidCallback? onPlay;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('album-cover-flow-play'),
            tooltip: '播放',
            onPressed: onPlay,
            color: const Color(0xFFF2F2F2),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(KaitingIcons.play, size: 26),
          ),
          const Spacer(),
          if (onInfo != null)
            IconButton(
              key: const ValueKey('album-cover-flow-info'),
              tooltip: '专辑详情',
              onPressed: onInfo,
              color: const Color(0xFFF2F2F2),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(KaitingIcons.info, size: 22),
            ),
        ],
      ),
    );
  }
}

class _CoverFlowCaption extends StatelessWidget {
  const _CoverFlowCaption({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '${album.artist}，${album.title}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 4),
        child: Column(
          key: ValueKey('cover-flow-caption-${album.id}'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF4F4F4),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverFlowStage extends StatelessWidget {
  const _CoverFlowStage({
    required this.albums,
    required this.page,
    required this.coverSize,
    required this.reduceMotion,
    required this.playingPulse,
    this.toggle = 0,
  });

  final List<Album> albums;
  final double page;
  final double coverSize;
  final bool reduceMotion;
  final bool playingPulse;
  final double toggle;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const SizedBox.expand();
    final focused = page.round().clamp(0, albums.length - 1);
    final start = math.max(0, focused - kCoverFlowSideCount);
    final end = math.min(albums.length - 1, focused + kCoverFlowSideCount);
    final indices = [for (var i = start; i <= end; i++) i]
      ..sort((a, b) {
        final da = (a - page).abs();
        final db = (b - page).abs();
        return db.compareTo(da);
      });
    final reflectionHeight = coverSize * kCoverFlowReflectionRatio;
    final plateHeight = coverSize + reflectionHeight;
    final coverCenterY = (coverSize / plateHeight) * 2 - 1;
    final cacheExtent = quantizedArtworkCacheExtent(
      coverSize,
      MediaQuery.devicePixelRatioOf(context),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: SizedBox(
            height: plateHeight + 8,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                for (final index in indices)
                  _CoverFlowPlate(
                    key: ValueKey('cover-flow-plate-${albums[index].id}'),
                    album: albums[index],
                    placement: coverFlowPlacement(
                      offset: index - page,
                      coverSize: coverSize,
                      reduceMotion: reduceMotion,
                      toggle: toggle,
                    ),
                    coverSize: coverSize,
                    plateHeight: plateHeight,
                    coverCenterY: coverCenterY,
                    cacheExtent: cacheExtent,
                    focused: index == focused,
                    playingPulse: playingPulse && index == focused,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverFlowPlate extends StatelessWidget {
  const _CoverFlowPlate({
    required this.album,
    required this.placement,
    required this.coverSize,
    required this.plateHeight,
    required this.coverCenterY,
    required this.cacheExtent,
    required this.focused,
    required this.playingPulse,
    super.key,
  });

  final Album album;
  final CoverFlowPlacement placement;
  final double coverSize;
  final double plateHeight;
  final double coverCenterY;
  final int cacheExtent;
  final bool focused;
  final bool playingPulse;

  @override
  Widget build(BuildContext context) {
    // Same order as iCarousel: translate in X/Z, then rotate about the
    // cover center so the pushed-back Z cancels the near-edge blow-up.
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.00055)
      ..translateByDouble(placement.translateX, 0, placement.translateZ, 1)
      ..rotateY(placement.rotateY);
    final scale = (playingPulse ? 1.03 : 1.0) * placement.scale;
    return IgnorePointer(
      ignoring: !focused && placement.opacity < 0.5,
      child: Transform(
        alignment: Alignment(0, coverCenterY),
        transform: transform,
        child: Opacity(
          opacity: placement.opacity,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: coverSize,
              height: plateHeight,
              child: Column(
                children: [
                  _CoverFace(
                    album: album,
                    size: coverSize,
                    cacheExtent: cacheExtent,
                    focused: focused,
                  ),
                  SizedBox(
                    width: coverSize,
                    height: coverSize * kCoverFlowReflectionRatio,
                    child: _CoverReflection(
                      album: album,
                      size: coverSize,
                      cacheExtent: cacheExtent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverFace extends StatelessWidget {
  const _CoverFace({
    required this.album,
    required this.size,
    required this.cacheExtent,
    required this.focused,
  });

  final Album album;
  final double size;
  final int cacheExtent;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: focused ? '播放 ${album.title}' : '查看 ${album.title}',
      child: DecoratedBox(
        decoration: BoxDecoration(
            boxShadow: focused
                ? const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 12,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AlbumArt(
                  album: album,
                  size: size,
                  borderRadius: 4,
                  showShadow: false,
                  cacheExtent: cacheExtent,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0x1AFFFFFF)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _CoverReflection extends StatelessWidget {
  const _CoverReflection({
    required this.album,
    required this.size,
    required this.cacheExtent,
  });

  final Album album;
  final double size;
  final int cacheExtent;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x73FFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.78],
          ).createShader(rect);
        },
        child: ClipRect(
          child: OverflowBox(
            maxHeight: size,
            alignment: Alignment.topCenter,
            child: Transform.flip(
              flipY: true,
              child: AlbumArt(
                album: album,
                size: size,
                borderRadius: 4,
                showShadow: false,
                cacheExtent: cacheExtent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
