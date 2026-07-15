import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:xml/xml.dart';

import 'webdav_credentials.dart';

enum WebDavConnectionError {
  unreachable,
  authenticationFailed,
  notAWebDavServer,
  unknown,
}

class WebDavDiscoveryResult {
  const WebDavDiscoveryResult({
    this.status = DiscoveryStatus.unknown,
    this.error,
    this.errorMessage,
    this.capabilities = const [],
    this.files = const [],
  });

  factory WebDavDiscoveryResult.error(
    WebDavConnectionError error, {
    String? message,
  }) {
    return WebDavDiscoveryResult(
      status: DiscoveryStatus.error,
      error: error,
      errorMessage: message,
    );
  }

  final DiscoveryStatus status;
  final WebDavConnectionError? error;
  final String? errorMessage;
  final List<String> capabilities;
  final List<WebDavFileEntry> files;

  bool get isReachable => error != WebDavConnectionError.unreachable;
}

enum DiscoveryStatus { unknown, probing, error, success }

class WebDavFileEntry {
  const WebDavFileEntry({
    required this.href,
    required this.displayName,
    required this.isCollection,
    required this.contentLength,
    this.modifiedAt,
    this.etag,
  });

  final String href;
  final String displayName;
  final bool isCollection;
  final int contentLength;
  final DateTime? modifiedAt;
  final String? etag;
}

class WebDavDiscoveryService {
  WebDavDiscoveryService({
    http.Client Function()? clientFactory,
    this.allowBadCertificate = false,
  }) : _clientFactory = clientFactory ?? _createDefaultClient;

  /// When true, self-signed and otherwise untrusted TLS certificates are
  /// accepted. Intended for home NAS servers.
  final bool allowBadCertificate;

