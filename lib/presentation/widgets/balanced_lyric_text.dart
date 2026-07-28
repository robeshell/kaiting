import 'package:flutter/material.dart';

/// Lyric [Text] that reduces awkward single-character wraps (常见「甩一字」).
///
/// Uses [TextPainter] against the real max width. When the last visual line
/// would hold only one character (or two Latin letters), it forces an earlier
/// break so the last line keeps at least two grapheme clusters when possible.
class BalancedLyricText extends StatelessWidget {
  const BalancedLyricText(
    this.text, {
    required this.style,
    super.key,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite || maxWidth <= 0) {
          return Text(text, style: style);
        }
        final balanced = balanceLyricLineBreaks(
          text,
          style: style,
          maxWidth: maxWidth,
          textScaler: MediaQuery.textScalerOf(context),
        );
        return Text(balanced, style: style);
      },
    );
  }
}

/// Pure helper for [BalancedLyricText] / [KaraokeLyricText] and tests.
String balanceLyricLineBreaks(
  String raw, {
  required TextStyle style,
  required double maxWidth,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final text = raw.trimRight();
  if (text.length < 3 || maxWidth <= 8) return text;

  // Up to two passes: fixing the last line can expose another orphan.
  var current = text;
  for (var pass = 0; pass < 2; pass++) {
    final painter = TextPainter(
      text: TextSpan(text: current, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);

    final metrics = painter.computeLineMetrics();
    if (metrics.length < 2) return current;

    final lastStart = _lineStartOffset(
      painter,
      metrics,
      metrics.length - 1,
      plainLength: current.length,
    );
    if (lastStart <= 0 || lastStart >= current.length) return current;

    final lastLine = current.substring(lastStart);
    final lastClusters = _graphemeCount(lastLine);
    // "甩一字" / lonely short Latin tail on the last line.
    final orphan =
        lastClusters == 1 ||
        (lastClusters == 2 && _isMostlyLatin(lastLine) && lastLine.trim().length <= 2);
    if (!orphan) return current;

    // Pull one more cluster onto the last line by breaking one earlier.
    final pullAt = _offsetBeforeLastClusters(current, lastStart, 1);
    if (pullAt <= 0 || pullAt >= lastStart) return current;

    // Avoid creating a 1-char previous segment if possible.
    final previous = current.substring(0, pullAt);
    final tail = current.substring(pullAt);
    if (_graphemeCount(previous.trim()) == 0) return current;

    final candidate = '$previous\n$tail';
    final forced = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final forcedMetrics = forced.computeLineMetrics();
    if (forcedMetrics.isEmpty) return current;
    final forcedLastStart = _lineStartOffset(
      forced,
      forcedMetrics,
      forcedMetrics.length - 1,
      plainLength: candidate.length,
    );
    final forcedLast =
        candidate.substring(forcedLastStart).replaceAll('\n', '');
    if (_graphemeCount(forcedLast) >= 2) {
      current = candidate;
      continue;
    }
    return current;
  }
  return current;
}

int _lineStartOffset(
  TextPainter painter,
  List<LineMetrics> metrics,
  int lineIndex, {
  int? plainLength,
}) {
  if (lineIndex <= 0) return 0;
  var dy = 0.0;
  for (var i = 0; i < lineIndex; i++) {
    dy += metrics[i].height;
  }
  // Mid-line Y so getPositionForOffset lands on that line's first cluster.
  final pos = painter.getPositionForOffset(Offset(0.5, dy + 0.5));
  final max = plainLength ?? _spanPlainText(painter).length;
  return pos.offset.clamp(0, max);
}

String _spanPlainText(TextPainter painter) {
  final span = painter.text;
  if (span is TextSpan) return span.toPlainText();
  return '';
}

int _graphemeCount(String value) {
  // Characters package not a direct dependency; Characters is in Flutter.
  return value.characters.length;
}

bool _isMostlyLatin(String value) {
  if (value.isEmpty) return false;
  var latin = 0;
  for (final unit in value.runes) {
    if ((unit >= 0x41 && unit <= 0x5A) ||
        (unit >= 0x61 && unit <= 0x7A) ||
        unit == 0x20) {
      latin++;
    }
  }
  return latin >= (value.runes.length / 2);
}

/// Offset of the start of the last [count] grapheme clusters before [end].
int _offsetBeforeLastClusters(String text, int end, int count) {
  if (end <= 0) return 0;
  final prefix = text.substring(0, end);
  final chars = prefix.characters;
  if (chars.length <= count) return 0;
  final keep = chars.take(chars.length - count).toString();
  return keep.length;
}
