import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/offline/offline_media_provider.dart';
import 'package:kaiting/presentation/controllers/offline_download_controller.dart';
import 'package:kaiting/sources/webdav/webdav_cache.dart';
import 'package:kaiting/sources/webdav/webdav_offline_media_provider.dart';

void main() {
  late Directory cacheDirectory;
  late HttpServer server;
  var failRecoverableRequests = true;
  String? lastAuthorization;

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp(
      'sound-offline-controller-test-',
    );
    failRecoverableRequests = true;
    lastAuthorization = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      lastAuthorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      if (request.uri.path.contains('fail') && failRecoverableRequests) {
        request.response.statusCode = HttpStatus.internalServerError;
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('audio', 'flac')
          ..contentLength = 2048
          ..add(List<int>.filled(2048, 7));
      }
      await request.response.close();
    });
  });

  Track track(String path) => Track(
    id: path,
    title: path,
    artist: 'Artist',
    albumTitle: 'Album',
    duration: const Duration(minutes: 3),
    source: SourceKind.webDav,
    mediaUri: 'http://127.0.0.1:${server.port}/$path',
  );

  tearDown(() async {
    await server.close(force: true);
    await cacheDirectory.delete(recursive: true);
  });

  test('pins and removes a WebDAV track with observable state', () async {
    final cache = WebDavCache(cacheDir: cacheDirectory, maxBytes: 4096);
    final controller = OfflineDownloadController(
      providers: [WebDavOfflineMediaProvider(cache: cache)],
    );
    final item = track('song.flac');
    await controller.refresh();

    final download = controller.pinTrack(item);
    expect(controller.isDownloading(item), isTrue);
    await download;

    expect(controller.isPinned(item), isTrue);
    expect(controller.taskFor(item), isNull);
    expect(controller.stats.pinnedEntries, 1);
    expect(controller.stats.pinnedBytes, 2048);

    await controller.removeTrack(item);
    expect(controller.isPinned(item), isFalse);
    expect(controller.stats.totalEntries, 0);
    controller.dispose();
  });

  test('provider resolves credentials without storing them on Track', () async {
    final cache = WebDavCache(cacheDir: cacheDirectory, maxBytes: 4096);
    final provider = WebDavOfflineMediaProvider(cache: cache)
      ..updateAccess(
        authHeaders: {
          'http://127.0.0.1:${server.port}/': const {
            'Authorization': 'Basic provider-token',
          },
        },
        allowBadCertificateUrls: const {},
      );
    final controller = OfflineDownloadController(providers: [provider]);

    await controller.pinTrack(track('authenticated.flac'));

    expect(lastAuthorization, 'Basic provider-token');
    controller.dispose();
  });

  test('batch downloads continue after one file fails', () async {
    final cache = WebDavCache(cacheDir: cacheDirectory, maxBytes: 4096);
    final controller = OfflineDownloadController(
      providers: [WebDavOfflineMediaProvider(cache: cache)],
    );
    await controller.refresh();
    final successful = track('song.flac');
    final failing = track('fail.flac');

    final result = await controller.pinTracks([successful, failing]);

    expect(result.completed, 1);
    expect(result.failed, 1);
    expect(controller.isPinned(successful), isTrue);
    expect(controller.taskFor(failing)?.state, OfflineDownloadTaskState.failed);
    controller.dispose();
  });

  test('cancels a queued download without leaving a failed task', () async {
    final cache = WebDavCache(cacheDir: cacheDirectory, maxBytes: 4096);
    final controller = OfflineDownloadController(
      providers: [WebDavOfflineMediaProvider(cache: cache)],
    );
    final item = track('cancel.flac');
    await controller.refresh();

    final download = controller.pinTrack(item);
    expect(controller.cancelTrack(item), isTrue);

    await expectLater(
      download,
      throwsA(isA<OfflineDownloadCancelledException>()),
    );
    expect(controller.taskFor(item), isNull);
    expect(controller.isPinned(item), isFalse);
    expect((await cache.stats()).totalEntries, 0);
    controller.dispose();
  });

  test(
    'offline items use library metadata and failed items can retry',
    () async {
      final cache = WebDavCache(cacheDir: cacheDirectory, maxBytes: 4096);
      final controller = OfflineDownloadController(
        providers: [WebDavOfflineMediaProvider(cache: cache)],
      );
      final item = track('fail.flac');
      controller.updateLibraryTracks([item]);
      await controller.refresh();

      await expectLater(controller.pinTrack(item), throwsA(anything));
      final failed = controller.offlineItems.single;
      expect(failed.title, 'fail.flac');
      expect(failed.artist, 'Artist');
      expect(failed.albumTitle, 'Album');
      expect(failed.canRetry, isTrue);

      failRecoverableRequests = false;
      await controller.retry(failed.reference);

      final downloaded = controller.offlineItems.single;
      expect(downloaded.pinned, isTrue);
      expect(downloaded.task, isNull);
      expect(downloaded.size, 2048);
      controller.dispose();
    },
  );

  test('local and invalid resources are not offered for offline download', () {
    final cache = WebDavCache(cacheDir: cacheDirectory);
    final controller = OfflineDownloadController(
      providers: [WebDavOfflineMediaProvider(cache: cache)],
    );

    expect(
      controller.supports(
        const Track(
          id: 'local',
          title: 'Local',
          artist: 'Artist',
          albumTitle: 'Album',
          duration: Duration.zero,
          source: SourceKind.local,
          mediaUri: '/tmp/song.flac',
        ),
      ),
      isFalse,
    );
    expect(
      controller.supports(
        const Track(
          id: 'invalid',
          title: 'Invalid',
          artist: 'Artist',
          albumTitle: 'Album',
          duration: Duration.zero,
          source: SourceKind.webDav,
          mediaUri: 'not-a-url',
        ),
      ),
      isFalse,
    );
    controller.dispose();
  });
}
