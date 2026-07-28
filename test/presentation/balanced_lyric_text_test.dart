import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/presentation/widgets/balanced_lyric_text.dart';

void main() {
  const style = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.7);

  test('leaves short lines unchanged', () {
    expect(
      balanceLyricLineBreaks('你好', style: style, maxWidth: 200),
      '你好',
    );
  });

  test('pulls a single trailing character onto the last line when possible', () {
    // Width that fits ~5 full-width CJK characters per line.
    final sample = TextPainter(
      text: const TextSpan(text: '国', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final maxWidth = sample.width * 5 + 1;

    // 11 chars → natural 5+5+1 orphan without balancing.
    const source = '一二三四五六七八九十甲';
    final balanced = balanceLyricLineBreaks(
      source,
      style: style,
      maxWidth: maxWidth,
    );

    expect(balanced.contains('\n'), isTrue);
    final lastLine = balanced.split('\n').last;
    expect(lastLine.characters.length, greaterThanOrEqualTo(2));
  });
}
