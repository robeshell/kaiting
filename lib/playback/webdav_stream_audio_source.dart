// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

/// A range-capable WebDAV source used when a connection explicitly permits an
/// untrusted certificate. Keeping the [HttpClient] here avoids weakening TLS
/// checks for just_audio's process-wide proxy or unrelated network traffic.
class WebDavStreamAudioSource extends StreamAudioSource {
  WebDavStreamAudioSource({
    required this.uri,
    required this.headers,
    required this.allowBadCertificate,
  });

  final Uri uri;
  final Map<String, String> headers;
  final bool allowBadCertificate;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    if (allowBadCertificate) {
      client.badCertificateCallback = (_, _, _) => true;
    }

    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      if (start != null || end != null) {
        final first = start ?? 0;
        final last = end == null ? '' : '${end - 1}';
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$first-$last');
      }

      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final rangedRequest = start != null || end != null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw HttpException(
          'WebDAV stream failed: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      if (rangedRequest && response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        throw HttpException('WebDAV server ignored the byte range', uri: uri);
      }

      final contentLength = response.contentLength < 0
          ? null
          : response.contentLength;
      final sourceLength = _sourceLengthFromContentRange(
        response.headers.value(HttpHeaders.contentRangeHeader),
      );
      final acceptsRanges =
          response.statusCode == HttpStatus.partialContent ||
          response.headers.value(HttpHeaders.acceptRangesHeader) == 'bytes';

      return StreamAudioResponse(
        rangeRequestsSupported: acceptsRanges,
        sourceLength: rangedRequest ? sourceLength : null,
        contentLength: contentLength,
        offset: rangedRequest ? start ?? 0 : null,
        contentType: response.headers.contentType?.mimeType ?? 'audio/mpeg',
        stream: _closingStream(response, client),
      );
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }

  int? _sourceLengthFromContentRange(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^bytes\s+\d+-\d+/(\d+|\*)$').firstMatch(value);
    final total = match?.group(1);
    return total == null || total == '*' ? null : int.tryParse(total);
  }

  Stream<List<int>> _closingStream(
    HttpClientResponse response,
    HttpClient client,
  ) {
    late final StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        subscription = response.listen(
          controller.add,
          onError: (Object error, StackTrace stackTrace) {
            client.close(force: true);
            controller.addError(error, stackTrace);
            unawaited(controller.close());
          },
          onDone: () {
            client.close();
            unawaited(controller.close());
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        client.close(force: true);
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
