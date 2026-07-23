import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/library/scanning/embedded_lyrics_parser.dart';

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

  test('keeps unsynchronized lyrics as clean individual lines', () {
    final lyrics = parseEmbeddedLyrics('track-one', 'First\nSecond');

    expect(lyrics, hasLength(2));
    expect(
      lyrics.map((line) => line.timestampMs),
      everyElement(unsynchronizedLyricTimestampMs),
    );
    expect(lyrics.map((line) => line.text), ['First', 'Second']);
  });

  test('removes metadata, applies offset, and deduplicates timed lines', () {
    final lyrics = parseEmbeddedLyrics(
      'track-one',
      '[ar:Artist]\n[offset:-500]\n[00:01.00]First\n'
          '[00:01.00]First\n[00:00.20]Clamped',
    );

    expect(lyrics.map((line) => line.timestampMs), [0, 500]);
    expect(lyrics.map((line) => line.text), ['Clamped', 'First']);
  });

  test('normalizes a legacy raw LRC database row', () {
    final normalized = normalizePersistedLyrics('track-one', const [
      LibraryLyricRecord(
        trackId: 'track-one',
        sequence: 0,
        timestampMs: 0,
        text: '[00:01.00]First\n[00:02.00]Second',
      ),
    ]);

    expect(normalized.map((line) => line.timestampMs), [1000, 2000]);
    expect(normalized.map((line) => line.text), ['First', 'Second']);
  });
}
