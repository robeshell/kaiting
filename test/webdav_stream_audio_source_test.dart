import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/playback/webdav_stream_audio_source.dart';

void main() {
  late HttpServer server;
  const bytes = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.headers.value('authorization') != 'Basic test') {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }
      request.response.headers
        ..contentType = ContentType('audio', 'mpeg')
        ..set(HttpHeaders.acceptRangesHeader, 'bytes');
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range == 'bytes=3-6') {
        request.response
          ..statusCode = HttpStatus.partialContent
          ..contentLength = 4
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 3-6/10')
          ..add(bytes.sublist(3, 7));
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..contentLength = bytes.length
          ..add(bytes);
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('forwards authentication and returns a full response', () async {
    final source = WebDavStreamAudioSource(
      uri: Uri.parse('http://127.0.0.1:${server.port}/audio.mp3'),
      headers: const {'Authorization': 'Basic test'},
      allowBadCertificate: false,
    );

    final response = await source.request();

    expect(response.rangeRequestsSupported, isTrue);
    expect(response.contentLength, bytes.length);
    expect(await response.stream.expand((chunk) => chunk).toList(), bytes);
  });

  test('maps exclusive byte ranges and reports the source length', () async {
    final source = WebDavStreamAudioSource(
      uri: Uri.parse('http://127.0.0.1:${server.port}/audio.mp3'),
      headers: const {'Authorization': 'Basic test'},
      allowBadCertificate: false,
    );

    final response = await source.request(3, 7);

    expect(response.sourceLength, bytes.length);
    expect(response.offset, 3);
    expect(response.contentLength, 4);
    expect(
      await response.stream.expand((chunk) => chunk).toList(),
      bytes.sublist(3, 7),
    );
  });
}