  static http.Client _createDefaultClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    return IOClient(httpClient);
  }

  static http.Client _createLenientClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (_, _, _) => true;
    return IOClient(httpClient);
  }

  static const _requestTimeout = Duration(seconds: 10);
  static const _maxDiscoveryBodyBytes = 4 * 1024 * 1024;

  final http.Client Function() _clientFactory;

  Future<WebDavDiscoveryResult> probe(
    String url, {
    required WebDavCredentials credentials,
  }) async {
    final client = allowBadCertificate
        ? _createLenientClient()
        : _clientFactory();
    try {
      final uri = Uri.parse(url);
      final optionsResult = await _options(client, uri, credentials);
      if (optionsResult.error != null) return optionsResult;
      return await _propfind(
        client,
        uri,
        credentials,
        optionsResult.capabilities,
      );
    } on TimeoutException catch (error) {
      debugPrint('WebDAV discovery timeout: $url\n${error.toString()}');
      return WebDavDiscoveryResult.error(
        WebDavConnectionError.unreachable,
        message: '连接超时',
      );
    } on http.ClientException catch (error) {
      debugPrint('WebDAV discovery client error: $url\n${error.toString()}');
      final message = _userFriendlyError(error);
      return WebDavDiscoveryResult.error(
        WebDavConnectionError.unreachable,
        message: message,
      );
    } on FormatException catch (error) {
      debugPrint('WebDAV discovery format error: $url\n${error.toString()}');
      return WebDavDiscoveryResult.error(
        WebDavConnectionError.unknown,
        message: '服务器响应格式无法识别',
      );
    } on TlsException catch (error) {
      debugPrint('WebDAV discovery TLS error: $url\n${error.toString()}');
      return WebDavDiscoveryResult.error(
        WebDavConnectionError.unreachable,
        message: _tlsFriendlyMessage(error),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'WebDAV discovery unexpected error: $url\n'
        '${error.toString()}\n$stackTrace',
      );
      return WebDavDiscoveryResult.error(
        WebDavConnectionError.unknown,
        message: _userFriendlyError(error),
      );
    } finally {
      client.close();
    }
  }

  Future<WebDavDiscoveryResult> _options(
    http.Client client,
    Uri uri,
    WebDavCredentials credentials,
  ) async {
    final request = http.Request('OPTIONS', uri);
    _applyCredentials(request, credentials);
    final response = await client.send(request).timeout(_requestTimeout);
    final statusCode = response.statusCode;

    if (statusCode == 401 || statusCode == 403) {
      await response.stream.drain<void>();
      debugPrint('WebDAV OPTIONS auth failed: $uri → HTTP $statusCode');
      return WebDavDiscoveryResult.error(
        WebDavConnectionError.authenticationFailed,
        message: '认证失败（HTTP $statusCode）',
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      await response.stream.drain<void>();
      debugPrint('WebDAV OPTIONS non-2xx: $uri → HTTP $statusCode');
      return WebDavDiscoveryResult.error(
        statusCode >= 500
            ? WebDavConnectionError.unreachable
            : WebDavConnectionError.notAWebDavServer,
        message: 'OPTIONS 请求失败（HTTP $statusCode）',
      );
    }

    final davHeader = _header(response.headers, 'dav') ?? '';
    final allowHeader = _header(response.headers, 'allow') ?? '';
    await response.stream.drain<void>();
    final davCapabilities = davHeader
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (davCapabilities.isEmpty) {
      return WebDavDiscoveryResult.error(
        WebDavConnectionError.notAWebDavServer,
        message: '服务器未声明 DAV 能力',
      );
    }

    return WebDavDiscoveryResult(
      status: DiscoveryStatus.success,
      capabilities: [
        ...davCapabilities,
        if (allowHeader.isNotEmpty) allowHeader,
      ],
    );
  }

  Future<WebDavDiscoveryResult> _propfind(
    http.Client client,
    Uri uri,
    WebDavCredentials credentials,
    List<String> capabilities,
  ) async {
    final request = http.Request('PROPFIND', uri)
      ..headers['Depth'] = '1'
      ..headers['Content-Type'] = 'application/xml; charset=utf-8'
      ..body = _propfindBody;
    _applyCredentials(request, credentials);
    final response = await client.send(request).timeout(_requestTimeout);

    if (response.statusCode == 401 || response.statusCode == 403) {
      await response.stream.drain<void>();
      debugPrint(
        'WebDAV PROPFIND auth failed: $uri → HTTP ${response.statusCode}',
      );
      return WebDavDiscoveryResult.error(
        WebDavConnectionError.authenticationFailed,
        message: '认证失败（HTTP ${response.statusCode}）',
      );
    }
    if (response.statusCode != 207) {
      await response.stream.drain<void>();
      debugPrint('WebDAV PROPFIND non-207: $uri → HTTP ${response.statusCode}');
      return WebDavDiscoveryResult.error(
        response.statusCode >= 500
            ? WebDavConnectionError.unreachable
            : WebDavConnectionError.notAWebDavServer,
        message: 'PROPFIND 未返回 Multi-Status（HTTP ${response.statusCode}）',
      );
    }

    final body = await _readBody(response).timeout(_requestTimeout);
    return WebDavDiscoveryResult(
      status: DiscoveryStatus.success,
      capabilities: capabilities,
      files: _parsePropfindResponse(body),
    );
  }

  void _applyCredentials(
    http.BaseRequest request,
    WebDavCredentials credentials,
  ) {
    if (!credentials.isEmpty) {
      request.headers['Authorization'] = credentials.basicHeaderValue;
    }
  }

  String? _header(Map<String, String> headers, String name) {
    final normalizedName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == normalizedName) return entry.value;
    }
    return null;
  }

  Future<String> _readBody(http.StreamedResponse response) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > _maxDiscoveryBodyBytes) {
        throw const FormatException('PROPFIND 响应超过 4 MiB 限制');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  List<WebDavFileEntry> _parsePropfindResponse(String source) {
    final document = XmlDocument.parse(source);
    final entries = <WebDavFileEntry>[];
    for (final response in _elementsNamed(document, 'response')) {
      final href = _firstText(response, 'href');
      if (href == null || href.isEmpty) continue;

      final successfulPropstats = _elementsNamed(response, 'propstat')
          .where(
            (element) =>
                _firstText(element, 'status')?.contains(' 200 ') == true,
          )
          .toList(growable: false);
      // A valid WebDAV response may split requested properties across more
      // than one successful propstat. Looking only at the first one can drop
      // getcontentlength/getlastmodified and prevents incremental scans.
      final propertyScopes = successfulPropstats.isEmpty
          ? <XmlNode>[response]
          : <XmlNode>[...successfulPropstats];
      final displayName = _firstTextFrom(propertyScopes, 'displayname');
      final isCollection = propertyScopes.any(
        (scope) => _elementsNamed(scope, 'collection').isNotEmpty,
      );
      final contentLength = int.tryParse(
        _firstTextFrom(propertyScopes, 'getcontentlength') ?? '',
      );
      final modifiedAt = _parseHttpDate(
        _firstTextFrom(propertyScopes, 'getlastmodified'),
      );
      final etag = _normalizedOptionalText(
        _firstTextFrom(propertyScopes, 'getetag'),
      );

      entries.add(
        WebDavFileEntry(
          href: href,
          displayName:
              displayName ??
              Uri.tryParse(
                href,
              )?.pathSegments.where((s) => s.isNotEmpty).lastOrNull ??
              href,
          isCollection: isCollection,
          contentLength: contentLength ?? -1,
          modifiedAt: modifiedAt,
          etag: etag,
        ),
      );
    }
    return entries;
  }

  Iterable<XmlElement> _elementsNamed(XmlNode node, String localName) {
    return node.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == localName,
    );
  }

  String? _firstText(XmlNode node, String localName) {
    return _elementsNamed(node, localName).firstOrNull?.innerText.trim();
  }

  String? _firstTextFrom(Iterable<XmlNode> nodes, String localName) {
    for (final node in nodes) {
      final value = _firstText(node, localName);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  DateTime? _parseHttpDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return HttpDate.parse(value).toUtc();
    } on FormatException {
      return null;
    }
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String _tlsFriendlyMessage(TlsException error) {
    final text = error.message.toLowerCase();
    if (text.contains('certificate') &&
        (text.contains('verify') || text.contains('unknown'))) {
      return '服务器使用的是自签名证书，请勾选「允许自签名证书」后重试';
    }
    if (text.contains('handshake')) {
      return '无法建立安全连接，请确认服务器地址以 https 开头，或者服务器可能未启用 SSL';
    }
    return 'SSL/TLS 连接失败：${error.message}';
  }

  static String _userFriendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('connection refused')) return '无法连接到服务器，请检查地址和端口是否正确';
    if (text.contains('host') && text.contains('not found')) {
      return '找不到服务器地址，请检查 URL 是否正确';
    }
    if (text.contains('timeout')) return '连接超时，请检查网络或服务器是否在线';
    if (text.contains('certificate')) return '服务器证书不被信任，请勾选「允许自签名证书」';
    return '连接失败，请检查地址和网络';
  }
}

const _propfindBody = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:displayname/>
    <d:resourcetype/>
    <d:getcontentlength/>
    <d:getlastmodified/>
    <d:getetag/>
  </d:prop>
</d:propfind>''';
