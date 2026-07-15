import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sound_player/library/scanning/audio_format_registry.dart';

Future<void> main(List<String> arguments) async {
  final options = FixtureServerOptions.parse(arguments);
  if (options.showHelp) {
    stdout.writeln(FixtureServerOptions.usage);
    return;
  }

  final root = Directory(options.root).absolute;
  if (!root.existsSync()) {
    stderr.writeln('Fixture root does not exist: ${root.path}');
    exitCode = 64;
    return;
  }

  final fixture = await WebDavFixtureServer.start(
    root: root,
    address: options.host,
    port: options.port,
    username: options.username,
    password: options.password,
    bytesPerSecond: options.bytesPerSecond,
  );
  stdout.writeln(
    'Sound WebDAV fixture: http://${options.host}:${fixture.port}/',
  );
  stdout.writeln('Root: ${root.path}');
  stdout.writeln('Username: ${options.username}');
  stdout.writeln('Press Ctrl-C to stop.');

  ProcessSignal.sigint.watch().listen((_) async {
    await fixture.close();
    exit(0);
  });
}

class WebDavFixtureServer {
  WebDavFixtureServer._(
    Directory root,
    this._server,
    this._authorization,
    this._bytesPerSecond,
  ) : _root = root.absolute;

  final Directory _root;
  final HttpServer _server;
  final String _authorization;
  final int _bytesPerSecond;
  StreamSubscription<HttpRequest>? _subscription;

  int get port => _server.port;

  static Future<WebDavFixtureServer> start({
    required Directory root,
    required String username,
    required String password,
    Object? address,
    int port = 0,
    int bytesPerSecond = 0,
  }) async {
    final server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    final token = base64Encode(utf8.encode('$username:$password'));
    final fixture = WebDavFixtureServer._(
      root,
      server,
      'Basic $token',
      bytesPerSecond,
    );
    fixture._subscription = server.listen(fixture._handleRequest);
    return fixture;
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    var status = HttpStatus.internalServerError;
    var transferred = 0;
    final requestedRange = request.headers.value(HttpHeaders.rangeHeader);
    final requestLabel =
        '${request.method} ${request.uri.path} range=${requestedRange ?? 'none'}';
    stdout.writeln('$requestLabel started ${DateTime.now().toIso8601String()}');
    try {
      if (request.headers.value(HttpHeaders.authorizationHeader) !=
          _authorization) {
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..headers.set(
            HttpHeaders.wwwAuthenticateHeader,
            'Basic realm="Sound WebDAV fixture", charset="UTF-8"',
          );
        status = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }

      request.response.headers
        ..set('DAV', '1')
        ..set('MS-Author-Via', 'DAV')
        ..set(HttpHeaders.acceptRangesHeader, 'bytes');

      if (request.method == 'OPTIONS') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.set('Allow', 'OPTIONS, PROPFIND, HEAD, GET');
        status = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final entity = _resolve(request.uri);
      if (entity == null || !entity.existsSync()) {
        request.response.statusCode = HttpStatus.notFound;
        status = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      if (request.method == 'PROPFIND') {
        status = await _sendProperties(request, entity);
        return;
      }

      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..headers.set('Allow', 'OPTIONS, PROPFIND, HEAD, GET');
        status = HttpStatus.methodNotAllowed;
        await request.response.close();
        return;
      }

      if (entity is! File) {
        request.response.statusCode = HttpStatus.notFound;
        status = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final result = await _sendFile(request, entity);
      status = result.status;
      transferred = result.bytes;
    } catch (error, stackTrace) {
      stderr.writeln('Fixture request failed: $error\n$stackTrace');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } on Object {
        // The client may have disconnected after headers were sent.
      }
    } finally {
      stdout.writeln(
        '$requestLabel -> $status ($transferred bytes) '
        '${DateTime.now().toIso8601String()}',
      );
    }
  }

