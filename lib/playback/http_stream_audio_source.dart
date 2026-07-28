// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

import '../library/scanning/audio_format_registry.dart';

/// A range-capable HTTP source for remote media (WebDAV / NAS).
///
/// Used instead of [ProgressiveAudioSource] when just_audio would otherwise
/// route through its URI loopback proxy (macOS / Windows, or bad TLS). That
/// proxy treats incomplete `Content-Length` bodies as HTTP/0.9 and can crash
/// in `detachSocket`. Serving via [StreamAudioSource] avoids that path.
///
/// Incomplete upstream bodies are handled so the loopback proxy does not
/// throw "No content even though contentLength was specified" on close.
class HttpStreamAudioSource extends StreamAudioSource {
  HttpStreamAudioSource({
    required this.uri,
    required this.headers,
    required this.allowBadCertificate,
    super.tag,
  });

  final Uri uri;
  final Map<String, String> headers;
  final bool allowBadCertificate;

  /// Fully buffer ranged responses up to this size so delivered bytes always
  /// match [StreamAudioResponse.contentLength] (avoids proxy close errors).
  static const _maxBufferedRangeBytes = 8 * 1024 * 1024;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      // Large FLAC over WebDAV can idle between chunks on a busy NAS.
      ..idleTimeout = const Duration(minutes: 5);
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
        client.close(force: true);
        throw HttpException(
          'HTTP media stream failed: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      if (rangedRequest && response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        client.close(force: true);
        throw HttpException('Media server ignored the byte range', uri: uri);
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
      final contentType =
          response.headers.contentType?.mimeType ??
          audioContentTypeForPath(uri.path) ??
          'application/octet-stream';

      // Small range requests: buffer fully so the just_audio loopback proxy
      // always closes with an exact content length (no uncaught HttpException).
      if (rangedRequest &&
          contentLength != null &&
          contentLength <= _maxBufferedRangeBytes) {
        try {
          final builder = BytesBuilder(copy: false);
          await for (final chunk in response) {
            builder.add(chunk);
          }
          client.close();
          final bytes = builder.takeBytes();
          return StreamAudioResponse(
            rangeRequestsSupported: acceptsRanges,
            sourceLength: sourceLength,
            contentLength: bytes.length,
            offset: start ?? 0,
            contentType: contentType,
            stream: Stream<List<int>>.value(bytes),
          );
        } catch (error) {
          client.close(force: true);
          rethrow;
        }
      }

      // Full-body streams: do not advertise a fixed contentLength. NAS/WebDAV
      // often close early (timeouts, sleep); promising 173MB and delivering less
      // makes Dart's HttpServer throw on proxy response close. Progressive
      // players still decode with chunked / unknown length; range probes above
      // keep seeking accurate when the server supports Accept-Ranges.
      final publishContentLength = rangedRequest ? contentLength : null;

      return StreamAudioResponse(
        rangeRequestsSupported: acceptsRanges,
        sourceLength: rangedRequest ? sourceLength : contentLength,
        contentLength: publishContentLength,
        offset: rangedRequest ? start ?? 0 : null,
        contentType: contentType,
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

  static bool _isIncompleteBodyError(Object error) {
    if (error is! HttpException) return false;
    final message = error.message.toLowerCase();
    return message.contains('contentlength') ||
        message.contains('content length') ||
        message.contains('connection closed while receiving') ||
        message.contains('connection closed before full header') ||
        message.contains('no content even though');
  }

  /// Forwards body bytes and always closes cleanly. Incomplete Content-Length
  /// from the origin becomes a normal stream end (not an uncaught error).
  Stream<List<int>> _closingStream(
    HttpClientResponse response,
    HttpClient client,
  ) {
    late final StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    var closed = false;

    Future<void> shutDown({Object? error, StackTrace? stackTrace}) async {
      if (closed) return;
      closed = true;
      client.close(force: true);
      await subscription?.cancel();
      if (!controller.isClosed) {
        // Incomplete origin body is common on flaky NAS / WebDAV. Surface as
        // clean EOS so the just_audio source proxy can close the loopback
        // response without a second uncaught exception.
        if (error != null && _isIncompleteBodyError(error)) {
          await controller.close();
          return;
        }
        if (error != null) {
          controller.addError(error, stackTrace);
        }
        await controller.close();
      }
    }

    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        subscription = response.listen(
          (chunk) {
            if (!closed && !controller.isClosed) {
              controller.add(chunk);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            unawaited(shutDown(error: error, stackTrace: stackTrace));
          },
          onDone: () {
            unawaited(shutDown());
          },
          cancelOnError: true,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        await shutDown();
      },
    );
    return controller.stream;
  }
}
