import 'package:flutter/material.dart';

import 'balanced_lyric_text.dart';

/// Lyric line with left-to-right karaoke color fill driven by [progressListenable].
///
/// Layout (break balancing) is cached and only recomputed when text / width /
/// style change. Position ticks only update the clip fraction so the rest of
/// the lyrics list does not rebuild.
class KaraokeLyricText extends StatefulWidget {
  const KaraokeLyricText(
    this.text, {
    required this.style,
    required this.progressListenable,
    required this.progressOf,
    required this.fillColor,
    required this.baseColor,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String text;
  final TextStyle style;
  final Listenable progressListenable;
  final double Function() progressOf;
  final Color fillColor;
  final Color baseColor;
  final TextAlign textAlign;

  @override
  State<KaraokeLyricText> createState() => _KaraokeLyricTextState();
}

class _KaraokeLyricTextState extends State<KaraokeLyricText> {
  String? _balanced;
  double? _layoutWidth;
  TextStyle? _layoutStyle;
  String? _layoutText;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _progress = widget.progressOf().clamp(0.0, 1.0);
    widget.progressListenable.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant KaraokeLyricText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progressListenable != widget.progressListenable) {
      oldWidget.progressListenable.removeListener(_onTick);
      widget.progressListenable.addListener(_onTick);
    }
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.fillColor != widget.fillColor ||
        oldWidget.baseColor != widget.baseColor) {
      _balanced = null;
    }
    _progress = widget.progressOf().clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    widget.progressListenable.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    final next = widget.progressOf().clamp(0.0, 1.0);
    // Skip sub-pixel paint storms; ~0.5% steps still look smooth.
    if ((next - _progress).abs() < 0.005) return;
    setState(() => _progress = next);
  }

  String _balancedFor(double maxWidth, TextScaler scaler) {
    if (_balanced != null &&
        _layoutWidth == maxWidth &&
        _layoutStyle == widget.style &&
        _layoutText == widget.text) {
      return _balanced!;
    }
    final balanced = (!maxWidth.isFinite || maxWidth <= 0)
        ? widget.text
        : balanceLyricLineBreaks(
            widget.text,
            style: widget.style,
            maxWidth: maxWidth,
            textScaler: scaler,
          );
    _balanced = balanced;
    _layoutWidth = maxWidth;
    _layoutStyle = widget.style;
    _layoutText = widget.text;
    return balanced;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final balanced = _balancedFor(
          constraints.maxWidth,
          MediaQuery.textScalerOf(context),
        );
        final baseStyle = widget.style.copyWith(color: widget.baseColor);
        final fillStyle = widget.style.copyWith(color: widget.fillColor);
        final align = widget.textAlign;
        final p = _progress;
        if (p <= 0.001) {
          return Text(balanced, style: baseStyle, textAlign: align);
        }
        if (p >= 0.999) {
          return Text(balanced, style: fillStyle, textAlign: align);
        }
        return Stack(
          alignment: align == TextAlign.center
              ? Alignment.topCenter
              : Alignment.topLeft,
          children: [
            Text(balanced, style: baseStyle, textAlign: align),
            ClipRect(
              clipper: _LeadingFractionClipper(p),
              child: Text(balanced, style: fillStyle, textAlign: align),
            ),
          ],
        );
      },
    );
  }
}

class _LeadingFractionClipper extends CustomClipper<Rect> {
  const _LeadingFractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(covariant _LeadingFractionClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}