  FileSystemEntity? _resolve(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.any(
      (segment) =>
          segment == '..' || segment.contains('/') || segment.contains('\\'),
    )) {
      return null;
    }
    final path = segments.fold(
      _root.path,
      (current, segment) => '$current${Platform.pathSeparator}$segment',
    );
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    return switch (type) {
      FileSystemEntityType.file => File(path),
      FileSystemEntityType.directory => Directory(path),
      _ => null,
    };
  }

  Future<int> _sendProperties(
    HttpRequest request,
    FileSystemEntity entity,
  ) async {
    final entities = <FileSystemEntity>[entity];
    final depth = request.headers.value('Depth');
    if (entity is Directory && depth != '0') {
      entities.addAll(entity.listSync(followLinks: false));
    }
    final responses = <String>[];
    for (final child in entities) {
      final stat = child.statSync();
      final relativeSegments = child.path
          .substring(_root.path.length)
          .replaceAll(Platform.pathSeparator, '/')
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);
      final href = relativeSegments.isEmpty
          ? '/'
          : '/${relativeSegments.map(Uri.encodeComponent).join('/')}';
      final isDirectory = stat.type == FileSystemEntityType.directory;
      responses.add('''
<d:response>
  <d:href>${_xmlEscape(href)}${isDirectory && !href.endsWith('/') ? '/' : ''}</d:href>
  <d:propstat><d:prop>
    <d:displayname>${_xmlEscape(child.uri.pathSegments.lastOrNull ?? '/')}</d:displayname>
    <d:resourcetype>${isDirectory ? '<d:collection/>' : ''}</d:resourcetype>
    <d:getcontentlength>${isDirectory ? 0 : stat.size}</d:getcontentlength>
    <d:getlastmodified>${HttpDate.format(stat.modified.toUtc())}</d:getlastmodified>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
</d:response>''');
    }
    final body = utf8.encode(
      '<?xml version="1.0" encoding="utf-8"?>'
      '<d:multistatus xmlns:d="DAV:">${responses.join()}</d:multistatus>',
    );
    request.response
      ..statusCode = 207
      ..headers.contentType = ContentType(
        'application',
        'xml',
        charset: 'utf-8',
      )
      ..contentLength = body.length
      ..add(body);
    await request.response.close();
    return 207;
  }

  Future<_TransferResult> _sendFile(HttpRequest request, File file) async {
    final length = file.lengthSync();
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    final range = rangeHeader == null
        ? ByteRange.full(length)
        : ByteRange.parse(rangeHeader, length: length);
    if (range == null) {
      request.response
        ..statusCode = HttpStatus.requestedRangeNotSatisfiable
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
      await request.response.close();
      return const _TransferResult(
        status: HttpStatus.requestedRangeNotSatisfiable,
        bytes: 0,
      );
    }

    final partial = rangeHeader != null;
    final bytes = range.length;
    request.response.bufferOutput = false;
    request.response
      ..statusCode = partial ? HttpStatus.partialContent : HttpStatus.ok
      ..contentLength = bytes
      ..headers.contentType = _contentType(file.path);
    if (partial) {
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes ${range.start}-${range.end}/$length',
      );
    }
    var transferred = 0;
    if (request.method == 'GET' && bytes > 0) {
      transferred = await _streamFile(
        request.response,
        file,
        start: range.start,
        length: bytes,
      );
    }
    try {
      await request.response.close();
    } on Object {
      // A seek normally cancels the previous open-ended range request.
    }
    return _TransferResult(
      status: request.response.statusCode,
      bytes: transferred,
    );
  }

  Future<int> _streamFile(
    HttpResponse response,
    File file, {
    required int start,
    required int length,
  }) async {
    if (_bytesPerSecond <= 0) {
      await response.addStream(file.openRead(start, start + length));
      return length;
    }

    const chunkSize = 64 * 1024;
    final handle = await file.open();
    var transferred = 0;
    try {
      await handle.setPosition(start);
      while (transferred < length) {
        final remaining = length - transferred;
        final chunk = await handle.read(
          remaining < chunkSize ? remaining : chunkSize,
        );
        if (chunk.isEmpty) break;
        response.add(chunk);
        await response.flush();
        transferred += chunk.length;
        final delayMicros =
            (chunk.length * Duration.microsecondsPerSecond) ~/ _bytesPerSecond;
        if (delayMicros > 0) {
          await Future<void>.delayed(Duration(microseconds: delayMicros));
        }
      }
    } on Object {
      // Client cancellation is expected when the player seeks to a new range.
    } finally {
      await handle.close();
    }
    return transferred;
  }
}

