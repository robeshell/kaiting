import '../library_records.dart';

const unsynchronizedLyricTimestampMs = -1;

final _timestampPattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
final _metadataPattern = RegExp(
  r'^\s*\[(?:ar|al|ti|au|by|re|ve|length):.*\]\s*$',
  caseSensitive: false,
);
final _offsetPattern = RegExp(
  r'^\s*\[offset:([+-]?\d+)\]\s*$',
  caseSensitive: false,
);

List<LibraryLyricRecord> parseEmbeddedLyrics(String trackId, String? value) {
  final lyrics = value?.replaceFirst('\ufeff', '').trim();
  if (lyrics == null || lyrics.isEmpty) return const [];

  final timedLines = <(int, int, String)>[];
  final plainLines = <String>[];
  final sourceLines = lyrics.split(RegExp(r'\r?\n'));
  var offsetMs = 0;
  for (final line in sourceLines) {
    final match = _offsetPattern.firstMatch(line);
    if (match != null) offsetMs = int.parse(match.group(1)!);
  }

  var originalOrder = 0;
  for (final line in sourceLines) {
    if (_metadataPattern.hasMatch(line) || _offsetPattern.hasMatch(line)) {
      continue;
    }
    final matches = _timestampPattern.allMatches(line).toList(growable: false);
    final text = line.replaceAll(_timestampPattern, '').trim();
    if (matches.isEmpty) {
      if (text.isNotEmpty) plainLines.add(text);
      continue;
    }
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
        mathMax(0, (minutes * 60 + seconds) * 1000 + fractionMs + offsetMs),
        originalOrder++,
        text,
      ));
    }
  }

  if (timedLines.isEmpty) {
    return [
      for (var index = 0; index < plainLines.length; index++)
        LibraryLyricRecord(
          trackId: trackId,
          sequence: index,
          timestampMs: unsynchronizedLyricTimestampMs,
          text: plainLines[index],
        ),
    ];
  }
  timedLines.sort((left, right) {
    final timestampOrder = left.$1.compareTo(right.$1);
    return timestampOrder != 0 ? timestampOrder : left.$2.compareTo(right.$2);
  });
  final seen = <(int, String)>{};
  final deduplicated = [
    for (final line in timedLines)
      if (seen.add((line.$1, line.$3))) line,
  ];
  return [
    for (var index = 0; index < deduplicated.length; index++)
      LibraryLyricRecord(
        trackId: trackId,
        sequence: index,
        timestampMs: deduplicated[index].$1,
        text: deduplicated[index].$3,
      ),
  ];
}

/// Converts legacy persisted lyrics (including a whole raw LRC document stored
/// in one row) to the same representation used by new scans.
List<LibraryLyricRecord> normalizePersistedLyrics(
  String trackId,
  List<LibraryLyricRecord> records,
) {
  if (records.isEmpty) return const [];
  final containsRawDocument = records.any(
    (record) =>
        record.text.contains('\n') || _timestampPattern.hasMatch(record.text),
  );
  if (containsRawDocument) {
    return parseEmbeddedLyrics(
      trackId,
      records.map((record) => record.text).join('\n'),
    );
  }
  return records
      .where((record) => record.text.trim().isNotEmpty)
      .toList(growable: false);
}

int mathMax(int left, int right) => left > right ? left : right;
