import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/playback/lyrics_timeline.dart';

void main() {
  test('timestamped source text participates without semantic guessing', () {
    final timeline = LyricsTimeline.forTrack(
      _track([
        const LyricLine(Duration.zero, '作词 : 方文山'),
        const LyricLine(Duration(seconds: 1), '作曲 : 周杰伦'),
        const LyricLine(Duration(seconds: 2), '编曲 : 洪敬尧'),
        const LyricLine(Duration(milliseconds: 32350), '琥珀色黄昏像糖'),
        const LyricLine(Duration(milliseconds: 36420), '你的脸没有化妆'),
      ]),
    );

    expect(timeline.isSeekable(0), isTrue);
    expect(timeline.isSeekable(2), isTrue);
    expect(timeline.activeLineIndex(const Duration(seconds: 20)), 2);
    expect(timeline.activeLineIndex(const Duration(milliseconds: 32350)), 3);
    expect(timeline.activeLineIndex(const Duration(seconds: 40)), 4);
  });

  test('same-timestamp lines form one active cue', () {
    final timeline = LyricsTimeline.forTrack(
      _track([
        const LyricLine(Duration(seconds: 5), 'Original'),
        const LyricLine(Duration(seconds: 5), 'Translation'),
        const LyricLine(Duration(seconds: 9), 'Next'),
      ]),
    );

    expect(timeline.activeLineIndex(const Duration(seconds: 5)), 1);
    expect(timeline.cueStartIndex(1), 0);
    expect(timeline.isInCue(0, 1), isTrue);
    expect(timeline.isInCue(1, 1), isTrue);
    expect(timeline.activeLineIndex(const Duration(seconds: 8)), 1);
    expect(timeline.activeLineIndex(const Duration(seconds: 9)), 2);
  });

  test('selection does not switch before the exact timestamp boundary', () {
    final timeline = LyricsTimeline.forTrack(
      _track([
        const LyricLine(Duration(seconds: 5), 'First'),
        const LyricLine(Duration(seconds: 10), 'Second'),
      ]),
    );

    expect(timeline.activeLineIndex(const Duration(milliseconds: 9999)), 0);
    expect(timeline.activeLineIndex(const Duration(seconds: 10)), 1);
  });

  test('plain lyrics are not exposed as a synchronized timeline', () {
    final timeline = LyricsTimeline.forTrack(
      _track(const [LyricLine(null, 'First'), LyricLine(null, 'Second')]),
    );

    expect(timeline.isSynchronized, isFalse);
    expect(timeline.activeLineIndex(const Duration(seconds: 5)), isNull);
  });
}

Track _track(List<LyricLine> lyrics) => Track(
  id: 'track',
  title: '园游会',
  artist: '周杰伦',
  albumTitle: '七里香',
  duration: const Duration(minutes: 4),
  source: SourceKind.local,
  lyrics: lyrics,
);
