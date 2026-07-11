import 'package:flutter/material.dart';

class ProgressScrubber extends StatefulWidget {
  const ProgressScrubber({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.activeColor,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color? activeColor;

  @override
  State<ProgressScrubber> createState() => _ProgressScrubberState();
}

class _ProgressScrubberState extends State<ProgressScrubber> {
  double? _previewMilliseconds;

  double get _durationMs =>
      widget.duration.inMilliseconds.toDouble().clamp(1, double.infinity);

  @override
  Widget build(BuildContext context) {
    final engineValue = widget.position.inMilliseconds.toDouble();
    final displayValue = (_previewMilliseconds ?? engineValue)
        .clamp(0, _durationMs)
        .toDouble();
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
      ),
      child: Slider(
        value: displayValue,
        max: _durationMs,
        activeColor: widget.activeColor ?? Colors.white,
        onChanged: (value) => setState(() => _previewMilliseconds = value),
        onChangeEnd: (value) {
          setState(() => _previewMilliseconds = null);
          widget.onSeek(Duration(milliseconds: value.round()));
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
