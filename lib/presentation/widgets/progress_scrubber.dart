import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';

/// Bubbles for the full lifetime of a pointer interacting with the scrubber.
///
/// Dispatched on pointer-down (before the gesture arena settles) so ancestors
/// can suppress dismiss / scroll while the bar is scrubbed.
class ProgressScrubInteractionNotification extends Notification {
  const ProgressScrubInteractionNotification({
    required this.active,
    this.pointer,
  });

  final bool active;
  final int? pointer;
}

/// Thin progress track with a large, exclusive pointer hit target.
///
/// Uses a global pointer route after down so drags keep updating even when the
/// finger leaves the 44px band (vertical noise must not steal the scrub).
class ProgressScrubber extends StatefulWidget {
  const ProgressScrubber({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.onPreviewChanged,
    this.activeColor,
    this.inactiveColor,
    this.trackHeight = 3,
    this.thumbRadius = 6,
    this.overlayRadius = 20,
    this.padding,
    this.minInteractiveHeight = 44,
    this.trackVerticalOffset = 0,
    this.interactive = true,
    this.hoverReveal = false,
    this.hoverTrackHeight,
    this.timeBubbleBuilder,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final FutureOr<void> Function(Duration position) onSeek;

  /// Live scrub position for sibling chrome (time labels). `null` when not
  /// scrubbing / preview has been released to the engine.
  final ValueChanged<Duration?>? onPreviewChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final double trackHeight;
  final double thumbRadius;
  final double overlayRadius;
  final EdgeInsetsGeometry? padding;
  final double minInteractiveHeight;
  final double trackVerticalOffset;
  final bool interactive;

  /// Mini-player style: a thin track by default that grows and reveals a
  /// thumb (plus an optional time bubble) while the pointer hovers or drags.
  final bool hoverReveal;

  /// Track height while hovered/dragging in [hoverReveal] mode.
  final double? hoverTrackHeight;

  /// Renders a time label above the thumb while hovering/dragging. The
  /// returned widget is horizontally centered on the thumb and clamped to the
  /// scrubber width; it may overflow above the widget bounds (use a
  /// non-clipping ancestor if that is intended).
  final Widget Function(BuildContext context, Duration time)? timeBubbleBuilder;

  @override
  State<ProgressScrubber> createState() => _ProgressScrubberState();
}

class _ProgressScrubberState extends State<ProgressScrubber> {
  double? _previewMilliseconds;
  // The committed seek target remains the visual playback position until the
  // source position catches up. Unlike [_previewMilliseconds], this does not
  // keep the drag affordance visible.
  double? _committedMilliseconds;
  bool _dragging = false;
  bool _interactionNotified = false;
  bool _globalRouteInstalled = false;
  int? _activePointer;
  bool _hovered = false;
  double? _hoverFraction;

  final GlobalKey _hitKey = GlobalKey(debugLabel: 'progress-scrubber-hit');

  double get _durationMs =>
      widget.duration.inMilliseconds.toDouble().clamp(1, double.infinity);

  double get _displayMs {
    final engine = widget.position.inMilliseconds.toDouble();
    return (_previewMilliseconds ?? _committedMilliseconds ?? engine).clamp(
      0,
      _durationMs,
    );
  }

  double get _fraction => widget.duration > Duration.zero
      ? (_displayMs / _durationMs).clamp(0.0, 1.0)
      : 0.0;

  /// Thumb position: the drag preview when active, otherwise the hover
  /// position, otherwise the playback fraction.
  double get _thumbFraction {
    if (_dragging || _previewMilliseconds != null) return _fraction;
    return _hoverFraction ?? _fraction;
  }

  void _notifyInteraction(bool active, {int? pointer}) {
    if (!active && !_interactionNotified) return;
    _interactionNotified = active;
    if (!mounted) return;
    ProgressScrubInteractionNotification(
      active: active,
      pointer: active ? (pointer ?? _activePointer) : null,
    ).dispatch(context);
  }

  void _ensureGlobalRoute() {
    if (_globalRouteInstalled) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointer);
    _globalRouteInstalled = true;
  }

  void _removeGlobalRoute() {
    if (!_globalRouteInstalled) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _handleGlobalPointer,
    );
    _globalRouteInstalled = false;
  }

  void _handleGlobalPointer(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    if (event is PointerMoveEvent) {
      final dx = _localDxFromGlobal(event.position);
      if (dx != null) _setFractionFromLocalDx(dx);
      return;
    }
    if (event is PointerUpEvent) {
      _endDrag(event.pointer, commit: true);
      return;
    }
    if (event is PointerCancelEvent) {
      _endDrag(event.pointer, commit: false);
    }
  }

  double? _localDxFromGlobal(Offset global) {
    final box = _hitKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(global).dx;
  }

