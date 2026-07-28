import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';

/// Bubbles for the full lifetime of a pointer interacting with the scrubber.
///
/// The notification starts on pointer-down, before Flutter resolves the
/// gesture arena, so ancestors can suppress competing dismiss gestures even
/// when the user's scrub has a noticeable vertical component.
class ProgressScrubInteractionNotification extends Notification {
  const ProgressScrubInteractionNotification({required this.active});

  final bool active;
}

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
    this.minInteractiveHeight = 40,
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
  final double overlayRadius;
  final EdgeInsetsGeometry? padding;

  /// Minimum vertical hit target for interactive scrubbing. The painted track
  /// stays [trackHeight]; extra space is transparent padding so a finger can
  /// grab the bar without pixel-perfect aim.
  final double minInteractiveHeight;

  /// When false, the scrubber is read-only: no thumb, no overlay, and no
  /// pointer interaction. Useful for mini-players where precise scrubbing
  /// is impractical.
  final bool interactive;

  @override
  State<ProgressScrubber> createState() => _ProgressScrubberState();
}

class _ProgressScrubberState extends State<ProgressScrubber> {
  /// How close the engine-reported position must get to a committed seek
  /// target before the preview hands the display back to the engine.
  static const _settleToleranceMs = 800.0;

  /// Upper bound on how long a committed preview may outlive its seek. Covers
  /// seeks the engine never confirms near the target (failed seek, track
  /// completion rolling into the next track).
  static const _settleTimeout = Duration(milliseconds: 1500);

  double? _previewMilliseconds;
  final Set<int> _activePointers = <int>{};
  Timer? _settleTimer;
  bool _globalRouteInstalled = false;
  bool _interactionNotified = false;

  double get _durationMs =>
      widget.duration.inMilliseconds.toDouble().clamp(1, double.infinity);

  bool get _isDragging => _activePointers.isNotEmpty;

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
    if (!_activePointers.contains(event.pointer)) return;
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _finishPointer(event.pointer);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    final wasInactive = _activePointers.isEmpty;
    _activePointers.add(event.pointer);
    _ensureGlobalRoute();
    if (wasInactive) {
      _notifyInteraction(true);
    }
  }

  void _finishPointer(int pointer) {
    if (!_activePointers.remove(pointer)) return;
    if (_activePointers.isEmpty) {
      _removeGlobalRoute();
      _notifyInteraction(false);
    }
  }

  void _clearAllPointers() {
    if (_activePointers.isEmpty) {
      _removeGlobalRoute();
      _notifyInteraction(false);
      return;
    }
    _activePointers.clear();
    _removeGlobalRoute();
    _notifyInteraction(false);
  }

  void _notifyInteraction(bool active) {
    if (_interactionNotified == active) return;
    _interactionNotified = active;
    if (!mounted) return;
    ProgressScrubInteractionNotification(active: active).dispatch(context);
  }

  Future<void> _commitSeek(double value) async {
    final target = Duration(milliseconds: value.round());
    if (mounted) {
      setState(() => _previewMilliseconds = value);
    } else {
      _previewMilliseconds = value;
    }
    try {
      await widget.onSeek(target);
    } finally {
      // Do not clear the preview here: the engine may complete its seek
      // Future before the confirmed position reaches [widget.position], and
      // falling back to the stale engine value would snap the thumb back to
      // the pre-seek position for a few frames. The preview is released in
      // [didUpdateWidget] once the reported position catches up, or by this
      // timer if it never does.
      _settleTimer?.cancel();
      _settleTimer = Timer(_settleTimeout, () {
        if (mounted && _previewMilliseconds == value && !_isDragging) {
          setState(() => _previewMilliseconds = null);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProgressScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    final preview = _previewMilliseconds;
    // Never let engine ticks override the thumb while the user is dragging.
    if (preview == null || _isDragging) return;
    final engineValue = widget.position.inMilliseconds.toDouble();
    if ((engineValue - preview).abs() <= _settleToleranceMs) {
      _settleTimer?.cancel();
      setState(() => _previewMilliseconds = null);
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _clearAllPointers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.interactive;
    final enabled = widget.duration > Duration.zero;
    final engineValue = widget.position.inMilliseconds.toDouble();
    final displayValue = (_previewMilliseconds ?? engineValue)
        .clamp(0, _durationMs)
        .toDouble();
    final fraction = enabled
        ? (displayValue / _durationMs).clamp(0.0, 1.0)
        : 0.0;

    if (!interactive) {
      return _NonInteractiveProgressTrack(
        fraction: fraction,
        trackHeight: widget.trackHeight,
        activeColor: widget.activeColor ?? context.soundPrimaryText,
        inactiveColor: widget.inactiveColor ?? context.soundTint(0.14),
        padding: widget.padding ?? EdgeInsets.zero,
      );
    }

    // Material insets the painted track by overlay/thumb radius when
    // [SliderThemeData.padding] is null. Always supply a padding (callers
    // may pass [EdgeInsets.zero] for horizontal edge alignment) so the track
    // spans the parent width and lines up with title / time labels.
    final resolvedPadding = widget.padding ?? EdgeInsets.zero;
    // Expand vertical hit beyond a hairline track. Prefer explicit vertical
    // padding from the caller; otherwise derive from [minInteractiveHeight].
    final EdgeInsetsGeometry hitPadding;
    if (resolvedPadding.vertical > 0) {
      hitPadding = resolvedPadding;
    } else {
      final vertical = ((widget.minInteractiveHeight - widget.trackHeight) / 2)
          .clamp(12.0, 20.0);
      hitPadding = resolvedPadding.add(
        EdgeInsets.symmetric(vertical: vertical),
      );
    }
    final slider = Slider(
      value: displayValue,
      max: _durationMs,
      padding: hitPadding,
      allowedInteraction: SliderInteraction.tapAndSlide,
      activeColor: widget.activeColor ?? context.soundPrimaryText,
      onChangeStart: enabled
          ? (value) {
              // Slider won the arena — keep interaction latched even if the
              // outer Listener misses later up events outside its bounds.
              _notifyInteraction(true);
              setState(() => _previewMilliseconds = value);
            }
          : null,
      onChanged: enabled
          ? (value) => setState(() => _previewMilliseconds = value)
          : null,
      onChangeEnd: enabled
          ? (value) {
              unawaited(_commitSeek(value));
              // Always release latch after a gesture ends so the bar cannot
              // get permanently stuck non-interactive / dismiss-blocked.
              _clearAllPointers();
            }
          : null,
    );
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: widget.trackHeight,
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: widget.thumbRadius,
          elevation: 0,
          pressedElevation: 0,
        ),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: widget.overlayRadius,
        ),
        // Soft press ring — overlay radius mainly expands the hit target.
        overlayColor: (widget.activeColor ?? context.soundPrimaryText)
            .withValues(alpha: 0.10),
        inactiveTrackColor: widget.inactiveColor ?? context.soundTint(0.14),
        // Keep padding non-null so BaseSliderTrackShape uses full width.
        padding: hitPadding,
      ),
      child: SizedBox(
        height: widget.minInteractiveHeight,
        child: Listener(
          // Translucent so we still see downs early for dismiss suppression,
          // without eating events the Slider needs after the finger leaves
          // this box (global route finishes those pointers).
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerDown,
          onPointerUp: (event) => _finishPointer(event.pointer),
          onPointerCancel: (event) => _finishPointer(event.pointer),
          child: Center(child: slider),
        ),
      ),
    );
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
          // Prefer filling the parent height when it matches [trackHeight]
          // (docked mini player). Centering inside a taller box leaves a
          // visible hairline of the bar surface above the fill.
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
