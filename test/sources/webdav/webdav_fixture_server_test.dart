import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/webdav_fixture_server.dart';

void main() {
  late Directory root;
  late WebDavFixtureServer server;
  late HttpClient client;
  final authorization =
      'Basic ${base64Encode(utf8.encode('sound:sound-test'))}';
  Uri uri(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sound-webdav-test-');
    await File(
      '${root.path}/sample.mp3',
    ).writeAsBytes(List.generate(16, (i) => i));
    server = await WebDavFixtureServer.start(
      root: root,
      username: 'sound',
      password: 'sound-test',
    );
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close();
    await root.delete(recursive: true);
  });

  test('requires Basic authentication', () async {
    final request = await client.getUrl(uri('/sample.mp3'));
    final response = await request.close();

    expect(response.statusCode, HttpStatus.unauthorized);
    expect(
      response.headers.value(HttpHeaders.wwwAuthenticateHeader),
      contains('Basic'),
    );
  });

  test('serves a byte range with WebDAV headers', () async {
    final request = await client.getUrl(uri('/sample.mp3'));
    request.headers
      ..set(HttpHeaders.authorizationHeader, authorization)
      ..set(HttpHeaders.rangeHeader, 'bytes=4-7');
    final response = await request.close();
    final body = await response.fold<List<int>>(
      <int>[],
      (all, bytes) => all..addAll(bytes),
    );

    expect(response.statusCode, HttpStatus.partialContent);
    expect(
      response.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 4-7/16',
    );
    expect(response.headers.value('DAV'), '1');
    expect(body, [4, 5, 6, 7]);
  });

  test('answers PROPFIND for fixture discovery', () async {
    final request = await client.openUrl('PROPFIND', uri('/'));
    request.headers
      ..set(HttpHeaders.authorizationHeader, authorization)
      ..set('Depth', '1');
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    expect(response.statusCode, 207);
    expect(body, contains('sample.mp3'));
  });
}