  void _emitPreview(double? ms) {
    final callback = widget.onPreviewChanged;
    if (callback == null) return;
    callback(ms == null ? null : Duration(milliseconds: ms.round()));
  }

  double? _fractionFromDx(double dx) {
    if (widget.duration <= Duration.zero) return null;
    final box = _hitKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 0;
    if (width <= 0) return null;
    return (dx / width).clamp(0.0, 1.0);
  }

  void _setFractionFromLocalDx(double dx) {
    final fraction = _fractionFromDx(dx);
    if (fraction == null) return;
    final ms = fraction * _durationMs;
    if (_previewMilliseconds != null &&
        (ms - _previewMilliseconds!).abs() < 0.5) {
      return;
    }
    setState(() => _previewMilliseconds = ms);
    _emitPreview(ms);
  }

  Future<void> _commitSeek(double valueMs) async {
    final target = Duration(milliseconds: valueMs.round());
    await widget.onSeek(target);
  }

  bool _engineHasSettled(double targetMs) {
    final engineMs = widget.position.inMilliseconds.toDouble();
    return (engineMs - targetMs).abs() <= 800.0;
  }

  void _beginDrag(int pointer, Offset globalPosition) {
    _activePointer = pointer;
    _dragging = true;
    _ensureGlobalRoute();
    // Notify first so ancestor cover-dismiss handlers see the flag on the
    // same pointer-down (child listeners run before parents).
    _notifyInteraction(true, pointer: pointer);
    final dx = _localDxFromGlobal(globalPosition);
    if (dx != null) _setFractionFromLocalDx(dx);
  }

  void _endDrag(int pointer, {required bool commit}) {
    if (_activePointer != null && _activePointer != pointer) return;
    final preview = _previewMilliseconds;
    _activePointer = null;
    _dragging = false;
    _removeGlobalRoute();
    _notifyInteraction(false);
    // Preview is only a drag affordance. Once the pointer is released, turn it
    // into a committed playback position and hide the drag chrome. The
    // playback controller normally publishes the same pending seek; the local
    // committed value bridges the async gap and prevents a snap-back if its
    // source position is temporarily stale.
    final shouldCommit =
        commit && preview != null && widget.duration > Duration.zero;
    if (mounted) {
      setState(() {
        _previewMilliseconds = null;
        if (shouldCommit) _committedMilliseconds = preview;
      });
    } else {
      _previewMilliseconds = null;
      if (shouldCommit) _committedMilliseconds = preview;
    }
    _emitPreview(null);
    if (shouldCommit) {
      unawaited(_commitSeek(preview));
    }
  }

  @override
  void didUpdateWidget(covariant ProgressScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    final committed = _committedMilliseconds;
    if (committed == null || _dragging) return;
    if (widget.duration <= Duration.zero || _engineHasSettled(committed)) {
      // The engine has taken ownership of the final position. The visual
      // value remains unchanged; only the fallback source is released.
      _committedMilliseconds = null;
    }
  }

