import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/sources/webdav/webdav_cache.dart';

void main() {
  late Directory cacheDirectory;
  late HttpServer server;
  var requestCount = 0;
  var failRequests = false;

  setUp(() async {
    requestCount = 0;
    failRequests = false;
    cacheDirectory = await Directory.systemTemp.createTemp(
      'sound-webdav-cache-test-',
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requestCount++;
      if (failRequests) {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }
      final fill = request.uri.path.contains('second') ? 2 : 1;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('audio', 'mpeg')
        ..add(List<int>.filled(2048, fill));
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await cacheDirectory.delete(recursive: true);
  });

  test('replacing an entry does not double-count its bytes', () async {
    final cache = WebDavCache(cacheDir: cacheDirectory, maxBytes: 3000);
    await cache.init();
    final firstUrl = 'http://127.0.0.1:${server.port}/first.mp3';

    final firstPath = await cache.download(firstUrl, headers: const {});
    final replacedPath = await cache.download(firstUrl, headers: const {});

    expect(replacedPath, firstPath);
    expect(await File(replacedPath).exists(), isTrue);
  });

  test(
    'a file larger than the limit is rejected without a dangling path',
    () async {
      final cache = WebDavCache(cacheDir: cacheDirectory, maxBytes: 1500);
      await cache.init();
      final url = 'http://127.0.0.1:${server.port}/oversized.mp3';

      await expectLater(
        cache.download(url, headers: const {}),
        throwsA(isA<HttpException>()),
      );
      expect(await cache.get(url), isNull);
    },
  );

  test('coalesces concurrent downloads of the same URL', () async {
    final cache = WebDavCache(cacheDir: cacheDirectory, maxBytes: 3000);
    await cache.init();
    final url = 'http://127.0.0.1:${server.port}/same.mp3';

    final paths = await Future.wait([
      cache.download(url, headers: const {}),
      cache.download(url, headers: const {}),
    ]);

    expect(paths[1], paths[0]);
    expect(requestCount, 1);
  });

  test('keeps a valid cached file when a refresh fails', () async {
    final cache = WebDavCache(cacheDir: cacheDirectory, maxBytes: 3000);
    await cache.init();
    final url = 'http://127.0.0.1:${server.port}/stable.mp3';
    final path = await cache.download(url, headers: const {});
    final original = await File(path).readAsBytes();
    failRequests = true;

    await expectLater(
      cache.download(url, headers: const {}),
      throwsA(isA<HttpException>()),
    );

    expect(await cache.get(url), path);
    expect(await File(path).readAsBytes(), original);
  });

  test('extensionless cached files survive cache reinitialization', () async {
    final url = 'http://127.0.0.1:${server.port}/audio';
    final cache = WebDavCache(cacheDir: cacheDirectory, maxBytes: 3000);
    await cache.init();
    final path = await cache.download(url, headers: const {});

    final reopened = WebDavCache(cacheDir: cacheDirectory, maxBytes: 3000);
    await reopened.init();

    expect(await reopened.get(url), path);
    expect(await File(path).exists(), isTrue);
  });
}
