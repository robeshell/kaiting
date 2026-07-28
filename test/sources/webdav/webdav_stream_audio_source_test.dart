import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/playback/http_stream_audio_source.dart';

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
    final source = HttpStreamAudioSource(
      uri: Uri.parse('http://127.0.0.1:${server.port}/audio.mp3'),
      headers: const {'Authorization': 'Basic test'},
      allowBadCertificate: false,
    );

    final response = await source.request();

    expect(response.rangeRequestsSupported, isTrue);
    // Full-body responses omit contentLength so a dropped NAS connection
    // cannot crash the just_audio loopback proxy on close.
    expect(response.contentLength, isNull);
    expect(response.sourceLength, bytes.length);
    expect(await response.stream.expand((chunk) => chunk).toList(), bytes);
  });

  test('maps exclusive byte ranges and reports the source length', () async {
    final source = HttpStreamAudioSource(
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

  test('treats incomplete Content-Length bodies as end-of-stream', () async {
    // Raw socket so we can promise Content-Length: 100 then hang up after 4
    // bytes — HttpServer refuses to close short of the declared length.
    final incomplete = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => incomplete.close());
    incomplete.listen((socket) async {
      await socket.first;
      socket.add(
        utf8.encode(
          'HTTP/1.1 200 OK\r\n'
          'Content-Type: audio/flac\r\n'
          'Content-Length: 100\r\n'
          'Connection: close\r\n'
          '\r\n',
        ),
      );
      socket.add([1, 2, 3, 4]);
      await socket.close();
    });

    final source = HttpStreamAudioSource(
      uri: Uri.parse('http://127.0.0.1:${incomplete.port}/partial.flac'),
      headers: const {},
      allowBadCertificate: false,
    );

    final response = await source.request();
    final chunks = <int>[];
    await for (final chunk in response.stream) {
      chunks.addAll(chunk);
    }
    expect(chunks, [1, 2, 3, 4]);
  });
}
