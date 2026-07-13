import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sound_player/library/library_records.dart';
import 'package:sound_player/library/library_repository.dart';
import 'package:sound_player/sources/webdav/webdav_connection_service.dart';
import 'package:sound_player/sources/webdav/webdav_credentials.dart';
import 'package:sound_player/sources/webdav/webdav_discovery.dart';

import '../tool/webdav_fixture_server.dart';

void main() {
  // ---------------------------------------------------------------------------
  // WebDavCredentials
  // ---------------------------------------------------------------------------
  group('WebDavCredentials', () {
    test('JSON round-trip preserves Unicode credentials', () {
      final credentials = WebDavCredentials(
        username: 'user@domain',
        password: 'pässwörd!@#',
      );

      final decoded = WebDavCredentials.fromJson(credentials.toJson());

      expect(decoded, isNotNull);
      expect(decoded!.username, 'user@domain');
      expect(decoded.password, 'pässwörd!@#');
    });

    test('invalid JSON values are rejected', () {
      expect(WebDavCredentials.fromJson(null), isNull);
      expect(WebDavCredentials.fromJson(''), isNull);
      expect(WebDavCredentials.fromJson('bad data'), isNull);
      expect(WebDavCredentials.fromJson('{"username": 1}'), isNull);
    });

    test('basicHeaderValue produces correct Basic auth header', () {
      final credentials = WebDavCredentials(username: 'test', password: 'pass');
      final expected = 'Basic ${base64Encode(utf8.encode('test:pass'))}';
      expect(credentials.basicHeaderValue, expected);
    });

    test('memory credential store supports write, read, and delete', () async {
      final store = MemoryWebDavCredentialStore();
      const credentials = WebDavCredentials(username: 'alice', password: 'pw');

      await store.write('connection', credentials);
      final stored = await store.read('connection');
      expect(stored?.username, 'alice');
      expect(stored?.password, 'pw');

      await store.delete('connection');
      expect(await store.read('connection'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // WebDavConnectionService CRUD
  // ---------------------------------------------------------------------------
  group('WebDavConnectionService', () {
    late FakeLibraryRepository repository;
    late FakeWebDavDiscoveryService fakeDiscovery;
    late MemoryWebDavCredentialStore credentialStore;
    late WebDavConnectionService service;

    setUp(() {
      repository = FakeLibraryRepository();
      fakeDiscovery = FakeWebDavDiscoveryService();
      credentialStore = MemoryWebDavCredentialStore();
      service = WebDavConnectionService(
        repository: repository,
        discovery: fakeDiscovery,
        credentialStore: credentialStore,
      );
    });

    test('listConnections returns empty when no connections exist', () async {
      final connections = await service.listConnections();
      expect(connections, isEmpty);
    });

    test('addConnection persists and returns discovery result', () async {
      fakeDiscovery._nextResult = WebDavDiscoveryResult(
        status: DiscoveryStatus.success,
        capabilities: ['1'],
        files: [
          WebDavFileEntry(
            href: '/music',
            displayName: 'music',
            isCollection: true,
            contentLength: 0,
          ),
        ],
      );

      final result = await service.addConnection(
        url: 'https://nas.local/dav',
        displayName: 'My NAS',
        credentials: const WebDavCredentials(
          username: 'user',
          password: 'pass',
        ),
      );

      expect(result.status, DiscoveryStatus.success);
      expect(result.files, hasLength(1));

      final connections = await service.listConnections();
      expect(connections, hasLength(1));
      expect(connections.first.url, 'https://nas.local/dav/');
      expect(connections.first.displayName, 'My NAS');
      expect(connections.first.status, WebDavConnectionStatus.connected);
      final source = await repository.getSource(connections.first.id);
      expect(source?.permissionBookmark, isNull);
      final stored = await credentialStore.read(connections.first.id);
      expect(stored?.username, 'user');
      expect(stored?.password, 'pass');
    });

    test('addConnection records error status when discovery fails', () async {
      fakeDiscovery._nextResult = WebDavDiscoveryResult.error(
        WebDavConnectionError.authenticationFailed,
        message: 'Bad credentials',
      );

      final result = await service.addConnection(
        url: 'https://nas.local/dav',
        displayName: 'Bad NAS',
        credentials: const WebDavCredentials(
          username: 'wrong',
          password: 'wrong',
        ),
      );

      expect(result.error, WebDavConnectionError.authenticationFailed);

      final connections = await service.listConnections();
      expect(
        connections.first.status,
        WebDavConnectionStatus.authenticationFailed,
      );
    });

    test('removeConnection deletes the source', () async {
      fakeDiscovery._nextResult = WebDavDiscoveryResult(
        status: DiscoveryStatus.success,
      );

      await service.addConnection(
        url: 'https://nas.local/dav',
        displayName: 'Temp',
        credentials: const WebDavCredentials(username: 'x', password: 'y'),
      );
      final connections = await service.listConnections();
      final id = connections.first.id;
      await service.removeConnection(connections.first.id);

      expect(await service.listConnections(), isEmpty);
      expect(await credentialStore.read(id), isNull);
    });

    test(
      'folder sources stay out of connections and cascade on removal',
      () async {
        await service.addConnection(
          url: 'https://nas.local/dav',
          displayName: 'NAS',
          credentials: const WebDavCredentials(username: 'u', password: 'p'),
        );
        final connection = (await service.listConnections()).single;
        final folderId = WebDavConnectionService.stableWebDavFolderSourceId(
          connection.id,
          '/dav/music/',
        );
        final now = DateTime.utc(2025, 1, 1);
        await repository.upsertSource(
          LibrarySourceRecord(
            id: folderId,
            type: LibrarySourceType.webDav,
            displayName: 'Music',
            rootUri: '/dav/music/',
            status: LibrarySourceStatus.available,
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(await service.listConnections(), hasLength(1));
        expect(
          WebDavConnectionService.isFolderSourceForConnection(
            folderId,
            connection.id,
          ),
          isTrue,
        );

        await service.removeConnection(connection.id);
        expect(await repository.getSource(connection.id), isNull);
        expect(await repository.getSource(folderId), isNull);
      },
    );

    test('resolves legacy random folder IDs with one connection', () async {
      await service.addConnection(
        url: 'https://nas.local/dav',
        displayName: 'NAS',
        credentials: const WebDavCredentials(username: 'u', password: 'p'),
      );
      final now = DateTime.utc(2025, 1, 1);
      const legacyFolder = WebDavConnectionRecord(
        id: 'webdav-folder:legacy-random-id',
        url: '/dav/music/',
        displayName: 'Music',
        status: WebDavConnectionStatus.connected,
        allowBadCertificate: false,
      );
      await repository.upsertSource(
        LibrarySourceRecord(
          id: legacyFolder.id,
          type: LibrarySourceType.webDav,
          displayName: legacyFolder.displayName,
          rootUri: legacyFolder.url,
          status: LibrarySourceStatus.available,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final parent = await service.resolveParentConnection(legacyFolder);

      expect(parent, isNotNull);
      expect(parent?.displayName, 'NAS');
    });

    test('updateConnection keeps identity and scan metadata', () async {
      final createdAt = DateTime.utc(2025, 1, 1);
      final scanStartedAt = DateTime.utc(2025, 2, 1);
      final scanCompletedAt = DateTime.utc(2025, 2, 2);
      const id = 'webdav:existing';
      await repository.upsertSource(
        LibrarySourceRecord(
          id: id,
          type: LibrarySourceType.webDav,
          displayName: 'Old NAS',
          rootUri: 'https://nas.local/Old/',
          status: LibrarySourceStatus.available,
          scanRevision: 7,
          lastScanStartedAt: scanStartedAt,
          lastScanCompletedAt: scanCompletedAt,
          createdAt: createdAt,
          updatedAt: scanCompletedAt,
        ),
      );
      await credentialStore.write(
        id,
        const WebDavCredentials(username: 'old', password: 'old-password'),
      );
      final connection = (await service.listConnections()).single;

      final result = await service.updateConnection(
        connection: connection,
        url: 'HTTPS://NAS.LOCAL:443/NewLibrary',
        displayName: 'New NAS',
        credentials: const WebDavCredentials(
          username: 'new',
          password: 'new-password',
        ),
      );

      expect(result.status, DiscoveryStatus.success);
      final updated = await repository.getSource(id);
      expect(updated?.id, id);
      expect(updated?.rootUri, 'https://nas.local/NewLibrary/');
      expect(updated?.displayName, 'New NAS');
      expect(updated?.scanRevision, 7);
      expect(updated?.lastScanStartedAt, scanStartedAt);
      expect(updated?.lastScanCompletedAt, scanCompletedAt);
      expect(updated?.createdAt, createdAt);
      expect(updated?.permissionBookmark, isNull);
      final stored = await credentialStore.read(id);
      expect(stored?.username, 'new');
      expect(stored?.password, 'new-password');
    });

    test(
      'probe without stored credentials records authentication failure',
      () async {
        const id = 'webdav:missing-secret';
        final now = DateTime.utc(2025, 1, 1);
        await repository.upsertSource(
          LibrarySourceRecord(
            id: id,
            type: LibrarySourceType.webDav,
            displayName: 'NAS',
            rootUri: 'https://nas.local/dav/',
            status: LibrarySourceStatus.available,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final result = await service.probeConnection(
          (await service.listConnections()).single,
        );

        expect(result.error, WebDavConnectionError.authenticationFailed);
        expect(
          (await repository.getSource(id))?.status,
          LibrarySourceStatus.permissionRequired,
        );
      },
    );

    test('watchConnections emits updates', () async {
      fakeDiscovery._nextResult = WebDavDiscoveryResult(
        status: DiscoveryStatus.success,
      );

      final events = <List<WebDavConnectionRecord>>[];
      final subscription = service.watchConnections().listen(events.add);
      addTearDown(subscription.cancel);

      await service.addConnection(
        url: 'https://nas.local/dav',
        displayName: 'NAS',
        credentials: const WebDavCredentials(username: 'u', password: 'p'),
      );

      expect(events, hasLength(greaterThanOrEqualTo(1)));
      expect(events.last, hasLength(1));
    });

    test('URL normalization removes default port and adds trailing slash', () {
      expect(
        WebDavConnectionService.normalizeWebDavUrl(
          ' HTTPS://NAS.LOCAL:443/Music ',
        ),
        'https://nas.local/Music/',
      );
    });

    test('URL validation rejects unsafe or unsupported forms', () {
      for (final value in [
        'ftp://nas.local/dav',
        'https://user:password@nas.local/dav',
        'https://nas.local/dav#fragment',
        'not-a-url',
      ]) {
        expect(
          () => WebDavConnectionService.normalizeWebDavUrl(value),
          throwsFormatException,
          reason: value,
        );
      }
    });

    test('stable ID normalizes host casing, default port, and slash', () {
      final id1 = WebDavConnectionService.stableWebDavConnectionId(
        'https://nas.local:443/dav',
      );
      final id2 = WebDavConnectionService.stableWebDavConnectionId(
        'https://NAS.LOCAL/dav/',
      );
      expect(id1, id2);
      expect(id1, startsWith('webdav:'));
    });

    test('stable ID preserves case-sensitive path identity', () {
      final upper = WebDavConnectionService.stableWebDavConnectionId(
        'https://nas.local/Music/',
      );
      final lower = WebDavConnectionService.stableWebDavConnectionId(
        'https://nas.local/music/',
      );
      expect(upper, isNot(lower));
    });
  });

  // ---------------------------------------------------------------------------
  // WebDavDiscoveryService protocol handling
  // ---------------------------------------------------------------------------
  group('WebDavDiscoveryService protocol handling', () {
    test(
      'rejects a successful HTTP server that does not advertise DAV',
      () async {
        var requestCount = 0;
        final discovery = WebDavDiscoveryService(
          clientFactory: () => MockClient((request) async {
            requestCount += 1;
            return http.Response('', 200);
          }),
        );

        final result = await discovery.probe(
          'https://example.test/dav/',
          credentials: const WebDavCredentials(username: '', password: ''),
        );

        expect(result.error, WebDavConnectionError.notAWebDavServer);
        expect(requestCount, 1, reason: 'PROPFIND must not run without DAV');
      },
    );

    test('requires PROPFIND to return Multi-Status', () async {
      var requestCount = 0;
      final discovery = WebDavDiscoveryService(
        clientFactory: () => MockClient((request) async {
          requestCount += 1;
          if (request.method == 'OPTIONS') {
            return http.Response('', 200, headers: {'DAV': '1'});
          }
          return http.Response('<html>not WebDAV</html>', 200);
        }),
      );

      final result = await discovery.probe(
        'https://example.test/dav/',
        credentials: const WebDavCredentials(username: 'u', password: 'p'),
      );

      expect(result.error, WebDavConnectionError.notAWebDavServer);
      expect(requestCount, 2);
    });

    test('parses DAV XML independently of namespace prefix', () async {
      final methods = <String>[];
      final discovery = WebDavDiscoveryService(
        clientFactory: () => MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'OPTIONS') {
            expect(request.headers['Authorization'], isNull);
            return http.Response(
              '',
              200,
              headers: {'DAV': '1, 2', 'Allow': 'OPTIONS, PROPFIND'},
            );
          }
          expect(request.headers['Depth'], '1');
          expect(request.headers['Content-Type'], contains('application/xml'));
          expect(request.body, contains('propfind'));
          return http.Response(
            '''<?xml version="1.0"?>
<x:multistatus xmlns:x="DAV:">
  <x:response>
    <x:href>/Music/Track%2001.flac</x:href>
    <x:propstat>
      <x:prop>
        <x:displayname>Track 01.flac</x:displayname>
        <x:resourcetype/>
        <x:getcontentlength>12345</x:getcontentlength>
      </x:prop>
      <x:status>HTTP/1.1 200 OK</x:status>
    </x:propstat>
  </x:response>
</x:multistatus>''',
            207,
            headers: {'content-type': 'application/xml'},
          );
        }),
      );

      final result = await discovery.probe(
        'https://example.test/dav/',
        credentials: const WebDavCredentials(username: '', password: ''),
      );

      expect(result.status, DiscoveryStatus.success);
      expect(methods, ['OPTIONS', 'PROPFIND']);
      expect(result.capabilities, containsAll(['1', '2']));
      expect(result.files, hasLength(1));
      expect(result.files.single.href, '/Music/Track%2001.flac');
      expect(result.files.single.displayName, 'Track 01.flac');
      expect(result.files.single.isCollection, isFalse);
      expect(result.files.single.contentLength, 12345);
    });

    test(
      'maps an OPTIONS authentication response to authenticationFailed',
      () async {
        final discovery = WebDavDiscoveryService(
          clientFactory: () => MockClient(
            (_) async =>
                http.Response('', 401, headers: {'www-authenticate': 'Basic'}),
          ),
        );

        final result = await discovery.probe(
          'https://example.test/dav/',
          credentials: const WebDavCredentials(
            username: 'bad',
            password: 'bad',
          ),
        );

        expect(result.error, WebDavConnectionError.authenticationFailed);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // WebDavDiscoveryService against fixture
  // ---------------------------------------------------------------------------
  group('WebDavDiscoveryService', () {
    late Directory root;
    late WebDavFixtureServer server;
    late WebDavDiscoveryService discovery;
    late WebDavCredentials credentials;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('sound-webdav-test-');
      await File(
        '${root.path}/sample.mp3',
      ).writeAsBytes(List.generate(16, (i) => i));
      await File('${root.path}/sub.txt').writeAsString('hello');
      server = await WebDavFixtureServer.start(
        root: root,
        username: 'sound',
        password: 'sound-test',
      );
      discovery = WebDavDiscoveryService();
      credentials = const WebDavCredentials(
        username: 'sound',
        password: 'sound-test',
      );
    });

    tearDown(() async {
      await server.close();
      await root.delete(recursive: true);
    });

    test('successful probe returns capabilities and files', () async {
      final url = 'http://127.0.0.1:${server.port}/';
      final result = await discovery.probe(url, credentials: credentials);

      expect(result.status, DiscoveryStatus.success);
      expect(result.error, isNull);
      // OPTIONS should return DAV header
      expect(result.capabilities.any((c) => c.contains('1')), isTrue);
      // PROPFIND should list sample.mp3
      final mp3 = result.files.where((f) => f.displayName == 'sample.mp3');
      expect(mp3, isNotEmpty);
    });

    test('authentication failure returns error', () async {
      final url = 'http://127.0.0.1:${server.port}/';
      final wrongCredentials = WebDavCredentials(
        username: 'bad',
        password: 'wrong',
      );
      final result = await discovery.probe(url, credentials: wrongCredentials);

      expect(result.status, DiscoveryStatus.error);
      expect(result.error, WebDavConnectionError.authenticationFailed);
    });

    test('unreachable host returns error', () async {
      final result = await discovery.probe(
        'http://127.0.0.1:1/',
        credentials: credentials,
      );

      expect(result.status, DiscoveryStatus.error);
      expect(
        result.error,
        WebDavConnectionError.unreachable,
        reason: result.errorMessage,
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Fake repository for isolated CRUD tests
// ---------------------------------------------------------------------------

class FakeWebDavDiscoveryService extends WebDavDiscoveryService {
  WebDavDiscoveryResult _nextResult = WebDavDiscoveryResult(
    status: DiscoveryStatus.success,
  );

  @override
  Future<WebDavDiscoveryResult> probe(
    String url, {
    required WebDavCredentials credentials,
  }) async {
    return _nextResult;
  }
}

class FakeLibraryRepository implements LibraryRepository {
  final List<LibrarySourceRecord> _sources = [];

  final _sourceController =
      StreamController<List<LibrarySourceRecord>>.broadcast(sync: true);

  @override
  Stream<List<LibrarySourceRecord>> watchSources() => _sourceController.stream;

  @override
  Future<List<LibrarySourceRecord>> getSources() async => List.of(_sources);

  @override
  Future<void> upsertSource(LibrarySourceRecord source) async {
    final index = _sources.indexWhere((s) => s.id == source.id);
    if (index >= 0) {
      _sources[index] = source;
    } else {
      _sources.add(source);
    }
    _sourceController.add(List.of(_sources));
  }

  @override
  Future<void> deleteSource(String id) async {
    _sources.removeWhere((s) => s.id == id);
    _sourceController.add(List.of(_sources));
  }

  @override
  Future<LibrarySourceRecord?> getSource(String id) async {
    try {
      return _sources.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> markSourceScanning(
    String id, {
    required DateTime startedAt,
  }) async {
    // No-op for tests.
  }

  // --- Unused repository methods ---

  @override
  Future<void> close() async {}

  @override
  Future<void> markSourceFailure(
    String id, {
    required LibrarySourceStatus status,
    required String message,
    required DateTime occurredAt,
  }) async {}

  @override
  Future<void> replaceSourceScan(LibraryScanBatch batch) async {}

  @override
  Stream<List<LibraryAlbumRecord>> watchAlbums() => const Stream.empty();

  @override
  Stream<List<LibraryArtistRecord>> watchArtists() => const Stream.empty();

  @override
  Stream<List<LibraryTrackRecord>> watchTracks() => const Stream.empty();

  @override
  Stream<List<LibraryFavoriteTrackRecord>> watchFavoriteTracks() =>
      const Stream.empty();

  @override
  Stream<List<LibraryPlayHistoryRecord>> watchPlayHistory({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<List<LibraryPlaylistRecord>> watchPlaylists() => const Stream.empty();

  @override
  Stream<List<LibraryPlaylistTrackRecord>> watchPlaylistTracks() =>
      const Stream.empty();

  @override
  Future<List<LibraryAlbumRecord>> getAlbums({String? sourceId}) async => [];

  @override
  Future<List<LibraryArtistRecord>> getArtists({String? sourceId}) async => [];

  @override
  Future<List<LibraryLyricRecord>> getLyrics(String trackId) async => [];

  @override
  Future<Map<String, List<LibraryLyricRecord>>> getAllLyrics() async => {};

  @override
  Future<List<LibraryFavoriteTrackRecord>> getFavoriteTracks() async => [];

  @override
  Future<List<LibraryPlayHistoryRecord>> getPlayHistory({
    int limit = 500,
  }) async => [];

  @override
  Future<List<LibraryPlaylistRecord>> getPlaylists() async => [];

  @override
  Future<List<LibraryPlaylistTrackRecord>> getPlaylistTracks({
    int? playlistId,
  }) async => [];

  @override
  Future<List<LibraryTrackRecord>> getTracks({String? sourceId}) async => [];

  @override
  Future<void> setTrackFavorite(
    String trackId, {
    required bool favorite,
    required DateTime changedAt,
  }) async {}

  @override
  Future<void> addPlayHistory(
    String trackId, {
    required DateTime playedAt,
  }) async {}

  @override
  Future<void> clearPlayHistory() async {}

  @override
  Future<int> createPlaylist({
    required String name,
    required DateTime createdAt,
  }) async => 1;

  @override
  Future<void> renamePlaylist(
    int playlistId, {
    required String name,
    required DateTime changedAt,
  }) async {}

  @override
  Future<void> deletePlaylist(int playlistId) async {}

  @override
  Future<bool> addTrackToPlaylist(
    int playlistId,
    String trackId, {
    required DateTime addedAt,
  }) async => true;

  @override
  Future<void> removeTrackFromPlaylist(
    int playlistId,
    String trackId, {
    required DateTime changedAt,
  }) async {}

  @override
  Future<void> reorderPlaylistTracks(
    int playlistId,
    List<String> orderedTrackIds, {
    required DateTime changedAt,
  }) async {}
}
