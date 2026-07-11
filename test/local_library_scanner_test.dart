import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sound_player/library/library_records.dart';
import 'package:sound_player/library/persistence/drift_library_repository.dart';
import 'package:sound_player/library/persistence/library_database.dart';
import 'package:sound_player/library/scanning/artwork_store.dart';
import 'package:sound_player/library/scanning/audio_metadata_extractor.dart';
import 'package:sound_player/library/scanning/file_system_local_media_catalog.dart';
import 'package:sound_player/library/scanning/local_library_scanner.dart';

void main() {
  test(
    'indexes metadata, skips damaged files, and atomically removes stale rows',
    () async {
      final directory = await Directory.systemTemp.createTemp('sound-scan-');
      addTearDown(() => directory.delete(recursive: true));
      final music = Directory(path.join(directory.path, 'Music'));
      await Directory(path.join(music.path, 'nested')).create(recursive: true);
      final first = File(path.join(music.path, 'first.mp3'));
      final second = File(path.join(music.path, 'nested', 'second.flac'));
      final damaged = File(path.join(music.path, 'damaged.mp3'));
      await first.writeAsBytes([1]);
      await second.writeAsBytes([2]);
      await damaged.writeAsBytes([3]);

      final repository = DriftLibraryRepository(
        LibraryDatabase(
          NativeDatabase(File(path.join(directory.path, 'library.sqlite'))),
        ),
      );
      addTearDown(repository.close);
      final now = DateTime.utc(2026, 7, 11, 12);
      final source = _source(music.uri.toString(), now);
      await repository.upsertSource(source);
      final extractor = _FakeMetadataExtractor({
        'first.mp3': ExtractedAudioMetadata(
          title: 'First',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(seconds: 10),
          trackNumber: 1,
          year: 2026,
          genre: 'Test',
          lyrics: '[00:01.00]Line',
          artwork: ExtractedArtwork(
            bytes: Uint8List.fromList([1, 2, 3]),
            mimeType: 'image/png',
          ),
        ),
        'second.flac': const ExtractedAudioMetadata(
          title: 'Second',
          artist: 'Artist',
          album: 'Album',
          duration: Duration(seconds: 20),
          trackNumber: 2,
        ),
      });
      final scanner = LocalLibraryScanner(
        repository: repository,
        catalog: FileSystemLocalMediaCatalog(),
        metadataExtractor: extractor,
        artworkStore: const _FakeArtworkStore(),
        clock: () => now,
      );

      final firstReport = await scanner.scan(source);

      expect(firstReport.discoveredFiles, 3);
      expect(firstReport.indexedTracks, 2);
      expect(firstReport.skippedFiles, 1);
      expect(firstReport.warnings.single, contains('damaged.mp3'));
      var tracks = await repository.getTracks(sourceId: source.id);
      expect(tracks.map((track) => track.title), ['First', 'Second']);
      expect(tracks.first.artworkKey, startsWith('artwork://'));
      expect(await repository.getLyrics(tracks.first.id), hasLength(1));
      expect((await repository.getSource(source.id))?.scanRevision, 1);

      await first.delete();
      await damaged.delete();
      final secondReport = await scanner.scan(source);

      expect(secondReport.discoveredFiles, 1);
      expect(secondReport.indexedTracks, 1);
      tracks = await repository.getTracks(sourceId: source.id);
      expect(tracks.single.title, 'Second');
      expect(await repository.getAlbums(sourceId: source.id), hasLength(1));
      expect(await repository.getArtists(sourceId: source.id), hasLength(1));
      expect((await repository.getSource(source.id))?.scanRevision, 2);
    },
  );
}

LibrarySourceRecord _source(String rootUri, DateTime now) {
  return LibrarySourceRecord(
    id: 'local:test',
    type: LibrarySourceType.local,
    displayName: 'Music',
    rootUri: rootUri,
    status: LibrarySourceStatus.available,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeMetadataExtractor implements AudioMetadataExtractor {
  const _FakeMetadataExtractor(this.metadata);

  final Map<String, ExtractedAudioMetadata> metadata;

  @override
  Future<ExtractedAudioMetadata> extract(File file) async {
    final value = metadata[path.basename(file.path)];
    if (value == null) throw const FormatException('Damaged audio fixture.');
    return value;
  }
}

class _FakeArtworkStore implements ArtworkStore {
  const _FakeArtworkStore();

  @override
  Future<String?> store({
    required String albumId,
    required List<int> bytes,
    required String mimeType,
  }) async {
    return 'artwork://${Uri.encodeComponent(albumId)}';
  }
}
