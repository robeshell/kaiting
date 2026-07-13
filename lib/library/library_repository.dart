import 'library_records.dart';

abstract interface class LibraryRepository {
  Stream<List<LibrarySourceRecord>> watchSources();
  Stream<List<LibraryArtistRecord>> watchArtists();
  Stream<List<LibraryAlbumRecord>> watchAlbums();
  Stream<List<LibraryTrackRecord>> watchTracks();
  Stream<List<LibraryFavoriteTrackRecord>> watchFavoriteTracks();
  Stream<List<LibraryPlayHistoryRecord>> watchPlayHistory({int limit = 500});
  Stream<List<LibraryPlaylistRecord>> watchPlaylists();
  Stream<List<LibraryPlaylistTrackRecord>> watchPlaylistTracks();

  Future<List<LibrarySourceRecord>> getSources();
  Future<LibrarySourceRecord?> getSource(String id);
  Future<List<LibraryArtistRecord>> getArtists({String? sourceId});
  Future<List<LibraryAlbumRecord>> getAlbums({String? sourceId});
  Future<List<LibraryTrackRecord>> getTracks({String? sourceId});
  Future<List<LibraryLyricRecord>> getLyrics(String trackId);
  Future<Map<String, List<LibraryLyricRecord>>> getAllLyrics();
  Future<List<LibraryFavoriteTrackRecord>> getFavoriteTracks();
  Future<List<LibraryPlayHistoryRecord>> getPlayHistory({int limit = 500});
  Future<List<LibraryPlaylistRecord>> getPlaylists();
  Future<List<LibraryPlaylistTrackRecord>> getPlaylistTracks({int? playlistId});

  Future<void> upsertSource(LibrarySourceRecord source);
  Future<void> deleteSource(String id);
  Future<void> markSourceScanning(String id, {required DateTime startedAt});
  Future<void> markSourceFailure(
    String id, {
    required LibrarySourceStatus status,
    required String message,
    required DateTime occurredAt,
  });
  Future<void> replaceSourceScan(LibraryScanBatch batch);
  Future<void> setTrackFavorite(
    String trackId, {
    required bool favorite,
    required DateTime changedAt,
  });
  Future<void> addPlayHistory(String trackId, {required DateTime playedAt});
  Future<void> clearPlayHistory();
  Future<int> createPlaylist({
    required String name,
    required DateTime createdAt,
  });
  Future<void> renamePlaylist(
    int playlistId, {
    required String name,
    required DateTime changedAt,
  });
  Future<void> deletePlaylist(int playlistId);
  Future<bool> addTrackToPlaylist(
    int playlistId,
    String trackId, {
    required DateTime addedAt,
  });
  Future<void> removeTrackFromPlaylist(
    int playlistId,
    String trackId, {
    required DateTime changedAt,
  });
  Future<void> reorderPlaylistTracks(
    int playlistId,
    List<String> orderedTrackIds, {
    required DateTime changedAt,
  });

  Future<void> close();
}
