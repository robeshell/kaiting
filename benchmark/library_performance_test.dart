import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/library/library_records.dart';
import 'package:sound_player/library/persistence/drift_library_repository.dart';
import 'package:sound_player/library/persistence/library_database.dart';
import 'package:sound_player/presentation/controllers/library_catalog_controller.dart';
import 'package:sound_player/presentation/controllers/library_search_controller.dart';

void main() {
  for (final trackCount in const [1000, 10000]) {
    test(
      'library pipeline baseline with $trackCount tracks',
      () async {
        final fixture = _LibraryFixture.generate(trackCount);
        final repository = _BenchmarkRepository(fixture);
        final catalog = LibraryCatalogController(repository: repository);

        final refreshMicros = await _medianAsyncMicros(() async {
          await catalog.refresh();
        });
        var indexedDocuments = 0;
        final indexMicros = _medianSyncMicros(() {
          indexedDocuments = _searchDocuments(catalog.albums).length;
        });
        final documents = _searchDocuments(catalog.albums);
        final searchRequest = LibrarySearchRequest(
          documents: documents,
          query: 'ambient artist 42',
          field: LibrarySearchField.all,
          sort: LibrarySearchSort.relevance,
        );
        var measuredSearchResults = 0;
        final searchMicros = await _medianAsyncMicros(() async {
          final ids = await compute(searchLibraryDocuments, searchRequest);
          measuredSearchResults = ids.length;
        });
        final resultIds = searchLibraryDocuments(searchRequest);
        final metrics = {
          'tracks': trackCount,
          'albums': fixture.albums.length,
          'lyricTracks': fixture.lyricsByTrackId.length,
          'catalogRefreshP50Ms': _milliseconds(refreshMicros),
          'searchIndexP50Ms': _milliseconds(indexMicros),
          'indexedDocuments': indexedDocuments,
          'backgroundSearchP50Ms': _milliseconds(searchMicros),
          'searchResults': resultIds.length,
          'processRssMiB': double.parse(
            (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(1),
          ),
        };

        stdout.writeln('SOUND_PERF ${jsonEncode(metrics)}');

        expect(catalog.tracks, hasLength(trackCount));
        expect(repository.allLyricsCalls, greaterThan(0));
        expect(repository.singleTrackLyricCalls, 0);
        expect(indexedDocuments, trackCount);
        expect(resultIds, isNotEmpty);
        expect(measuredSearchResults, resultIds.length);
        expect(
          refreshMicros,
          lessThan(trackCount == 10000 ? 50000 : 15000),
          reason: 'Synthetic catalog refresh exceeded the fixed-device budget.',
        );
        expect(
          indexMicros,
          lessThan(trackCount == 10000 ? 80000 : 15000),
          reason: 'Search indexing exceeded the fixed-device budget.',
        );
        expect(
          searchMicros,
          lessThan(trackCount == 10000 ? 15000 : 5000),
          reason: 'Background search exceeded the fixed-device budget.',
        );

        catalog.dispose();
        await Future<void>.delayed(Duration.zero);
        await repository.close();
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}

class _LibraryFixture {
  const _LibraryFixture({
    required this.source,
    required this.albums,
    required this.tracks,
    required this.lyricsByTrackId,
  });

  factory _LibraryFixture.generate(int trackCount) {
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
          artworkKey: 'file:///benchmark/art-$albumIndex.jpg',
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
          artworkKey: 'file:///benchmark/art-$albumIndex.jpg',
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

    return _LibraryFixture(
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
}

class _BenchmarkRepository extends DriftLibraryRepository {
  _BenchmarkRepository(this.fixture)
    : super(LibraryDatabase(NativeDatabase.memory()));

  final _LibraryFixture fixture;
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

List<LibrarySearchDocument> _searchDocuments(List<Album> albums) {
  return [
    for (final album in albums)
      for (final track in album.tracks)
        LibrarySearchDocument(
          trackId: track.id,
          title: track.title,
          trackArtist: track.artist,
          albumTitle: album.title,
          albumArtist: album.artist,
          genre: track.genre ?? album.genre ?? '',
        ),
  ];
}

int _medianSyncMicros(void Function() operation) {
  operation();
  final samples = <int>[];
  for (var iteration = 0; iteration < 7; iteration++) {
    final stopwatch = Stopwatch()..start();
    operation();
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds);
  }
  samples.sort();
  return samples[samples.length ~/ 2];
}

Future<int> _medianAsyncMicros(Future<void> Function() operation) async {
  await operation();
  final samples = <int>[];
  for (var iteration = 0; iteration < 5; iteration++) {
    final stopwatch = Stopwatch()..start();
    await operation();
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds);
  }
  samples.sort();
  return samples[samples.length ~/ 2];
}

double _milliseconds(int microseconds) {
  return double.parse((microseconds / 1000).toStringAsFixed(2));
}
