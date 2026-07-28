import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
    this.interactive = true,
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
  final bool interactive;

  @override
  State<ProgressScrubber> createState() => _ProgressScrubberState();
}

class _ProgressScrubberState extends State<ProgressScrubber> {
  static const _settleToleranceMs = 800.0;
  static const _settleTimeout = Duration(milliseconds: 1500);

  double? _previewMilliseconds;
  Timer? _settleTimer;
  bool _dragging = false;
  bool _interactionNotified = false;
  bool _globalRouteInstalled = false;
  int? _activePointer;

  final GlobalKey _hitKey = GlobalKey(debugLabel: 'progress-scrubber-hit');

  double get _durationMs =>
      widget.duration.inMilliseconds.toDouble().clamp(1, double.infinity);

  double get _displayMs {
    final engine = widget.position.inMilliseconds.toDouble();
    return (_previewMilliseconds ?? engine).clamp(0, _durationMs);
  }

  double get _fraction => widget.duration > Duration.zero
      ? (_displayMs / _durationMs).clamp(0.0, 1.0)
      : 0.0;

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

  void _setFractionFromLocalDx(double dx) {
    if (widget.duration <= Duration.zero) return;
    final box = _hitKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 0;
    if (width <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
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
    if (mounted) {
      setState(() => _previewMilliseconds = valueMs);
    } else {
      _previewMilliseconds = valueMs;
    }
    _emitPreview(valueMs);
    try {
      await widget.onSeek(target);
    } finally {
      _settleTimer?.cancel();
      _settleTimer = Timer(_settleTimeout, () {
        if (mounted && _previewMilliseconds == valueMs && !_dragging) {
          setState(() => _previewMilliseconds = null);
          _emitPreview(null);
        }
      });
    }
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
    if (commit && preview != null && widget.duration > Duration.zero) {
      unawaited(_commitSeek(preview));
    } else {
      // Cancelled drag — drop preview so labels fall back to engine.
      _emitPreview(null);
    }
  }

  @override
  void didUpdateWidget(covariant ProgressScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    final preview = _previewMilliseconds;
    if (preview == null || _dragging) return;
    final engineValue = widget.position.inMilliseconds.toDouble();
    if ((engineValue - preview).abs() <= _settleToleranceMs) {
      _settleTimer?.cancel();
      // Clear field only — build() follows didUpdateWidget. Do not setState
      // or synchronously notify the parent: ancestors (e.g. AnimatedBuilder)
      // may already be building when position catches the scrub target.
      _previewMilliseconds = null;
      _emitPreviewDeferred(null);
    }
  }

  /// Notify [onPreviewChanged] after the current frame when we may be inside
  /// a parent build (didUpdateWidget / dispose).
  void _emitPreviewDeferred(double? ms) {
    final callback = widget.onPreviewChanged;
    if (callback == null) return;
    final value = ms == null ? null : Duration(milliseconds: ms.round());
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      callback(value);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted && ms != null) return;
      callback(value);
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
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

    final height = math.max(widget.minInteractiveHeight, 44.0);
    final thumbR = widget.thumbRadius;

    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  _ScrubberPainter({
    required this.fraction,
    required this.trackHeight,
    required this.thumbRadius,
    required this.activeColor,
    required this.inactiveColor,
    required this.showThumb,
  });

  final double fraction;
  final double trackHeight;
  final double thumbRadius;
  final Color activeColor;
  final Color inactiveColor;
  final bool showThumb;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final trackTop = cy - trackHeight / 2;
    final radius = Radius.circular(trackHeight);
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackTop, size.width, trackHeight),
      radius,
    );
    canvas.drawRRect(trackRect, Paint()..color = inactiveColor);

    final activeWidth = (size.width * fraction).clamp(0.0, size.width);
    if (activeWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, trackTop, activeWidth, trackHeight),
          radius,
        ),
        Paint()..color = activeColor,
      );
    }

    if (!showThumb) return;
    final thumbX = activeWidth.clamp(thumbRadius, size.width - thumbRadius);
    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbRadius,
      Paint()..color = activeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.trackHeight != trackHeight ||
        oldDelegate.thumbRadius != thumbRadius ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.showThumb != showThumb;
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
