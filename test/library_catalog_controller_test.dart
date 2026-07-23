import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/library/persistence/drift_library_repository.dart';
import 'package:kaiting/library/persistence/library_database.dart';
import 'package:kaiting/presentation/controllers/library_catalog_controller.dart';

void main() {
  test(
    'maps persisted metadata and media resources into presentation models',
    () {
      final now = DateTime.utc(2026, 7, 11);
      final result = mapLibraryAlbums(
        sources: [
          LibrarySourceRecord(
            id: 'source:local',
            type: LibrarySourceType.local,
            displayName: 'Music',
            rootUri: 'file:///music/',
            status: LibrarySourceStatus.available,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        albums: const [
          LibraryAlbumRecord(
            id: 'album:real',
            sourceId: 'source:local',
            title: 'Indexed Album',
            sortTitle: 'indexed album',
            albumArtist: 'Indexed Artist',
            year: 2025,
            genre: 'Ambient',
            artworkKey: 'file:///cache/cover.jpg',
          ),
        ],
        tracks: [
          LibraryTrackRecord(
            id: 'track:real',
            sourceId: 'source:local',
            albumId: 'album:real',
            relativePath: 'album/song.flac',
            mediaUri: 'file:///music/album/song.flac',
            title: 'Indexed Track',
            artistName: 'Indexed Artist',
            albumTitle: 'Indexed Album',
            durationMs: 182000,
            trackNumber: 3,
            discNumber: 2,
            modifiedAt: now,
          ),
        ],
        lyricsByTrackId: const {
          'track:real': [
            LibraryLyricRecord(
              trackId: 'track:real',
              sequence: 0,
              timestampMs: 1200,
              text: 'A real lyric',
            ),
          ],
        },
      );

      expect(result, hasLength(1));
      final album = result.single;
      expect(album.title, 'Indexed Album');
      expect(album.source, SourceKind.local);
      expect(album.year, 2025);
      expect(album.genre, 'Ambient');
      expect(album.artworkUri, 'file:///cache/cover.jpg');

      final track = album.tracks.single;
      expect(track.mediaUri, 'file:///music/album/song.flac');
      expect(track.artworkUri, album.artworkUri);
      expect(track.year, album.year);
      expect(track.genre, album.genre);
      expect(track.discNumber, 2);
      expect(track.lyrics.single.text, 'A real lyric');
      expect(track.lyrics.single.time, const Duration(milliseconds: 1200));
    },
  );

  test('omits empty albums instead of creating fake tracks', () {
    final result = mapLibraryAlbums(
      sources: const [],
      albums: const [
        LibraryAlbumRecord(
          id: 'album:empty',
          sourceId: 'source:missing',
          title: 'Empty Album',
          sortTitle: 'empty album',
          albumArtist: 'Unknown Artist',
        ),
      ],
      tracks: const [],
      lyricsByTrackId: const {},
    );

    expect(result, isEmpty);
  });

  test('normalizes legacy WebDAV raw LRC before presentation', () {
    final now = DateTime.utc(2026, 7, 14);
    final albums = mapLibraryAlbums(
      sources: [
        LibrarySourceRecord(
          id: 'webdav',
          type: LibrarySourceType.webDav,
          displayName: 'NAS',
          rootUri: 'https://example.test/music/',
          status: LibrarySourceStatus.available,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      albums: const [
        LibraryAlbumRecord(
          id: 'album',
          sourceId: 'webdav',
          title: 'Album',
          sortTitle: 'album',
          albumArtist: 'Artist',
        ),
      ],
      tracks: [
        LibraryTrackRecord(
          id: 'track',
          sourceId: 'webdav',
          albumId: 'album',
          relativePath: 'song.flac',
          mediaUri: 'https://example.test/music/song.flac',
          title: 'Song',
          artistName: 'Artist',
          albumTitle: 'Album',
          durationMs: 60000,
          modifiedAt: now,
        ),
      ],
      lyricsByTrackId: const {
        'track': [
          LibraryLyricRecord(
            trackId: 'track',
            sequence: 0,
            timestampMs: 0,
            text: '[00:01.00]First\n[00:02.00]Second',
          ),
        ],
      },
    );

    final lyrics = albums.single.tracks.single.lyrics;
    expect(lyrics.map((line) => line.text), ['First', 'Second']);
    expect(lyrics.map((line) => line.time), const [
      Duration(seconds: 1),
      Duration(seconds: 2),
    ]);
  });

  test('refresh batches lyrics and caches the flattened track list', () async {
    final now = DateTime.utc(2026, 7, 13);
    final repository = _CountingLibraryRepository(
      LibraryDatabase(NativeDatabase.memory()),
    );
    await repository.upsertSource(
      LibrarySourceRecord(
        id: 'source',
        type: LibrarySourceType.local,
        displayName: 'Music',
        rootUri: 'file:///music/',
        status: LibrarySourceStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.replaceSourceScan(
      LibraryScanBatch(
        sourceId: 'source',
        completedAt: now,
        albums: const [
          LibraryAlbumRecord(
            id: 'album',
            sourceId: 'source',
            title: 'Album',
            sortTitle: 'album',
            albumArtist: 'Artist',
          ),
        ],
        tracks: [
          LibraryTrackRecord(
            id: 'track',
            sourceId: 'source',
            albumId: 'album',
            relativePath: 'track.flac',
            mediaUri: 'file:///music/track.flac',
            title: 'Track',
            artistName: 'Artist',
            albumTitle: 'Album',
            durationMs: 1000,
            modifiedAt: now,
          ),
        ],
      ),
    );
    final catalog = LibraryCatalogController(repository: repository);

    await catalog.refresh();

    expect(repository.allLyricsCalls, 1);
    expect(repository.singleTrackLyricCalls, 0);
    expect(catalog.tracks.single.id, 'track');
    expect(identical(catalog.tracks, catalog.tracks), isTrue);

    catalog.dispose();
    await Future<void>.delayed(Duration.zero);
    await repository.close();
  });

  test(
    'initial snapshot is ready synchronously and skips the duplicate watch read',
    () async {
      final repository = _CountingLibraryRepository(
        LibraryDatabase(NativeDatabase.memory()),
      );
      const snapshot = LibraryCatalogSnapshot(
        sources: [],
        albums: [],
        tracks: [],
        lyricsByTrackId: {},
      );

      final catalog = LibraryCatalogController(
        repository: repository,
        initialSnapshot: snapshot,
      );

      expect(catalog.status, LibraryCatalogStatus.ready);
      expect(catalog.albums, isEmpty);
      expect(repository.catalogReadCalls, 0);

      repository.emitTracks(const []);
      await Future<void>.delayed(Duration.zero);

      expect(repository.catalogReadCalls, 0);

      catalog.dispose();
      await Future<void>.delayed(Duration.zero);
      await repository.close();
    },
  );
}

class _CountingLibraryRepository extends DriftLibraryRepository {
  _CountingLibraryRepository(super.database);

  final _trackChanges = StreamController<List<LibraryTrackRecord>>.broadcast();
  int sourcesCalls = 0;
  int albumsCalls = 0;
  int tracksCalls = 0;
  int allLyricsCalls = 0;
  int singleTrackLyricCalls = 0;
  int get catalogReadCalls =>
      sourcesCalls + albumsCalls + tracksCalls + allLyricsCalls;

  void emitTracks(List<LibraryTrackRecord> tracks) => _trackChanges.add(tracks);

  @override
  Stream<List<LibraryTrackRecord>> watchTracks() => _trackChanges.stream;

  @override
  Future<List<LibrarySourceRecord>> getSources() {
    sourcesCalls++;
    return super.getSources();
  }

  @override
  Future<List<LibraryAlbumRecord>> getAlbums({String? sourceId}) {
    albumsCalls++;
    return super.getAlbums(sourceId: sourceId);
  }

  @override
  Future<List<LibraryTrackRecord>> getTracks({String? sourceId}) {
    tracksCalls++;
    return super.getTracks(sourceId: sourceId);
  }

  @override
  Future<Map<String, List<LibraryLyricRecord>>> getAllLyrics() {
    allLyricsCalls++;
    return super.getAllLyrics();
  }

  @override
  Future<List<LibraryLyricRecord>> getLyrics(String trackId) {
    singleTrackLyricCalls++;
    return super.getLyrics(trackId);
  }

  @override
  Future<void> close() async {
    await _trackChanges.close();
    await super.close();
  }
}
