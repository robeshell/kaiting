import '../domain/library_models.dart';

/// Looks up catalog lyrics for playback without coupling the controller to a
/// specific library store.
///
/// Session persistence only embeds lyrics for the *current* track. All other
/// queue entries restore with empty lyrics. Callers (and
/// [SoundPlaybackController]) use this source to reattach lyrics by track id
/// before display / after session restore.
abstract interface class PlaybackLyricsSource {
  /// Lyrics for [trackId], or an empty list when the catalog has none.
  Future<List<LyricLine>> lyricsForTrack(String trackId);

  /// Batch lookup. Prefer a single store round-trip when many ids are missing.
  Future<Map<String, List<LyricLine>>> lyricsForTracks(
    Iterable<String> trackIds,
  );
}

/// Sequential [PlaybackLyricsSource.lyricsForTrack] fallback for tests/fakes.
mixin SequentialPlaybackLyricsLookup on PlaybackLyricsSource {
  @override
  Future<Map<String, List<LyricLine>>> lyricsForTracks(
    Iterable<String> trackIds,
  ) async {
    final result = <String, List<LyricLine>>{};
    for (final id in trackIds) {
      final lyrics = await lyricsForTrack(id);
      if (lyrics.isNotEmpty) result[id] = lyrics;
    }
    return result;
  }
}
