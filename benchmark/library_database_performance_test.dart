import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/library/library_records.dart';
import 'package:sound_player/library/persistence/drift_library_repository.dart';
import 'package:sound_player/library/persistence/library_database.dart';
import 'package:sound_player/presentation/controllers/library_catalog_controller.dart';

import 'support/library_benchmark_fixture.dart';

void main() {
  for (final trackCount in const [1000, 10000]) {
    test(
      'SQLite file baseline with $trackCount tracks',
      () async {
        final fixture = LibraryBenchmarkFixture.generate(trackCount);
        final directory = await Directory.systemTemp.createTemp(
          'sound-db-benchmark-$trackCount-',
        );
        final file = File('${directory.path}/library.sqlite');

        var repository = _openRepository(file);
        await repository.upsertSource(fixture.source);

        final initialScanMicros = await _measureAsyncMicros(
          () => repository.replaceSourceScan(
            fixture.scanBatch(DateTime.utc(2026, 7, 13, 12)),
          ),
        );
        final repeatScanMicros = await _measureAsyncMicros(
          () => repository.replaceSourceScan(
            fixture.scanBatch(DateTime.utc(2026, 7, 13, 12, 1)),
          ),
        );
        await repository.close();

        final databaseBytes = await _databaseFootprint(directory);
        repository = _openRepository(file);

        late final List<LibrarySourceRecord> sources;
        final openAndSourcesMicros = await _measureAsyncMicros(() async {
          sources = await repository.getSources();
        });
        late final List<LibraryAlbumRecord> albums;
        final albumsMicros = await _measureAsyncMicros(() async {
          albums = await repository.getAlbums();
        });
        late final List<LibraryTrackRecord> tracks;
        final tracksMicros = await _measureAsyncMicros(() async {
          tracks = await repository.getTracks();
        });
        late final Map<String, List<LibraryLyricRecord>> lyricsByTrackId;
        final lyricsMicros = await _measureAsyncMicros(() async {
          lyricsByTrackId = await repository.getAllLyrics();
        });
        late final List<Album> mappedAlbums;
        final mappingMicros = _measureSyncMicros(() {
          mappedAlbums = mapLibraryAlbums(
            sources: sources,
            albums: albums,
            tracks: tracks,
            lyricsByTrackId: lyricsByTrackId,
          );
        });

        final metrics = {
          'tracks': trackCount,
          'albums': fixture.albums.length,
          'lyricLines': fixture.lyrics.length,
          'initialScanMs': _milliseconds(initialScanMicros),
          'repeatScanMs': _milliseconds(repeatScanMicros),
          'openAndSourcesMs': _milliseconds(openAndSourcesMicros),
          'readAlbumsMs': _milliseconds(albumsMicros),
          'readTracksMs': _milliseconds(tracksMicros),
          'readLyricsMs': _milliseconds(lyricsMicros),
          'mapModelsMs': _milliseconds(mappingMicros),
          'databaseMiB': double.parse(
            (databaseBytes / 1024 / 1024).toStringAsFixed(2),
          ),
          'processRssMiB': double.parse(
            (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(1),
          ),
        };
        stdout.writeln('SOUND_DB_PERF ${jsonEncode(metrics)}');

        expect(sources, hasLength(1));
        expect(albums, hasLength(fixture.albums.length));
        expect(tracks, hasLength(trackCount));
        expect(
          lyricsByTrackId.values.fold<int>(
            0,
            (total, lines) => total + lines.length,
          ),
          fixture.lyrics.length,
        );
        expect(mappedAlbums, hasLength(fixture.albums.length));
        expect(
          mappedAlbums.fold<int>(
            0,
            (total, album) => total + album.tracks.length,
          ),
          trackCount,
        );

        final scanBudget = trackCount == 10000
            ? const Duration(milliseconds: 750)
            : const Duration(milliseconds: 250);
        expect(initialScanMicros, lessThan(scanBudget.inMicroseconds));
        expect(repeatScanMicros, lessThan(scanBudget.inMicroseconds));
        expect(
          openAndSourcesMicros +
              albumsMicros +
              tracksMicros +
              lyricsMicros +
              mappingMicros,
          lessThan(
            trackCount == 10000
                ? const Duration(seconds: 2).inMicroseconds
                : const Duration(milliseconds: 500).inMicroseconds,
          ),
        );

        await repository.close();
        await directory.delete(recursive: true);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }
}

DriftLibraryRepository _openRepository(File file) {
  return DriftLibraryRepository(
    LibraryDatabase(NativeDatabase(file, logStatements: false)),
  );
}

Future<int> _databaseFootprint(Directory directory) async {
  var bytes = 0;
  await for (final entity in directory.list()) {
    if (entity is File) bytes += await entity.length();
  }
  return bytes;
}

Future<int> _measureAsyncMicros(Future<void> Function() operation) async {
  final stopwatch = Stopwatch()..start();
  await operation();
  stopwatch.stop();
  return stopwatch.elapsedMicroseconds;
}

int _measureSyncMicros(void Function() operation) {
  final stopwatch = Stopwatch()..start();
  operation();
  stopwatch.stop();
  return stopwatch.elapsedMicroseconds;
}

double _milliseconds(int microseconds) {
  return double.parse((microseconds / 1000).toStringAsFixed(2));
}
