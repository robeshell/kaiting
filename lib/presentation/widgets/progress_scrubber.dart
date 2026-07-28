import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';

/// Bubbles for the full lifetime of a pointer interacting with the scrubber.
///
/// The notification starts on pointer-down, before Flutter resolves the
/// gesture arena, so ancestors can suppress competing dismiss gestures even
/// when the user's scrub has a noticeable vertical component.
class ProgressScrubInteractionNotification extends Notification {
  const ProgressScrubInteractionNotification({
    required this.active,
    this.pointer,
  });

  final bool active;

  /// Pointer that owns the scrub, when [active] is true.
  final int? pointer;
}

/// Thin progress track with a large, direct pointer hit target.
///
/// Uses [Listener] (not Material [Slider]) so horizontal drags are not stolen
/// by scroll/dismiss arenas and the full [minInteractiveHeight] is tappable.
class ProgressScrubber extends StatefulWidget {
  const ProgressScrubber({
    required this.position,
    required this.duration,
    required this.onSeek,
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
  final Color? activeColor;
  final Color? inactiveColor;
  final double trackHeight;
  final double thumbRadius;

  /// Kept for API compatibility with call sites; hit height uses
  /// [minInteractiveHeight] instead of Material overlay radius.
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
  int? _activePointer;
  double _trackWidth = 0;

  double get _durationMs =>
      widget.duration.inMilliseconds.toDouble().clamp(1, double.infinity);

  double get _displayMs {
    final engine = widget.position.inMilliseconds.toDouble();
    return (_previewMilliseconds ?? engine).clamp(0, _durationMs);
  }

  double get _fraction =>
      widget.duration > Duration.zero ? (_displayMs / _durationMs).clamp(0.0, 1.0) : 0.0;

  void _notifyInteraction(bool active, {int? pointer}) {
    final boundPointer = active ? (pointer ?? _activePointer) : null;
    if (_interactionNotified == active && !active) return;
    _interactionNotified = active;
    if (!mounted) return;
    ProgressScrubInteractionNotification(
      active: active,
      pointer: boundPointer,
    ).dispatch(context);
  }

  void _setFractionFromLocalDx(double dx) {
    if (_trackWidth <= 0 || widget.duration <= Duration.zero) return;
    final fraction = (dx / _trackWidth).clamp(0.0, 1.0);
    final ms = fraction * _durationMs;
    setState(() => _previewMilliseconds = ms);
  }

  Future<void> _commitSeek(double valueMs) async {
    final target = Duration(milliseconds: valueMs.round());
    if (mounted) {
      setState(() => _previewMilliseconds = valueMs);
    } else {
      _previewMilliseconds = valueMs;
    }
    try {
      await widget.onSeek(target);
    } finally {
      _settleTimer?.cancel();
      _settleTimer = Timer(_settleTimeout, () {
        if (mounted && _previewMilliseconds == valueMs && !_dragging) {
          setState(() => _previewMilliseconds = null);
        }
      });
    }
  }

  void _beginDrag(int pointer, double localDx) {
    _activePointer = pointer;
    _dragging = true;
    // Notify first so ancestor cover-dismiss handlers see the flag on the
    // same pointer-down (child listeners run before parents).
    _notifyInteraction(true, pointer: pointer);
    _setFractionFromLocalDx(localDx);
  }

  void _updateDrag(int pointer, double localDx) {
    if (!_dragging || _activePointer != pointer) return;
    _setFractionFromLocalDx(localDx);
  }

  void _endDrag(int pointer, {required bool commit}) {
    if (_activePointer != null && _activePointer != pointer) return;
    final preview = _previewMilliseconds;
    _activePointer = null;
    _dragging = false;
    _notifyInteraction(false);
    if (commit && preview != null && widget.duration > Duration.zero) {
      unawaited(_commitSeek(preview));
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
      setState(() => _previewMilliseconds = null);
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    if (_dragging || _interactionNotified) {
      _dragging = false;
      _activePointer = null;
      _interactionNotified = false;
    }
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          _trackWidth = constraints.maxWidth;
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: enabled
                ? (event) => _beginDrag(event.pointer, event.localPosition.dx)
                : null,
            onPointerMove: enabled
                ? (event) => _updateDrag(event.pointer, event.localPosition.dx)
                : null,
            onPointerUp: enabled
                ? (event) => _endDrag(event.pointer, commit: true)
                : null,
            onPointerCancel: enabled
                ? (event) => _endDrag(event.pointer, commit: false)
                : null,
            child: SizedBox(
              key: const ValueKey('progress-scrubber-hit-target'),
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _ScrubberPainter(
                  fraction: fraction,
                  trackHeight: widget.trackHeight,
                  thumbRadius: thumbR,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  showThumb: enabled,
                  thumbHighlighted: _dragging,
                ),
              ),
            ),
          );
        },
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
    required this.thumbHighlighted,
  });

  final double fraction;
  final double trackHeight;
  final double thumbRadius;
  final Color activeColor;
  final Color inactiveColor;
  final bool showThumb;
  final bool thumbHighlighted;

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
    // Keep thumb size stable while dragging — scale pops read as elasticity.
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
        oldDelegate.showThumb != showThumb ||
        oldDelegate.thumbHighlighted != thumbHighlighted;
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
