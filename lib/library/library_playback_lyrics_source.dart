import '../domain/library_models.dart';
import '../playback/playback_lyrics_source.dart';
import 'library_records.dart';
import 'library_repository.dart';
import 'scanning/embedded_lyrics_parser.dart';

/// [PlaybackLyricsSource] backed by the library lyrics table.
class LibraryPlaybackLyricsSource implements PlaybackLyricsSource {
  const LibraryPlaybackLyricsSource(this.repository);

  final LibraryRepository repository;

  @override
  Future<List<LyricLine>> lyricsForTrack(String trackId) async {
    final records = await repository.getLyrics(trackId);
    return _mapLyrics(trackId, records);
  }

  @override
  Future<Map<String, List<LyricLine>>> lyricsForTracks(
    Iterable<String> trackIds,
  ) async {
    final needed = trackIds.toSet();
    if (needed.isEmpty) return const {};
    final byTrack = await repository.getLyricsForTrackIds(needed);
    return {
      for (final id in needed)
        if (byTrack[id] case final records? when records.isNotEmpty)
          id: _mapLyrics(id, records),
    };
  }
}

List<LyricLine> _mapLyrics(String trackId, List<LibraryLyricRecord> records) =>
    [
      for (final lyric in normalizePersistedLyrics(trackId, records))
        LyricLine(
          lyric.timestampMs == unsynchronizedLyricTimestampMs
              ? null
              : Duration(milliseconds: lyric.timestampMs),
          lyric.text,
        ),
    ];
