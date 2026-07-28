import 'dart:async';

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
    this.thumbRadius = 5,
    this.overlayRadius = 14,
    this.padding,
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

  double get _durationMs =>
      widget.duration.inMilliseconds.toDouble().clamp(1, double.infinity);

  void _handlePointerDown(PointerDownEvent event) {
    final wasInactive = _activePointers.isEmpty;
    _activePointers.add(event.pointer);
    if (wasInactive) {
      const ProgressScrubInteractionNotification(active: true).dispatch(context);
    }
  }

  void _finishPointer(int pointer) {
    if (!_activePointers.remove(pointer) || _activePointers.isNotEmpty) return;
    const ProgressScrubInteractionNotification(active: false).dispatch(context);
  }

  Future<void> _commitSeek(double value) async {
    final target = Duration(milliseconds: value.round());
    setState(() => _previewMilliseconds = value);
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
        if (mounted && _previewMilliseconds == value) {
          setState(() => _previewMilliseconds = null);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProgressScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    final preview = _previewMilliseconds;
    if (preview == null || _activePointers.isNotEmpty) return;
    final engineValue = widget.position.inMilliseconds.toDouble();
    if ((engineValue - preview).abs() <= _settleToleranceMs) {
      _settleTimer?.cancel();
      setState(() => _previewMilliseconds = null);
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
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
    final fraction = enabled ? (displayValue / _durationMs).clamp(0.0, 1.0) : 0.0;

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
    // may pass [EdgeInsets.zero]) so the track spans the parent width and
    // lines up with title / time labels on the same column.
    final resolvedPadding = widget.padding ?? EdgeInsets.zero;
    final slider = Slider(
      value: displayValue,
      max: _durationMs,
      padding: resolvedPadding,
      activeColor: widget.activeColor ?? context.soundPrimaryText,
      onChanged: enabled
          ? (value) => setState(() => _previewMilliseconds = value)
          : null,
      onChangeEnd: enabled
          ? (value) => unawaited(_commitSeek(value))
          : null,
    );
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: widget.trackHeight,
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: widget.thumbRadius,
        ),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: widget.overlayRadius,
        ),
        inactiveTrackColor: widget.inactiveColor ?? context.soundTint(0.14),
        // Keep padding non-null so BaseSliderTrackShape uses full width.
        padding: resolvedPadding,
      ),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        onPointerUp: (event) => _finishPointer(event.pointer),
        onPointerCancel: (event) => _finishPointer(event.pointer),
        child: slider,
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
          final height = constraints.maxHeight.isFinite &&
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
                    Expanded(
                      child: Container(color: inactiveColor),
                    ),
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
