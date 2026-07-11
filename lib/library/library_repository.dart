import 'library_records.dart';

abstract interface class LibraryRepository {
  Stream<List<LibrarySourceRecord>> watchSources();
  Stream<List<LibraryArtistRecord>> watchArtists();
  Stream<List<LibraryAlbumRecord>> watchAlbums();
  Stream<List<LibraryTrackRecord>> watchTracks();

  Future<List<LibrarySourceRecord>> getSources();
  Future<LibrarySourceRecord?> getSource(String id);
  Future<List<LibraryArtistRecord>> getArtists({String? sourceId});
  Future<List<LibraryAlbumRecord>> getAlbums({String? sourceId});
  Future<List<LibraryTrackRecord>> getTracks({String? sourceId});
  Future<List<LibraryLyricRecord>> getLyrics(String trackId);

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

  Future<void> close();
}
