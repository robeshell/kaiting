import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/presentation/controllers/library_catalog_controller.dart';
import 'package:sound_player/presentation/controllers/library_search_controller.dart';

import 'support/library_benchmark_fixture.dart';

void main() {
  for (final trackCount in const [1000, 10000]) {
    test(
      'library pipeline baseline with $trackCount tracks',
      () async {
        final fixture = LibraryBenchmarkFixture.generate(trackCount);
        final repository = BenchmarkLibraryRepository(fixture);
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
