import 'package:drift/native.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/library/persistence/drift_library_repository.dart';
import 'package:kaiting/library/persistence/library_database.dart';

class LibraryBenchmarkFixture {
  const LibraryBenchmarkFixture({
    required this.source,
    required this.albums,
    required this.tracks,
    required this.lyricsByTrackId,
  });

  factory LibraryBenchmarkFixture.generate(
    int trackCount, {
    bool includeArtwork = true,
  }) {
    final now = DateTime.utc(2026, 7, 13);
    const sourceId = 'benchmark:local';
    const tracksPerAlbum = 10;
    final albumCount = (trackCount / tracksPerAlbum).ceil();
    final albums = <LibraryAlbumRecord>[];
    final tracks = <LibraryTrackRecord>[];
    final lyrics = <String, List<LibraryLyricRecord>>{};

    for (var albumIndex = 0; albumIndex < albumCount; albumIndex++) {
      final albumId = 'album-$albumIndex';
      albums.add(
        LibraryAlbumRecord(
          id: albumId,
          sourceId: sourceId,
          title: 'Album $albumIndex',
          sortTitle: 'album ${albumIndex.toString().padLeft(5, '0')}',
          albumArtist: 'Album Artist ${albumIndex % 100}',
          year: 2000 + albumIndex % 27,
          genre: albumIndex.isEven ? 'Ambient' : 'Rock',
          artworkKey: includeArtwork
              ? 'file:///benchmark/art-$albumIndex.jpg'
              : null,
        ),
      );
    }

    for (var index = 0; index < trackCount; index++) {
      final albumIndex = index ~/ tracksPerAlbum;
      final trackId = 'track-$index';
      tracks.add(
        LibraryTrackRecord(
          id: trackId,
          sourceId: sourceId,
          albumId: 'album-$albumIndex',
          relativePath: 'album-$albumIndex/track-$index.flac',
          mediaUri: 'file:///benchmark/album-$albumIndex/track-$index.flac',
          title: 'Song ${index.toString().padLeft(5, '0')}',
          artistName: 'Artist ${index % 250}',
          albumTitle: 'Album $albumIndex',
          durationMs: 180000 + index % 120000,
          trackNumber: index % tracksPerAlbum + 1,
          discNumber: 1,
          genre: index.isEven ? 'Ambient' : 'Rock',
          modifiedAt: now,
          artworkKey: includeArtwork
              ? 'file:///benchmark/art-$albumIndex.jpg'
              : null,
        ),
      );
      if (index % 10 == 0) {
        lyrics[trackId] = [
          for (var line = 0; line < 5; line++)
            LibraryLyricRecord(
              trackId: trackId,
              sequence: line,
              timestampMs: line * 5000,
              text: 'Lyric line $line for track $index',
            ),
        ];
      }
    }

    return LibraryBenchmarkFixture(
      source: LibrarySourceRecord(
        id: sourceId,
        type: LibrarySourceType.local,
        displayName: 'Benchmark Music',
        rootUri: 'file:///benchmark/',
        status: LibrarySourceStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
      albums: List.unmodifiable(albums),
      tracks: List.unmodifiable(tracks),
      lyricsByTrackId: Map.unmodifiable(lyrics),
    );
  }

  final LibrarySourceRecord source;
  final List<LibraryAlbumRecord> albums;
  final List<LibraryTrackRecord> tracks;
  final Map<String, List<LibraryLyricRecord>> lyricsByTrackId;

  List<LibraryLyricRecord> get lyrics =>
      List.unmodifiable([for (final lines in lyricsByTrackId.values) ...lines]);

  LibraryScanBatch scanBatch(DateTime completedAt) {
    return LibraryScanBatch(
      sourceId: source.id,
      completedAt: completedAt,
      albums: albums,
      tracks: tracks,
      lyrics: lyrics,
    );
  }
}

class BenchmarkLibraryRepository extends DriftLibraryRepository {
  BenchmarkLibraryRepository(this.fixture)
    : super(LibraryDatabase(NativeDatabase.memory()));

  final LibraryBenchmarkFixture fixture;
  int allLyricsCalls = 0;
  int singleTrackLyricCalls = 0;

  @override
  Stream<List<LibraryTrackRecord>> watchTracks() => const Stream.empty();

  @override
  Future<List<LibrarySourceRecord>> getSources() async => [fixture.source];

  @override
  Future<List<LibraryAlbumRecord>> getAlbums({String? sourceId}) async {
    return fixture.albums;
  }

  @override
  Future<List<LibraryTrackRecord>> getTracks({String? sourceId}) async {
    return fixture.tracks;
  }

  @override
  Future<Map<String, List<LibraryLyricRecord>>> getAllLyrics() async {
    allLyricsCalls++;
    return fixture.lyricsByTrackId;
  }

  @override
  Future<List<LibraryLyricRecord>> getLyrics(String trackId) async {
    singleTrackLyricCalls++;
    return fixture.lyricsByTrackId[trackId] ?? const [];
  }
}
