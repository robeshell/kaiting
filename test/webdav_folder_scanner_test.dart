import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/library/persistence/drift_library_repository.dart';
import 'package:kaiting/library/persistence/library_database.dart';
import 'package:kaiting/library/scanning/artwork_store.dart';
import 'package:kaiting/library/scanning/audio_metadata_extractor.dart';
import 'package:kaiting/library/scanning/scan_cancellation.dart';
import 'package:kaiting/sources/webdav/webdav_connection_service.dart';
import 'package:kaiting/sources/webdav/webdav_credentials.dart';
import 'package:kaiting/sources/webdav/webdav_discovery.dart';
import 'package:kaiting/sources/webdav/webdav_folder_scanner.dart';

import '../tool/webdav_fixture_server.dart';

void main() {
  late Directory root;
  late WebDavFixtureServer server;
  late DriftLibraryRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sound-webdav-scan-test-');
    final music = Directory('${root.path}/dav/music');
    await music.create(recursive: true);
    await File('${music.path}/notes.txt').writeAsString('not audio');
    server = await WebDavFixtureServer.start(
      root: root,
      username: 'sound',
      password: 'sound-test',
    );
    repository = DriftLibraryRepository(
      LibraryDatabase(NativeDatabase.memory()),
    );
  });

  tearDown(() async {
    await repository.close();
    await server.close();
    await root.delete(recursive: true);
  });

  test(
    'resolves server-root hrefs without duplicating the connection path',
    () async {
      final baseUrl = 'http://127.0.0.1:${server.port}/dav/';
      final connectionId = WebDavConnectionService.stableWebDavConnectionId(
        baseUrl,
      );
      final createdAt = DateTime.utc(2025, 1, 1);
      await repository.upsertSource(
        LibrarySourceRecord(
          id: connectionId,
          type: LibrarySourceType.webDav,
          displayName: 'Fixture',
          rootUri: baseUrl,
          status: LibrarySourceStatus.available,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      final scanner = WebDavFolderScanner(repository: repository);
      const credentials = WebDavCredentials(
        username: 'sound',
        password: 'sound-test',
      );

      await scanner.scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: credentials,
      );
      final folderId = WebDavConnectionService.stableWebDavFolderSourceId(
        connectionId,
        '/dav/music/',
      );
      final firstCreatedAt = (await repository.getSource(folderId))?.createdAt;
      await scanner.scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: credentials,
      );

      final folder = await repository.getSource(folderId);
      expect(folder, isNotNull);
      expect(folder?.rootUri, '/dav/music/');
      expect(folder?.status, LibrarySourceStatus.available);
      expect(folder?.scanRevision, 2);
      expect(folder?.createdAt, firstCreatedAt);
      expect(await repository.getTracks(sourceId: folderId), isEmpty);

      final service = WebDavConnectionService(
        repository: repository,
        credentialStore: MemoryWebDavCredentialStore(),
      );
      expect(await service.listConnections(), hasLength(1));
    },
  );

  test('ignores macOS AppleDouble sidecars exposed by WebDAV', () async {
    final music = Directory('${root.path}/dav/music');
    await File('${music.path}/Track.mp3').writeAsBytes(<int>[1, 2, 3, 4]);
    // Some NAS products rewrite hrefs to an opaque playable-looking URL and
    // preserve the AppleDouble name only in the WebDAV displayname property.
    await File(
      '${music.path}/sidecar-download.mp3',
    ).writeAsBytes(<int>[5, 6, 7, 8]);
    await File(
      '${music.path}/metadata-header.mp3',
    ).writeAsBytes(<int>[0x00, 0x05, 0x16, 0x07, 0x00, 0x02, 0x00, 0x00]);

    final baseUrl = 'http://127.0.0.1:${server.port}/dav/';
    final connectionId = WebDavConnectionService.stableWebDavConnectionId(
      baseUrl,
    );
    final now = DateTime.utc(2026, 7, 18);
    await repository.upsertSource(
      LibrarySourceRecord(
        id: connectionId,
        type: LibrarySourceType.webDav,
        displayName: 'Fixture',
        rootUri: baseUrl,
        status: LibrarySourceStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final result =
        await WebDavFolderScanner(
          repository: repository,
          metadataExtractor: const _AlwaysFailingMetadataExtractor(),
          discovery: _DisplayNameDiscovery(<String, String>{
            'http://127.0.0.1:${server.port}/dav/music/Track.mp3':
                '100% Track.mp3',
            'http://127.0.0.1:${server.port}/dav/music/sidecar-download.mp3':
                '._Track.mp3',
            'http://127.0.0.1:${server.port}/dav/music/metadata-header.mp3':
                'innocent-looking.mp3',
          }),
        ).scan(
          connectionId: connectionId,
          folderUrls: const <String>['/dav/music/'],
          baseUrl: baseUrl,
          credentials: const WebDavCredentials(
            username: 'sound',
            password: 'sound-test',
          ),
        );

    final folderId = WebDavConnectionService.stableWebDavFolderSourceId(
      connectionId,
      '/dav/music/',
    );
    final tracks = await repository.getTracks(sourceId: folderId);
    expect(result.indexedTracks, 1);
    expect(result.skippedFiles, 1);
    expect(tracks, hasLength(1));
    expect(tracks.single.title, '100% Track');
    expect(tracks.single.mediaUri, endsWith('/Track.mp3'));
  });

  test(
    'rescans a legacy folder ID without creating a conflicting source',
    () async {
      final baseUrl = 'http://127.0.0.1:${server.port}/dav/';
      final connectionId = WebDavConnectionService.stableWebDavConnectionId(
        baseUrl,
      );
      final createdAt = DateTime.utc(2025, 1, 1);
      await repository.upsertSource(
        LibrarySourceRecord(
          id: connectionId,
          type: LibrarySourceType.webDav,
          displayName: 'Fixture',
          rootUri: baseUrl,
          status: LibrarySourceStatus.available,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      const legacyFolderId = 'webdav-folder:legacy-random-id';
      await repository.upsertSource(
        LibrarySourceRecord(
          id: legacyFolderId,
          type: LibrarySourceType.webDav,
          displayName: 'Legacy Music',
          rootUri: '/dav/music/',
          status: LibrarySourceStatus.available,
          scanRevision: 4,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      await WebDavFolderScanner(repository: repository).scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: const WebDavCredentials(
          username: 'sound',
          password: 'sound-test',
        ),
        existingSourceId: legacyFolderId,
      );

      final legacyFolder = await repository.getSource(legacyFolderId);
      final generatedId = WebDavConnectionService.stableWebDavFolderSourceId(
        connectionId,
        '/dav/music/',
      );
      expect(legacyFolder?.status, LibrarySourceStatus.available);
      expect(legacyFolder?.scanRevision, 5);
      expect(await repository.getSource(generatedId), isNull);
    },
  );

  test('extracts and persists embedded WebDAV album artwork', () async {
    final music = Directory('${root.path}/dav/music');
    final fixture = base64Decode(_mp3ArtworkFixture);
    final firstArtist = _replaceAscii(
      fixture,
      'Fixture Artist',
      'Fixture/AlphaX',
    );
    final secondArtist = _replaceAscii(
      fixture,
      'Fixture Artist',
      'Fixture/BetaXY',
    );
    await File(
      '${music.path}/01-no-cover.mp3',
    ).writeAsBytes(_withoutRecognizedArtwork(firstArtist));
    await File('${music.path}/02-cover.mp3').writeAsBytes(secondArtist);
    final artworkRoot = Directory('${root.path}/artwork');
    final baseUrl = 'http://127.0.0.1:${server.port}/dav/';
    final connectionId = WebDavConnectionService.stableWebDavConnectionId(
      baseUrl,
    );
    final now = DateTime.utc(2026, 7, 13);
    await repository.upsertSource(
      LibrarySourceRecord(
        id: connectionId,
        type: LibrarySourceType.webDav,
        displayName: 'Fixture',
        rootUri: baseUrl,
        status: LibrarySourceStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final scanner = WebDavFolderScanner(
      repository: repository,
      artworkStore: FileArtworkStore(rootDirectory: () async => artworkRoot),
      discovery: _FileListDiscovery([
        'http://127.0.0.1:${server.port}/dav/music/01-no-cover.mp3',
        'http://127.0.0.1:${server.port}/dav/music/02-cover.mp3',
      ]),
    );

    final result = await scanner.scan(
      connectionId: connectionId,
      folderUrls: const ['/dav/music/'],
      baseUrl: baseUrl,
      credentials: const WebDavCredentials(
        username: 'sound',
        password: 'sound-test',
      ),
    );

    final folderId = WebDavConnectionService.stableWebDavFolderSourceId(
      connectionId,
      '/dav/music/',
    );
    final albums = await repository.getAlbums(sourceId: folderId);
    final tracks = await repository.getTracks(sourceId: folderId);
    expect(result.indexedTracks, 2);
    expect(albums, hasLength(1));
    expect(albums.single.albumArtist, 'Fixture');
    expect(tracks.map((track) => track.artistName).toSet(), {
      'Fixture/AlphaX',
      'Fixture/BetaXY',
    });
    expect(albums.single.artworkKey, isNotNull);
    final artworkFile = File(Uri.parse(albums.single.artworkKey!).toFilePath());
    expect(await artworkFile.exists(), isTrue);
    expect(await artworkFile.length(), greaterThan(0));
  });

  test('uses the same release grouping rules for WebDAV metadata', () async {
    final music = Directory('${root.path}/dav/music');
    final relativeFiles = [
      'Artist One/Greatest Hits/artist-one.mp3',
      'Artist Two/Greatest Hits/artist-two.mp3',
      'Main Artist/Complete Album/CD 1/disc-one.flac',
      'Main Artist/Complete Album/Disc 2/disc-two.flac',
      'Festival Collection/guest-one.mp3',
      'Festival Collection/guest-two.mp3',
    ];
    for (var index = 0; index < relativeFiles.length; index++) {
      final file = File('${music.path}/${relativeFiles[index]}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes([index + 1]);
    }
    final baseUrl = 'http://127.0.0.1:${server.port}/dav/';
    final connectionId = WebDavConnectionService.stableWebDavConnectionId(
      baseUrl,
    );
    final now = DateTime.utc(2026, 7, 13);
    await repository.upsertSource(
      LibrarySourceRecord(
        id: connectionId,
        type: LibrarySourceType.webDav,
        displayName: 'Fixture',
        rootUri: baseUrl,
        status: LibrarySourceStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final fileUrls = [
      for (final relative in relativeFiles)
        'http://127.0.0.1:${server.port}/dav/music/$relative',
    ];
    final scanner = WebDavFolderScanner(
      repository: repository,
      metadataExtractor: const _ByteMetadataExtractor({
        1: ExtractedAudioMetadata(
          title: 'One',
          artist: 'Artist One',
          album: 'Greatest Hits',
          albumArtist: 'Artist One',
          trackNumber: 1,
        ),
        2: ExtractedAudioMetadata(
          title: 'Two',
          artist: 'Artist Two',
          album: 'Greatest Hits',
          albumArtist: 'Artist Two',
          trackNumber: 1,
        ),
        3: ExtractedAudioMetadata(
          title: 'Disc One',
          artist: 'Main Artist',
          album: 'Complete Album',
          albumArtist: 'Main Artist',
          trackNumber: 1,
          discNumber: 1,
        ),
        4: ExtractedAudioMetadata(
          title: 'Disc Two',
          artist: 'Main Artist & Guest',
          album: 'Complete Album',
          albumArtist: 'Main Artist',
          trackNumber: 1,
          discNumber: 2,
        ),
        5: ExtractedAudioMetadata(
          title: 'Guest One',
          artist: 'Guest One',
          album: 'Festival Collection',
          albumArtist: 'Various Artists',
          isCompilation: true,
          trackNumber: 1,
        ),
        6: ExtractedAudioMetadata(
          title: 'Guest Two',
          artist: 'Guest Two',
          album: 'Festival Collection',
          albumArtist: 'Various Artists',
          isCompilation: true,
          trackNumber: 2,
        ),
      }),
      discovery: _FileListDiscovery(fileUrls),
    );

    final result = await scanner.scan(
      connectionId: connectionId,
      folderUrls: const ['/dav/music/'],
      baseUrl: baseUrl,
      credentials: const WebDavCredentials(
        username: 'sound',
        password: 'sound-test',
      ),
    );

    final folderId = WebDavConnectionService.stableWebDavFolderSourceId(
      connectionId,
      '/dav/music/',
    );
    final albums = await repository.getAlbums(sourceId: folderId);
    final tracks = await repository.getTracks(sourceId: folderId);
    expect(result.indexedTracks, 6);
    expect(albums, hasLength(4));
    expect(
      albums.where((album) => album.title == 'Greatest Hits'),
      hasLength(2),
    );
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

  test(
    'keeps metadata-unreadable MP3 files discoverable by filename',
    () async {
      final music = Directory('${root.path}/dav/music');
      await File('${music.path}/fallback.mp3').writeAsBytes([
        // An ID3 marker with deliberately incomplete tag data followed by an
        // MPEG frame signature. Header-only metadata readers may reject it,
        // while the scanner should still retain the remote playback URL.
        0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x7f, 0x7f, 0x7f, 0x7f,
        0xff, 0xfb, 0x90, 0x64,
        ...List<int>.filled(2048, 0),
      ]);
      final baseUrl = 'http://127.0.0.1:${server.port}/dav/';
      final connectionId = WebDavConnectionService.stableWebDavConnectionId(
        baseUrl,
      );
      final now = DateTime.utc(2026, 7, 12);
      await repository.upsertSource(
        LibrarySourceRecord(
          id: connectionId,
          type: LibrarySourceType.webDav,
          displayName: 'Fixture',
          rootUri: baseUrl,
          status: LibrarySourceStatus.available,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final scanner = WebDavFolderScanner(
        repository: repository,
        discovery: _SingleMp3Discovery(
          'http://127.0.0.1:${server.port}/dav/music/fallback.mp3',
        ),
      );

      final result = await scanner.scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: const WebDavCredentials(
          username: 'sound',
          password: 'sound-test',
        ),
      );

      final folderId = WebDavConnectionService.stableWebDavFolderSourceId(
        connectionId,
        '/dav/music/',
      );
      final tracks = await repository.getTracks(sourceId: folderId);
      expect(result.skippedFiles, 0);
      expect(result.indexedTracks, 1);
      expect(tracks, hasLength(1));
      expect(tracks.single.title, 'fallback');
      expect(tracks.single.artistName, '未知艺人');
      expect(tracks.single.albumTitle, '未知专辑');
      expect(tracks.single.durationMs, 0);
      expect(tracks.single.mediaUri, endsWith('/fallback.mp3'));
    },
  );

  test(
    'indexes supported hrefs when display names omit extensions and metadata fails',
    () async {
      final music = Directory('${root.path}/dav/music');
      const fileNames = <String>[
        'tail-metadata.m4a',
        'large-artwork.flac',
        'stream.ogg',
        'voice.opus',
        'recording.wav',
      ];
      for (final fileName in fileNames) {
        await File('${music.path}/$fileName').writeAsBytes(<int>[1, 2, 3, 4]);
      }

      final baseUrl = 'http://127.0.0.1:${server.port}/dav/';
      final connectionId = WebDavConnectionService.stableWebDavConnectionId(
        baseUrl,
      );
      final now = DateTime.utc(2026, 7, 16);
      await repository.upsertSource(
        LibrarySourceRecord(
          id: connectionId,
          type: LibrarySourceType.webDav,
          displayName: 'Fixture',
          rootUri: baseUrl,
          status: LibrarySourceStatus.available,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final files = <String, String>{
        for (var index = 0; index < fileNames.length; index++)
          'http://127.0.0.1:${server.port}/dav/music/${fileNames[index]}':
              'Remote track ${index + 1}',
      };
      final result =
          await WebDavFolderScanner(
            repository: repository,
            metadataExtractor: const _AlwaysFailingMetadataExtractor(),
            discovery: _DisplayNameDiscovery(files),
          ).scan(
            connectionId: connectionId,
            folderUrls: const <String>['/dav/music/'],
            baseUrl: baseUrl,
            credentials: const WebDavCredentials(
              username: 'sound',
              password: 'sound-test',
            ),
          );

      final folderId = WebDavConnectionService.stableWebDavFolderSourceId(
        connectionId,
        '/dav/music/',
      );
      final tracks = await repository.getTracks(sourceId: folderId);
      expect(result.indexedTracks, fileNames.length);
      expect(result.skippedFiles, 0);
      expect(tracks, hasLength(fileNames.length));
      expect(tracks.map((track) => track.title).toSet(), <String>{
        for (var index = 1; index <= fileNames.length; index++)
          'Remote track $index',
      });
      expect(tracks.every((track) => track.artistName == '未知艺人'), isTrue);
      expect(tracks.map((track) => track.contentType).toSet(), <String?>{
        'audio/mp4',
        'audio/flac',
        'audio/ogg',
        'audio/wav',
      });
    },
  );

  test('keeps valid raw AAC discoverable by filename', () async {
    final music = Directory('${root.path}/dav/music');
    await File(
      '${music.path}/raw-track.aac',
    ).writeAsBytes(<int>[0xff, 0xf1, 0x50, 0x80, 0x01, 0x7f, 0xfc]);
    final baseUrl = 'http://127.0.0.1:${server.port}/dav/';
    final connectionId = WebDavConnectionService.stableWebDavConnectionId(
      baseUrl,
    );
    final now = DateTime.utc(2026, 7, 15);
    await repository.upsertSource(
      LibrarySourceRecord(
        id: connectionId,
        type: LibrarySourceType.webDav,
        displayName: 'Fixture',
        rootUri: baseUrl,
        status: LibrarySourceStatus.available,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final result =
        await WebDavFolderScanner(
          repository: repository,
          metadataExtractor: const _AlwaysFailingMetadataExtractor(),
        ).scan(
          connectionId: connectionId,
          folderUrls: const <String>['/dav/music/'],
          baseUrl: baseUrl,
          credentials: const WebDavCredentials(
            username: 'sound',
            password: 'sound-test',
          ),
        );

    final folderId = WebDavConnectionService.stableWebDavFolderSourceId(
      connectionId,
      '/dav/music/',
    );
    final track = (await repository.getTracks(sourceId: folderId)).single;
    expect(result.indexedTracks, 1);
    expect(result.skippedFiles, 0);
    expect(track.title, 'raw-track');
    expect(track.artistName, '未知艺人');
    expect(track.contentType, 'audio/aac');
  });

  test(
    'incremental rescans skip unchanged metadata and preserve moved track IDs',
    () async {
      final music = Directory('${root.path}/dav/music');
      final first = File('${music.path}/first.mp3');
      final second = File('${music.path}/second.flac');
      await first.writeAsBytes([1]);
      await second.writeAsBytes([2, 2]);
      final firstModified = DateTime.utc(2026, 7, 14, 10);
      final secondModified = DateTime.utc(2026, 7, 14, 11);
      await first.setLastModified(firstModified);
      await second.setLastModified(secondModified);

      final baseUrl = 'http://127.0.0.1:${server.port}/dav/';
      final connectionId = WebDavConnectionService.stableWebDavConnectionId(
        baseUrl,
      );
      final now = DateTime.utc(2026, 7, 14, 9);
      await repository.upsertSource(
        LibrarySourceRecord(
          id: connectionId,
          type: LibrarySourceType.webDav,
          displayName: 'Fixture',
          rootUri: baseUrl,
          status: LibrarySourceStatus.available,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final extractor = _CountingByteMetadataExtractor({
        1: const ExtractedAudioMetadata(
          title: 'First',
          artist: 'Artist',
          album: 'Album',
          trackNumber: 1,
        ),
        2: const ExtractedAudioMetadata(
          title: 'Second',
          artist: 'Artist',
          album: 'Album',
          trackNumber: 2,
        ),
        3: const ExtractedAudioMetadata(
          title: 'First Updated',
          artist: 'Artist',
          album: 'Album',
          trackNumber: 1,
        ),
      });
      final scanner = WebDavFolderScanner(
        repository: repository,
        metadataExtractor: extractor,
      );
      const credentials = WebDavCredentials(
        username: 'sound',
        password: 'sound-test',
      );
      final folderId = WebDavConnectionService.stableWebDavFolderSourceId(
        connectionId,
        '/dav/music/',
      );

      final initial = await scanner.scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: credentials,
      );
      expect(initial.addedTracks, 2);
      expect(initial.unchangedTracks, 0);
      expect(extractor.calls, 2);

      final unchanged = await scanner.scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: credentials,
      );
      expect(unchanged.unchangedTracks, 2);
      expect(unchanged.addedTracks, 0);
      expect(extractor.calls, 2);

      await first.writeAsBytes([3, 3, 3]);
      await first.setLastModified(
        firstModified.add(const Duration(seconds: 1)),
      );
      final modified = await scanner.scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: credentials,
      );
      expect(modified.modifiedTracks, 1);
      expect(modified.unchangedTracks, 1);
      expect(extractor.calls, 3);
      expect(
        (await repository.getTracks(sourceId: folderId))
            .singleWhere((track) => track.relativePath.endsWith('first.mp3'))
            .title,
        'First Updated',
      );

      final beforeMove = (await repository.getTracks(
        sourceId: folderId,
      )).singleWhere((track) => track.title == 'Second');
      await repository.setTrackFavorite(
        beforeMove.id,
        favorite: true,
        changedAt: DateTime.utc(2026, 7, 14, 13),
      );
      final movedFile = await second.rename('${music.path}/moved.flac');
      await movedFile.setLastModified(secondModified);

      final moved = await scanner.scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: credentials,
      );
      expect(moved.movedTracks, 1);
      expect(moved.addedTracks, 0);
      expect(moved.removedTracks, 0);
      expect(extractor.calls, 4);
      final afterMove = (await repository.getTracks(
        sourceId: folderId,
      )).singleWhere((track) => track.title == 'Second');
      expect(afterMove.id, beforeMove.id);
      expect(afterMove.relativePath, endsWith('/moved.flac'));
      expect(
        (await repository.getFavoriteTracks()).single.trackId,
        beforeMove.id,
      );

      await first.delete();
      final removed = await scanner.scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: credentials,
      );
      expect(removed.removedTracks, 1);
      expect(removed.unchangedTracks, 1);
      expect(extractor.calls, 4);
      expect(await repository.getTracks(sourceId: folderId), hasLength(1));
    },
  );

  test(
    'cancelled and failed WebDAV rescans keep the previous snapshot',
    () async {
      final music = Directory('${root.path}/dav/music');
      final retained = File('${music.path}/retained.mp3');
      await retained.writeAsBytes([1]);
      final initialModified = DateTime.utc(2026, 7, 14, 10);
      await retained.setLastModified(initialModified);
      final baseUrl = 'http://127.0.0.1:${server.port}/dav/';
      final connectionId = WebDavConnectionService.stableWebDavConnectionId(
        baseUrl,
      );
      final now = DateTime.utc(2026, 7, 14, 9);
      await repository.upsertSource(
        LibrarySourceRecord(
          id: connectionId,
          type: LibrarySourceType.webDav,
          displayName: 'Fixture',
          rootUri: baseUrl,
          status: LibrarySourceStatus.available,
          createdAt: now,
          updatedAt: now,
        ),
      );
      const credentials = WebDavCredentials(
        username: 'sound',
        password: 'sound-test',
      );
      final initialScanner = WebDavFolderScanner(
        repository: repository,
        metadataExtractor: _CountingByteMetadataExtractor({
          1: const ExtractedAudioMetadata(
            title: 'Retained',
            artist: 'Artist',
            album: 'Album',
          ),
        }),
      );
      await initialScanner.scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: credentials,
      );
      final folderId = WebDavConnectionService.stableWebDavFolderSourceId(
        connectionId,
        '/dav/music/',
      );
      final beforeSource = await repository.getSource(folderId);
      final beforeTrack = (await repository.getTracks(
        sourceId: folderId,
      )).single;

      await retained.writeAsBytes([2, 2]);
      await retained.setLastModified(
        initialModified.add(const Duration(seconds: 1)),
      );
      final blockingExtractor = _BlockingByteMetadataExtractor(
        const ExtractedAudioMetadata(
          title: 'Should Not Commit',
          artist: 'Artist',
          album: 'Album',
        ),
      );
      final scanner = WebDavFolderScanner(
        repository: repository,
        metadataExtractor: blockingExtractor,
      );
      final scanFuture = scanner.scan(
        connectionId: connectionId,
        folderUrls: const ['/dav/music/'],
        baseUrl: baseUrl,
        credentials: credentials,
        existingSourceId: folderId,
      );

      await blockingExtractor.entered.future.timeout(
        const Duration(seconds: 5),
      );
      expect(scanner.isScanning(folderId), isTrue);
      expect(scanner.cancel(folderId), isTrue);
      blockingExtractor.release.complete();
      await expectLater(scanFuture, throwsA(isA<ScanCancelledException>()));

      final afterSource = await repository.getSource(folderId);
      final afterTrack = (await repository.getTracks(
        sourceId: folderId,
      )).single;
      expect(afterSource?.status, LibrarySourceStatus.available);
      expect(afterSource?.scanRevision, beforeSource?.scanRevision);
      expect(afterTrack.id, beforeTrack.id);
      expect(afterTrack.title, beforeTrack.title);
      expect(afterTrack.fileSize, beforeTrack.fileSize);
      expect(scanner.isScanning(folderId), isFalse);

      final failingScanner = WebDavFolderScanner(
        repository: repository,
        discovery: _FailingDiscovery(),
      );
      await expectLater(
        failingScanner.scan(
          connectionId: connectionId,
          folderUrls: const ['/dav/music/'],
          baseUrl: baseUrl,
          credentials: credentials,
          existingSourceId: folderId,
        ),
        throwsA(isA<StateError>()),
      );
      final failedSource = await repository.getSource(folderId);
      final trackAfterFailure = (await repository.getTracks(
        sourceId: folderId,
      )).single;
      expect(failedSource?.status, LibrarySourceStatus.error);
      expect(failedSource?.scanRevision, beforeSource?.scanRevision);
      expect(trackAfterFailure.id, beforeTrack.id);
      expect(trackAfterFailure.title, beforeTrack.title);
    },
  );
}

class _SingleMp3Discovery extends WebDavDiscoveryService {
  _SingleMp3Discovery(this.fileUrl);

  final String fileUrl;

  @override
  Future<WebDavDiscoveryResult> probe(
    String url, {
    required WebDavCredentials credentials,
  }) async {
    return WebDavDiscoveryResult(
      status: DiscoveryStatus.success,
      capabilities: const ['1'],
      files: [
        WebDavFileEntry(
          href: fileUrl,
          displayName: 'fallback.mp3',
          isCollection: false,
          contentLength: 2062,
        ),
      ],
    );
  }
}

class _FileListDiscovery extends WebDavDiscoveryService {
  _FileListDiscovery(this.fileUrls);

  final List<String> fileUrls;

  @override
  Future<WebDavDiscoveryResult> probe(
    String url, {
    required WebDavCredentials credentials,
  }) async {
    return WebDavDiscoveryResult(
      status: DiscoveryStatus.success,
      capabilities: const ['1'],
      files: [
        for (final fileUrl in fileUrls)
          WebDavFileEntry(
            href: fileUrl,
            displayName: Uri.parse(fileUrl).pathSegments.last,
            isCollection: false,
            contentLength: 762,
          ),
      ],
    );
  }
}

class _DisplayNameDiscovery extends WebDavDiscoveryService {
  _DisplayNameDiscovery(this.files);

  final Map<String, String> files;

  @override
  Future<WebDavDiscoveryResult> probe(
    String url, {
    required WebDavCredentials credentials,
  }) async {
    return WebDavDiscoveryResult(
      status: DiscoveryStatus.success,
      capabilities: const <String>['1'],
      files: [
        for (final entry in files.entries)
          WebDavFileEntry(
            href: entry.key,
            displayName: entry.value,
            isCollection: false,
            contentLength: 4,
          ),
      ],
    );
  }
}

class _FailingDiscovery extends WebDavDiscoveryService {
  @override
  Future<WebDavDiscoveryResult> probe(
    String url, {
    required WebDavCredentials credentials,
  }) async {
    return WebDavDiscoveryResult.error(
      WebDavConnectionError.unreachable,
      message: 'Fixture unavailable',
    );
  }
}

class _AlwaysFailingMetadataExtractor implements AudioMetadataExtractor {
  const _AlwaysFailingMetadataExtractor();

  @override
  Future<ExtractedAudioMetadata> extract(File file) {
    throw const FormatException('No metadata container.');
  }
}

class _ByteMetadataExtractor implements AudioMetadataExtractor {
  const _ByteMetadataExtractor(this.metadata);

  final Map<int, ExtractedAudioMetadata> metadata;

  @override
  Future<ExtractedAudioMetadata> extract(File file) async {
    final bytes = await file.readAsBytes();
    final value = bytes.isEmpty ? null : metadata[bytes.first];
    if (value == null) throw const FormatException('Unknown audio fixture.');
    return value;
  }
}

class _CountingByteMetadataExtractor implements AudioMetadataExtractor {
  _CountingByteMetadataExtractor(this.metadata);

  final Map<int, ExtractedAudioMetadata> metadata;
  int calls = 0;

  @override
  Future<ExtractedAudioMetadata> extract(File file) async {
    calls++;
    final bytes = await file.readAsBytes();
    final value = bytes.isEmpty ? null : metadata[bytes.first];
    if (value == null) throw const FormatException('Unknown audio fixture.');
    return value;
  }
}

class _BlockingByteMetadataExtractor implements AudioMetadataExtractor {
  _BlockingByteMetadataExtractor(this.metadata);

  final ExtractedAudioMetadata metadata;
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<ExtractedAudioMetadata> extract(File file) async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    return metadata;
  }
}

List<int> _withoutRecognizedArtwork(List<int> bytes) {
  final copy = List<int>.of(bytes);
  final marker = ascii.encode('APIC');
  for (var index = 0; index <= copy.length - marker.length; index++) {
    if (copy[index] == marker[0] &&
        copy[index + 1] == marker[1] &&
        copy[index + 2] == marker[2] &&
        copy[index + 3] == marker[3]) {
      copy[index] = 0x58;
      return copy;
    }
  }
  throw StateError('Fixture does not contain an APIC frame.');
}

List<int> _replaceAscii(List<int> bytes, String from, String to) {
  final source = ascii.encode(from);
  final replacement = ascii.encode(to);
  if (source.length != replacement.length) {
    throw ArgumentError('Replacement must preserve the fixture byte length.');
  }
  final copy = List<int>.of(bytes);
  for (var index = 0; index <= copy.length - source.length; index++) {
    var matches = true;
    for (var offset = 0; offset < source.length; offset++) {
      if (copy[index + offset] != source[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      copy.setRange(index, index + replacement.length, replacement);
      return copy;
    }
  }
  throw StateError('Fixture does not contain "$from".');
}

const _mp3ArtworkFixture =
    'SUQzBAAAAAACQFRJVDIAAAANAAADRml4dHVyZSBNUDMAVFBFMQAAABAAAANGaXh0dXJlIEFydGlzdABU'
    'QUxCAAAADwAAA0ZpeHR1cmUgQWxidW0AVFJDSwAAAAMAAAMyAFRQT1MAAAADAAADMQBURFJDAAAABgAA'
    'AzIwMjYAVENPTgAAAAYAAANUZXN0AFRYWFgAAAAaAAADVVNMVABbMDA6MDAuMDBdSGVsbG8gTVAzAFRT'
    'U0UAAAAPAAADTGF2ZjYyLjEyLjEwMABBUElDAAAAawAAA2ltYWdlL3BuZwAAAIlQTkcNChoKAAAADUlI'
    'RFIAAAACAAAAAggCAAAA/dSacwAAAAlwSFlzAAAAAQAAAAEATyXE1gAAABBJREFUeJxj/MMAAixgkgEA'
    'DQQBAr9QFbMAAAAASUVORK5CYIIAAAAAAAAAAAAA/+M4wAAAAAAAAAAAAEluZm8AAAAPAAAAAwAAAbAA'
    'qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV'
    '1dXV1dXV////////////////////////////////////////////AAAAAExhdmM2Mi4yOAAAAAAAAAAA'
    'AAAAACQC8AAAAAAAAAGw9wpEpwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAA/+MYxAAAAANIAAAAAExBTUUzLjEwMFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV'
    'VVVVVVVVVVVVVVVVVVVVVVVV/+MYxDsAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV'
    'VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV/+MYxHYAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVV'
    'VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV';
