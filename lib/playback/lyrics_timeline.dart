import '../domain/library_models.dart';

/// A single, testable interpretation of a track's lyric timing.
///
/// Timestamped text is treated as source data, not guessed to be a lyric or a
/// credit from its wording. Multiple lines with the same timestamp form one
/// cue and are highlighted together.
class LyricsTimeline {
  LyricsTimeline._(this.lines, this.isSynchronized, this._timedIndices);

  factory LyricsTimeline.forTrack(Track track) {
    final lines = track.lyrics;
    final synchronized =
        lines.isNotEmpty && lines.every((line) => line.time != null);
    return LyricsTimeline._(
      lines,
      synchronized,
      synchronized
          ? List<int>.generate(lines.length, (index) => index)
          : const [],
    );
  }

  final List<LyricLine> lines;
  final bool isSynchronized;
  final List<int> _timedIndices;

  bool get hasTimedContent => _timedIndices.isNotEmpty;

  bool isSeekable(int index) =>
      isSynchronized && index >= 0 && index < lines.length;

  /// Selects the last line whose timestamp has started.
  ///
  /// No implicit lead time is applied here. Presentation code may scroll a
  /// little ahead, but the active cue remains tied to the playback clock.
  int? activeLineIndex(Duration position, {Duration offset = Duration.zero}) {
    if (!isSynchronized || _timedIndices.isEmpty) return null;
    final targetMs = position.inMilliseconds + offset.inMilliseconds;
    var low = 0;
    var high = _timedIndices.length - 1;
    int? result;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final lineIndex = _timedIndices[middle];
      final timestamp = lines[lineIndex].time!.inMilliseconds;
      if (timestamp <= targetMs) {
        result = lineIndex;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return result;
  }

  /// Returns the first displayed line belonging to [index]'s timestamp cue.
  int cueStartIndex(int index) {
    if (!isSeekable(index)) return index;
    final timestamp = lines[index].time;
    var first = index;
    while (first > 0 && lines[first - 1].time == timestamp) {
      first--;
    }
    return first;
  }

  bool isInCue(int index, int? activeIndex) {
    if (activeIndex == null || !isSeekable(index)) return false;
    return lines[index].time == lines[activeIndex].time;
  }
}
