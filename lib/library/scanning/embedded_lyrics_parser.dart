import '../library_records.dart';

List<LibraryLyricRecord> parseEmbeddedLyrics(String trackId, String? value) {
  final lyrics = value?.trim();
  if (lyrics == null || lyrics.isEmpty) return const [];

  final timestampPattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final timedLines = <(int, int, String)>[];
  var originalOrder = 0;
  for (final line in lyrics.split(RegExp(r'\r?\n'))) {
    final matches = timestampPattern.allMatches(line).toList(growable: false);
    if (matches.isEmpty) continue;
    final text = line.replaceAll(timestampPattern, '').trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3);
      final fractionMs = switch (fraction?.length) {
        1 => int.parse(fraction!) * 100,
        2 => int.parse(fraction!) * 10,
        3 => int.parse(fraction!),
        _ => 0,
      };
      timedLines.add((
        (minutes * 60 + seconds) * 1000 + fractionMs,
        originalOrder++,
        text,
      ));
    }
  }

  if (timedLines.isEmpty) {
    return [
      LibraryLyricRecord(
        trackId: trackId,
        sequence: 0,
        timestampMs: 0,
        text: lyrics,
      ),
    ];
  }
  timedLines.sort((left, right) {
    final timestampOrder = left.$1.compareTo(right.$1);
    return timestampOrder != 0 ? timestampOrder : left.$2.compareTo(right.$2);
  });
  return [
    for (var index = 0; index < timedLines.length; index++)
      LibraryLyricRecord(
        trackId: trackId,
        sequence: index,
        timestampMs: timedLines[index].$1,
        text: timedLines[index].$3,
      ),
  ];
}