class ByteRange {
  const ByteRange(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start + 1;

  factory ByteRange.full(int length) => ByteRange(0, length - 1);

  static ByteRange? parse(String value, {required int length}) {
    if (length <= 0 || !value.startsWith('bytes=') || value.contains(',')) {
      return null;
    }
    final parts = value.substring(6).split('-');
    if (parts.length != 2) return null;
    final startText = parts.first.trim();
    final endText = parts.last.trim();

    if (startText.isEmpty) {
      final suffixLength = int.tryParse(endText);
      if (suffixLength == null || suffixLength <= 0) return null;
      final start = (length - suffixLength).clamp(0, length - 1);
      return ByteRange(start, length - 1);
    }

    final start = int.tryParse(startText);
    final requestedEnd = endText.isEmpty ? length - 1 : int.tryParse(endText);
    if (start == null ||
        requestedEnd == null ||
        start < 0 ||
        start >= length ||
        requestedEnd < start) {
      return null;
    }
    return ByteRange(start, requestedEnd.clamp(start, length - 1));
  }
}

class FixtureServerOptions {
  const FixtureServerOptions({
    required this.root,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.bytesPerSecond,
    required this.showHelp,
  });

  final String root;
  final String host;
  final int port;
  final String username;
  final String password;
  final int bytesPerSecond;
  final bool showHelp;

  static const usage = '''
Usage:
  dart run tool/webdav_fixture_server.dart --root <directory> [options]

Options:
  --host <address>     Bind address (default: 127.0.0.1)
  --port <port>        Port (default: 8088)
  --username <value>  Basic Auth username (default: sound)
  --password <value>  Basic Auth password (default: sound-test)
  --bytes-per-second <bytes>
                       Optional transfer throttle (default: unlimited)
  --help               Show this help
''';

  static FixtureServerOptions parse(List<String> arguments) {
    final values = <String, String>{};
    var showHelp = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--help' || argument == '-h') {
        showHelp = true;
        continue;
      }
      if (!argument.startsWith('--') || index + 1 >= arguments.length) {
        throw FormatException('Invalid argument: $argument\n$usage');
      }
      values[argument.substring(2)] = arguments[++index];
    }
    final root = values['root'] ?? '';
    if (!showHelp && root.isEmpty) {
      throw const FormatException('--root is required.');
    }
    final port = int.tryParse(values['port'] ?? '8088');
    if (port == null || port < 0 || port > 65535) {
      throw FormatException('Invalid port: ${values['port']}');
    }
    final bytesPerSecond = int.tryParse(values['bytes-per-second'] ?? '0');
    if (bytesPerSecond == null || bytesPerSecond < 0) {
      throw FormatException(
        'Invalid bytes-per-second: ${values['bytes-per-second']}',
      );
    }
    return FixtureServerOptions(
      root: root,
      host: values['host'] ?? '127.0.0.1',
      port: port,
      username: values['username'] ?? 'sound',
      password: values['password'] ?? 'sound-test',
      bytesPerSecond: bytesPerSecond,
      showHelp: showHelp,
    );
  }
}

class _TransferResult {
  const _TransferResult({required this.status, required this.bytes});

  final int status;
  final int bytes;
}

ContentType _contentType(String path) {
  final value = audioContentTypeForPath(path);
  if (value == null) return ContentType.binary;
  final parts = value.split('/');
  return ContentType(parts.first, parts.last);
}

String _xmlEscape(String value) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(value);
