import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'balanced_lyric_text.dart';

/// Lyric line with left-to-right karaoke color fill driven by [progressListenable].
///
/// Fill follows **visual line order**: each wrapped line is filled left→right
/// before the next line starts. A simple full-width [ClipRect] is wrong for
/// multi-line / centered text.
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
  TextAlign? _layoutAlign;
  double _progress = 0;
  List<ui.LineMetrics> _metrics = const [];
  double _textHeight = 0;

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
        oldWidget.textAlign != widget.textAlign ||
        oldWidget.fillColor != widget.fillColor ||
        oldWidget.baseColor != widget.baseColor) {
      _balanced = null;
      _metrics = const [];
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
        _layoutText == widget.text &&
        _layoutAlign == widget.textAlign) {
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
    _layoutAlign = widget.textAlign;
    _layoutMetrics(balanced, maxWidth, scaler);
    return balanced;
  }

  void _layoutMetrics(String balanced, double maxWidth, TextScaler scaler) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      _metrics = const [];
      _textHeight = 0;
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: balanced, style: widget.style),
      textAlign: widget.textAlign,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    _metrics = painter.computeLineMetrics();
    _textHeight = painter.height;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final scaler = MediaQuery.textScalerOf(context);
        final balanced = _balancedFor(maxWidth, scaler);
        // Rebuild metrics if width changed after a progress-only setState.
        if (_metrics.isEmpty && balanced.isNotEmpty && maxWidth.isFinite) {
          _layoutMetrics(balanced, maxWidth, scaler);
        }
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

        final height = _textHeight > 0 ? _textHeight : null;
        return SizedBox(
          width: maxWidth.isFinite ? maxWidth : null,
          height: height,
          child: Stack(
            alignment: align == TextAlign.center
                ? Alignment.topCenter
                : Alignment.topLeft,
            children: [
              Text(balanced, style: baseStyle, textAlign: align),
              ClipPath(
                clipper: _KaraokeLineProgressClipper(
                  progress: p,
                  metrics: _metrics,
                ),
                child: Text(balanced, style: fillStyle, textAlign: align),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Clips the fill layer so progress walks each wrapped line LTR in order.
class _KaraokeLineProgressClipper extends CustomClipper<Path> {
  const _KaraokeLineProgressClipper({
    required this.progress,
    required this.metrics,
  });

  final double progress;
  final List<ui.LineMetrics> metrics;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (metrics.isEmpty) {
      // Fallback: single-block LTR wipe (legacy behaviour).
      path.addRect(Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height));
      return path;
    }

    var totalWidth = 0.0;
    for (final line in metrics) {
      totalWidth += line.width;
    }
    if (totalWidth <= 0) {
      path.addRect(Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height));
      return path;
    }

    var remaining = progress.clamp(0.0, 1.0) * totalWidth;
    for (final line in metrics) {
      if (remaining <= 0) break;
      final lineWidth = line.width;
      if (lineWidth <= 0) continue;
      final fillWidth = remaining >= lineWidth ? lineWidth : remaining;
      final top = line.baseline - line.ascent;
      final height = line.height > 0 ? line.height : (line.ascent + line.descent);
      // [LineMetrics.left] already accounts for textAlign (e.g. centered lines).
      path.addRect(Rect.fromLTWH(line.left, top, fillWidth, height));
      remaining -= lineWidth;
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _KaraokeLineProgressClipper oldClipper) {
    if (oldClipper.progress != progress) return true;
    if (oldClipper.metrics.length != metrics.length) return true;
    for (var i = 0; i < metrics.length; i++) {
      final a = oldClipper.metrics[i];
      final b = metrics[i];
      if (a.width != b.width ||
          a.left != b.left ||
          a.baseline != b.baseline ||
          a.height != b.height) {
        return true;
      }
    }
    return false;
  }
}
