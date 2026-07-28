import 'package:flutter/material.dart';

import 'balanced_lyric_text.dart';

/// Lyric line with left-to-right karaoke color fill.
///
/// Uses the same break balancing as [BalancedLyricText], then clips a fully
/// opaque fill over a softer base using the current cue progress (0–1).
///
/// With standard line-level LRC this approximates singing progress between
/// consecutive timestamps; word-level enhanced LRC is not required.
class KaraokeLyricText extends StatelessWidget {
  const KaraokeLyricText(
    this.text, {
    required this.style,
    required this.progress,
    required this.fillColor,
    required this.baseColor,
    super.key,
  });

  final String text;
  final TextStyle style;

  /// 0 = not started, 1 = fully filled.
  final double progress;
  final Color fillColor;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final scaler = MediaQuery.textScalerOf(context);
        final balanced = (!maxWidth.isFinite || maxWidth <= 0)
            ? text
            : balanceLyricLineBreaks(
                text,
                style: style,
                maxWidth: maxWidth,
                textScaler: scaler,
              );
        final clamped = progress.clamp(0.0, 1.0);
        final baseStyle = style.copyWith(color: baseColor);
        final fillStyle = style.copyWith(color: fillColor);
        // When nearly full / empty, skip the stack for cheaper paints.
        if (clamped <= 0.001) {
          return Text(balanced, style: baseStyle);
        }
        if (clamped >= 0.999) {
          return Text(balanced, style: fillStyle);
        }
        return Stack(
          alignment: Alignment.topLeft,
          children: [
            Text(balanced, style: baseStyle),
            ClipRect(
              clipper: _LeadingFractionClipper(clamped),
              child: Text(balanced, style: fillStyle),
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
