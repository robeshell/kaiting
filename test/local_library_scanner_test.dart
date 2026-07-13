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
          artist: 'Artist/Guest',
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
      expect(tracks.map((track) => track.artistName), [
        'Artist',
        'Artist/Guest',
      ]);
      final firstAlbums = await repository.getAlbums(sourceId: source.id);
      expect(firstAlbums, hasLength(1));
      expect(firstAlbums.single.albumArtist, 'Artist');
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

  test('groups multi-disc, compilation, and same-title releases', () async {
    final directory = await Directory.systemTemp.createTemp('sound-groups-');
    addTearDown(() => directory.delete(recursive: true));
    final music = Directory(path.join(directory.path, 'Music'));
    final relativeFiles = [
      'Artist One/Greatest Hits/artist-one.mp3',
      'Artist Two/Greatest Hits/artist-two.mp3',
      'Main Artist/Complete Album/CD 1/disc-one.flac',
      'Main Artist/Complete Album/Disc 2/disc-two.flac',
      'Festival Collection/guest-one.mp3',
      'Festival Collection/guest-two.mp3',
    ];
    for (var index = 0; index < relativeFiles.length; index++) {
      final file = File(path.join(music.path, relativeFiles[index]));
      await file.parent.create(recursive: true);
      await file.writeAsBytes([index + 1]);
    }

    final repository = DriftLibraryRepository(
      LibraryDatabase(NativeDatabase.memory()),
    );
    addTearDown(repository.close);
    final now = DateTime.utc(2026, 7, 13);
    final source = _source(music.uri.toString(), now);
    await repository.upsertSource(source);
    final scanner = LocalLibraryScanner(
      repository: repository,
      catalog: FileSystemLocalMediaCatalog(),
      metadataExtractor: const _FakeMetadataExtractor({
        'artist-one.mp3': ExtractedAudioMetadata(
          title: 'One',
          artist: 'Artist One',
          album: 'Greatest Hits',
          albumArtist: 'Artist One',
          trackNumber: 1,
        ),
        'artist-two.mp3': ExtractedAudioMetadata(
          title: 'Two',
          artist: 'Artist Two',
          album: 'Greatest Hits',
          albumArtist: 'Artist Two',
          trackNumber: 1,
        ),
        'disc-one.flac': ExtractedAudioMetadata(
          title: 'Disc One',
          artist: 'Main Artist',
          album: 'Complete Album',
          albumArtist: 'Main Artist',
          trackNumber: 1,
          discNumber: 1,
        ),
        'disc-two.flac': ExtractedAudioMetadata(
          title: 'Disc Two',
          artist: 'Main Artist & Guest',
          album: 'Complete Album',
          albumArtist: 'Main Artist',
          trackNumber: 1,
          discNumber: 2,
        ),
        'guest-one.mp3': ExtractedAudioMetadata(
          title: 'Guest One',
          artist: 'Guest One',
          album: 'Festival Collection',
          albumArtist: 'Various Artists',
          isCompilation: true,
          trackNumber: 1,
        ),
        'guest-two.mp3': ExtractedAudioMetadata(
          title: 'Guest Two',
          artist: 'Guest Two',
          album: 'Festival Collection',
          albumArtist: 'Various Artists',
          isCompilation: true,
          trackNumber: 2,
        ),
      }),
      clock: () => now,
    );

    final report = await scanner.scan(source);
    final albums = await repository.getAlbums(sourceId: source.id);
    final tracks = await repository.getTracks(sourceId: source.id);

    expect(report.indexedTracks, 6);
    expect(albums, hasLength(4));
    final greatestHits = albums
        .where((album) => album.title == 'Greatest Hits')
        .toList();
    expect(greatestHits, hasLength(2));
    expect(greatestHits.map((album) => album.albumArtist).toSet(), {
      'Artist One',
      'Artist Two',
    });
    final multiDisc = albums.singleWhere(
      (album) => album.title == 'Complete Album',
    );
    expect(
      tracks
          .where((track) => track.albumId == multiDisc.id)
          .map((track) => track.discNumber),
      [1, 2],
    );
    expect(
      albums
          .singleWhere((album) => album.title == 'Festival Collection')
          .albumArtist,
      'Various Artists',
    );
  });
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