  @override
  void dispose() {
    _removeGlobalRoute();
    if (_dragging || _interactionNotified) {
      _dragging = false;
      _activePointer = null;
      _interactionNotified = false;
    }
    // Drop parent label preview. Parent handlers must no-op when !mounted.
    _emitPreview(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? context.soundPrimaryText;
    final inactiveColor = widget.inactiveColor ?? context.soundTint(0.14);
    final enabled = widget.interactive && widget.duration > Duration.zero;
    final fraction = _fraction;

    if (!widget.interactive) {
      return _NonInteractiveProgressTrack(
        fraction: fraction,
        trackHeight: widget.trackHeight,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        padding: widget.padding ?? EdgeInsets.zero,
      );
    }

    if (widget.hoverReveal) {
      return _buildHoverReveal(
        context,
        enabled: enabled,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
      );
    }

    final height = math.max(widget.minInteractiveHeight, 44.0);
    final thumbR = widget.thumbRadius;

    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: GestureDetector(
        // Claim taps inside the scrubber so an ancestor (for example the
        // dock's whole-bar onTap) cannot also open the now-playing screen.
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: enabled
              ? (event) => _beginDrag(event.pointer, event.position)
              : null,
          // Move/up handled by the global route so vertical drift off the
          // 44px band does not kill the scrub.
          child: SizedBox(
            key: _hitKey,
            height: height,
            width: double.infinity,
            child: CustomPaint(
              key: const ValueKey('progress-scrubber-hit-target'),
              painter: _ScrubberPainter(
                fraction: fraction,
                trackHeight: widget.trackHeight,
                thumbRadius: thumbR,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                showThumb: enabled,
                verticalOffset: widget.trackVerticalOffset,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoverReveal(
    BuildContext context, {
    required bool enabled,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final fraction = _fraction;
    final reveal = _hovered || _dragging || _previewMilliseconds != null;
    final trackHeight = reveal
        ? (widget.hoverTrackHeight ?? widget.trackHeight + 3)
        : widget.trackHeight;
    final showThumb = enabled && reveal;
    final height = math.max(widget.minInteractiveHeight, 16.0);
    final thumbFraction = _thumbFraction;
    final bubbleBuilder = widget.timeBubbleBuilder;
    final bubbleTime = Duration(
      milliseconds: (thumbFraction * _durationMs).round(),
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled
          ? (_) => setState(() {
              _hovered = false;
              _hoverFraction = null;
            })
          : null,
      onHover: enabled
          ? (event) {
              final dx = _localDxFromGlobal(event.position);
              if (dx == null) return;
              setState(() => _hoverFraction = _fractionFromDx(dx));
            }
          : null,
      child: Padding(
        padding: widget.padding ?? EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final thumbX = (thumbFraction * width).clamp(
              widget.thumbRadius,
              math.max(widget.thumbRadius, width - widget.thumbRadius),
            );
            final alignX = width > 0
                ? ((thumbX / (width / 2)) - 1).clamp(-1.0, 1.0)
                : 0.0;
            return SizedBox(
              key: _hitKey,
              height: height,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      // Prevent the dock's parent tap recognizer from
                      // interpreting a scrubber click as "open now playing".
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: enabled
                            ? (event) =>
                                  _beginDrag(event.pointer, event.position)
                            : null,
                        // Move/up handled by the global route so vertical
                        // drift off the thin band does not kill the scrub.
                        child: CustomPaint(
                          key: const ValueKey('progress-scrubber-hit-target'),
                          painter: _ScrubberPainter(
                            fraction: fraction,
                            thumbFraction: thumbFraction,
                            trackHeight: trackHeight,
                            thumbRadius: widget.thumbRadius,
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            showThumb: showThumb,
                            // Hovered/dragging track sits a touch lower so the
                            // thicker track and thumb stay inside the bar.
                            verticalOffset:
                                widget.trackVerticalOffset + (reveal ? 3 : 0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showThumb && bubbleBuilder != null)
                    Positioned.fill(
                      // Display-only: the bubble must never steal pointer
                      // events from the track underneath.
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment(alignX, -1),
                          child: bubbleBuilder(context, bubbleTime),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  _ScrubberPainter({
    required this.fraction,
    this.thumbFraction,
    required this.trackHeight,
    required this.thumbRadius,
    required this.activeColor,
    required this.inactiveColor,
    required this.showThumb,
    required this.verticalOffset,
  });

  final double fraction;
  final double? thumbFraction;
  final double trackHeight;
  final double thumbRadius;
  final Color activeColor;
  final Color inactiveColor;
  final bool showThumb;
  final double verticalOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final maxOffset = math.max(
      0.0,
      // The thumb keeps the track away from the widget edge when visible; a
      // hidden thumb (thin mini-player track) may sit flush at the top.
      size.height / 2 -
          (showThumb
              ? math.max(thumbRadius, trackHeight / 2)
              : trackHeight / 2),
    );
    final cy = size.height / 2 + verticalOffset.clamp(-maxOffset, maxOffset);
    final trackTop = cy - trackHeight / 2;
    final trackRect = Rect.fromLTWH(0, trackTop, size.width, trackHeight);
    canvas.drawRect(trackRect, Paint()..color = inactiveColor);

    final activeWidth = (size.width * fraction).clamp(0.0, size.width);
    if (activeWidth > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, trackTop, activeWidth, trackHeight),
        Paint()..color = activeColor,
      );
    }

    if (!showThumb) return;
    final thumbX = ((thumbFraction ?? fraction) * size.width).clamp(
      thumbRadius,
      size.width - thumbRadius,
    );
    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbRadius,
      Paint()..color = activeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.thumbFraction != thumbFraction ||
        oldDelegate.trackHeight != trackHeight ||
        oldDelegate.thumbRadius != thumbRadius ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.showThumb != showThumb ||
        oldDelegate.verticalOffset != verticalOffset;
  }
}

class _NonInteractiveProgressTrack extends StatelessWidget {
  const _NonInteractiveProgressTrack({
    required this.fraction,
    required this.trackHeight,
    required this.activeColor,
    required this.inactiveColor,
    required this.padding,
  });

  final double fraction;
  final double trackHeight;
  final Color activeColor;
  final Color inactiveColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final activeWidth = constraints.maxWidth * fraction;
          final height =
              constraints.maxHeight.isFinite &&
                  constraints.maxHeight > 0 &&
                  constraints.maxHeight <= trackHeight + 0.5
              ? constraints.maxHeight
              : trackHeight;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  if (activeWidth > 0)
                    SizedBox(
                      width: activeWidth,
                      child: Container(color: activeColor),
                    ),
                  if (activeWidth < constraints.maxWidth)
                    Expanded(child: Container(color: inactiveColor)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
