import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/library/scanning/embedded_lyrics_parser.dart';

void main() {
  test('sorts LRC timestamps and supports multiple timestamps per line', () {
    final lyrics = parseEmbeddedLyrics(
      'track-one',
      '[00:02.50]Later\n[00:01.2][00:03.025]Repeated',
    );

    expect(lyrics.map((line) => line.timestampMs), [1200, 2500, 3025]);
    expect(lyrics.map((line) => line.text), ['Repeated', 'Later', 'Repeated']);
    expect(lyrics.map((line) => line.sequence), [0, 1, 2]);
  });

  test('keeps unsynchronized lyrics as a single record', () {
    final lyrics = parseEmbeddedLyrics('track-one', 'First\nSecond');

    expect(lyrics, hasLength(1));
    expect(lyrics.single.timestampMs, 0);
    expect(lyrics.single.text, 'First\nSecond');
  });
}
