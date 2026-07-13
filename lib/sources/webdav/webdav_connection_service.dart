import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../library/library_records.dart';
import '../../library/library_repository.dart';
import 'webdav_credentials.dart';
import 'webdav_discovery.dart';

class WebDavConnectionRecord {
  const WebDavConnectionRecord({
    required this.id,
    required this.url,
    required this.displayName,
    required this.status,
    required this.allowBadCertificate,
    this.lastError,
    this.lastProbedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String url;
  final String displayName;
  final WebDavConnectionStatus status;
  final bool allowBadCertificate;
  final String? lastError;
  final DateTime? lastProbedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAvailable => status == WebDavConnectionStatus.connected;
}

enum WebDavConnectionStatus {
  idle,
  probing,
  connected,
  unreachable,
  authenticationFailed,
  error,
}

class WebDavConnectionService {
  WebDavConnectionService({
    required this.repository,
    WebDavDiscoveryService? discovery,
    WebDavCredentialStore? credentialStore,
  }) : discovery = discovery ?? WebDavDiscoveryService(),
       credentialStore = credentialStore ?? SecureWebDavCredentialStore();

  final LibraryRepository repository;
  final WebDavDiscoveryService discovery;
  final WebDavCredentialStore credentialStore;

  static const _connectionIdPrefix = 'webdav:';
  static const _folderIdPrefix = 'webdav-folder:';

  Stream<List<WebDavConnectionRecord>> watchConnections() {
    return repository.watchSources().map(
      (sources) => sources
          .where(_isConnectionSource)
          .map(_recordFromSource)
          .toList(growable: false),
    );
  }

  Stream<List<WebDavConnectionRecord>> watchManagedSources() {
    return repository.watchSources().map(
      (sources) => sources
          .where((source) => source.type == LibrarySourceType.webDav)
          .map(_recordFromSource)
          .toList(growable: false),
    );
  }

  Future<List<WebDavConnectionRecord>> listConnections() async {
    final sources = await repository.getSources();
    return sources
        .where(_isConnectionSource)
        .map(_recordFromSource)
        .toList(growable: false);
  }

  Future<WebDavConnectionRecord?> resolveParentConnection(
    WebDavConnectionRecord folderSource,
  ) async {
    final connections = await listConnections();
    final encodedParent = connections
        .where(
          (connection) =>
              isFolderSourceForConnection(folderSource.id, connection.id),
        )
        .firstOrNull;
    if (encodedParent != null) return encodedParent;

    // Early development builds used random folder IDs, so those records do
    // not contain the connection hash. Recover their parent from the indexed
    // media origins, or from the only configured connection when unambiguous.
    final tracks = await repository.getTracks(sourceId: folderSource.id);
    final originMatches = connections
        .where(
          (connection) => tracks.any(
            (track) =>
                _mediaBelongsToConnection(track.mediaUri, connection.url),
          ),
        )
        .toList(growable: false);
    if (originMatches.length == 1) return originMatches.single;
    if (connections.length == 1) return connections.single;
    return null;
  }

  Future<WebDavCredentials?> readCredentials(String connectionId) {
    return credentialStore.read(connectionId);
  }

  Future<WebDavDiscoveryResult> addConnection({
    required String url,
    required String displayName,
    required WebDavCredentials credentials,
    bool allowBadCertificate = false,
  }) async {
    final normalizedUrl = normalizeWebDavUrl(url);
    final id = stableWebDavConnectionId(normalizedUrl);
    final existing = await repository.getSource(id);
    return _writeCredentialsWithRollback(id, credentials, () async {
      await _persistProbeStart(
        existing: existing,
        id: id,
        url: normalizedUrl,
        displayName: displayName,
        allowBadCertificate: allowBadCertificate,
      );
      return _probeAndFinish(
        existing: existing,
        id: id,
        url: normalizedUrl,
        displayName: displayName,
        credentials: credentials,
        allowBadCertificate: allowBadCertificate,
      );
    });
  }

  Future<WebDavDiscoveryResult> updateConnection({
    required WebDavConnectionRecord connection,
    required String url,
    required String displayName,
    required WebDavCredentials credentials,
    bool allowBadCertificate = false,
  }) async {
    final existing = await repository.getSource(connection.id);
    if (existing == null || existing.type != LibrarySourceType.webDav) {
      throw StateError('Unknown WebDAV connection: ${connection.id}');
    }
    final normalizedUrl = normalizeWebDavUrl(url);
    return _writeCredentialsWithRollback(connection.id, credentials, () async {
      await _persistProbeStart(
        existing: existing,
        id: connection.id,
        url: normalizedUrl,
        displayName: displayName,
        allowBadCertificate: allowBadCertificate,
      );
      return _probeAndFinish(
        existing: existing,
        id: connection.id,
        url: normalizedUrl,
        displayName: displayName,
        credentials: credentials,
        allowBadCertificate: allowBadCertificate,
      );
    });
  }

  Future<WebDavDiscoveryResult> probeConnection(
    WebDavConnectionRecord connection, {
    bool allowBadCertificate = false,
  }) async {
    final source = await repository.getSource(connection.id);
    if (source == null || source.type != LibrarySourceType.webDav) {
      throw StateError('Unknown WebDAV connection: ${connection.id}');
    }
    final credentials = await credentialStore.read(connection.id);
    if (credentials == null) {
      final result = WebDavDiscoveryResult.error(
        WebDavConnectionError.authenticationFailed,
        message: '安全存储中缺少连接凭据',
      );
      await _persistProbeResult(
        result,
        DateTime.now().toUtc(),
        existing: source,
        id: source.id,
        url: source.rootUri,
        displayName: source.displayName,
        allowBadCertificate: allowBadCertificate,
      );
      return result;
    }
    await _persistProbeStart(
      existing: source,
      id: source.id,
      url: source.rootUri,
      displayName: source.displayName,
      allowBadCertificate: allowBadCertificate,
    );
    return _probeAndFinish(
      existing: source,
      id: source.id,
      url: source.rootUri,
      displayName: source.displayName,
      credentials: credentials,
      allowBadCertificate: allowBadCertificate,
    );
  }

  Future<void> removeConnection(String id) async {
    if (id.startsWith(_connectionIdPrefix)) {
      final sources = await repository.getSources();
      for (final source in sources.where(
        (source) => isFolderSourceForConnection(source.id, id),
      )) {
        await repository.deleteSource(source.id);
      }
    }
    await repository.deleteSource(id);
    await credentialStore.delete(id);
  }

  static String stableWebDavFolderSourceId(
    String connectionId,
    String folderPath,
  ) {
    final connectionKey = sha256.convert(utf8.encode(connectionId));
    final folderKey = sha256.convert(utf8.encode(folderPath));
    return '$_folderIdPrefix$connectionKey:$folderKey';
  }

  static bool isFolderSourceForConnection(
    String sourceId,
    String connectionId,
  ) {
    final connectionKey = sha256.convert(utf8.encode(connectionId));
    return sourceId.startsWith('$_folderIdPrefix$connectionKey:');
  }

  static bool _mediaBelongsToConnection(String mediaUrl, String baseUrl) {
    final media = Uri.tryParse(mediaUrl);
    final base = Uri.tryParse(baseUrl);
    if (media == null || base == null || !media.hasScheme || !base.hasScheme) {
      return false;
    }
    if (media.scheme.toLowerCase() != base.scheme.toLowerCase() ||
        media.host.toLowerCase() != base.host.toLowerCase() ||
        media.port != base.port) {
      return false;
    }
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    return media.path == base.path || media.path.startsWith(basePath);
  }

  Future<T> _writeCredentialsWithRollback<T>(
    String id,
    WebDavCredentials credentials,
    Future<T> Function() persist,
  ) async {
    final previous = await credentialStore.read(id);
    await credentialStore.write(id, credentials);
    try {
      return await persist();
    } catch (_) {
      if (previous == null) {
        await credentialStore.delete(id);
      } else {
        await credentialStore.write(id, previous);
      }
      rethrow;
    }
  }

  Future<void> _persistProbeStart({
    required LibrarySourceRecord? existing,
    required String id,
    required String url,
    required String displayName,
    bool allowBadCertificate = false,
  }) async {
    final now = DateTime.now().toUtc();
    await repository.upsertSource(
      _sourceRecord(
        existing: existing,
        id: id,
        url: url,
        displayName: displayName,
        status: LibrarySourceStatus.scanning,
        lastError: null,
        updatedAt: now,
        allowBadCertificate: allowBadCertificate,
      ),
    );
  }

  Future<WebDavDiscoveryResult> _probeAndFinish({
    required LibrarySourceRecord? existing,
    required String id,
    required String url,
    required String displayName,
    required WebDavCredentials credentials,
    bool allowBadCertificate = false,
  }) async {
    final effectiveDiscovery = allowBadCertificate
        ? WebDavDiscoveryService(allowBadCertificate: true)
        : discovery;
    final result = await effectiveDiscovery.probe(
      url,
      credentials: credentials,
    );
    final current = await repository.getSource(id) ?? existing;
    await _persistProbeResult(
      result,
      DateTime.now().toUtc(),
      existing: current,
      id: id,
      url: url,
      displayName: displayName,
      allowBadCertificate: allowBadCertificate,
    );
    return result;
  }

  Future<void> _persistProbeResult(
    WebDavDiscoveryResult result,
    DateTime now, {
    required LibrarySourceRecord? existing,
    required String id,
    required String url,
    required String displayName,
    bool allowBadCertificate = false,
  }) async {
    final status = result.error == null
        ? WebDavConnectionStatus.connected
        : switch (result.error!) {
            WebDavConnectionError.unreachable =>
              WebDavConnectionStatus.unreachable,
            WebDavConnectionError.authenticationFailed =>
              WebDavConnectionStatus.authenticationFailed,
            WebDavConnectionError.notAWebDavServer ||
            WebDavConnectionError.unknown => WebDavConnectionStatus.error,
          };
    await repository.upsertSource(
      _sourceRecord(
        existing: existing,
        id: id,
        url: url,
        displayName: displayName,
        status: _toSourceStatus(status),
        lastError: result.errorMessage,
        updatedAt: now,
        allowBadCertificate: allowBadCertificate,
      ),
    );
  }

  static LibrarySourceRecord _sourceRecord({
    required LibrarySourceRecord? existing,
    required String id,
    required String url,
    required String displayName,
    required LibrarySourceStatus status,
    required String? lastError,
    required DateTime updatedAt,
    bool allowBadCertificate = false,
  }) {
    return LibrarySourceRecord(
      id: id,
      type: LibrarySourceType.webDav,
      displayName: displayName.trim(),
      rootUri: url,
      permissionBookmark: allowBadCertificate
          ? Uint8List.fromList(utf8.encode('allowBadCert'))
          : null,
      status: status,
      scanRevision: existing?.scanRevision ?? 0,
      lastScanStartedAt: existing?.lastScanStartedAt,
      lastScanCompletedAt: existing?.lastScanCompletedAt,
      lastError: lastError,
      createdAt: existing?.createdAt ?? updatedAt,
      updatedAt: updatedAt,
    );
  }

  static bool _isBadCertAllowed(Uint8List? permissionBookmark) {
    return permissionBookmark != null &&
        utf8.decode(permissionBookmark) == 'allowBadCert';
  }

  static String normalizeWebDavUrl(String value) {
    final uri = Uri.parse(value.trim());
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
      throw const FormatException('WebDAV 地址必须是有效的 HTTP(S) URL');
    }
    if (uri.userInfo.isNotEmpty) {
      throw const FormatException('请使用用户名和密码字段，不要把凭据写在 URL 中');
    }
    if (uri.fragment.isNotEmpty) {
      throw const FormatException('WebDAV 地址不能包含片段标识');
    }
    final defaultPort =
        (scheme == 'http' && uri.port == 80) ||
        (scheme == 'https' && uri.port == 443);
    final path = uri.path.isEmpty
        ? '/'
        : uri.path.endsWith('/')
        ? uri.path
        : '${uri.path}/';
    final baseUri = Uri(
      scheme: scheme,
      host: uri.host.toLowerCase(),
      path: path,
      query: uri.hasQuery ? uri.query : null,
    );
    if (!uri.hasPort || defaultPort) return baseUri.toString();
    return baseUri.replace(port: uri.port).toString();
  }

  static String stableWebDavConnectionId(String url) {
    final normalized = normalizeWebDavUrl(url);
    return 'webdav:${sha256.convert(utf8.encode(normalized))}';
  }

  static bool _isConnectionSource(LibrarySourceRecord source) {
    return source.type == LibrarySourceType.webDav &&
        source.id.startsWith(_connectionIdPrefix);
  }

  static WebDavConnectionRecord _recordFromSource(LibrarySourceRecord source) {
    return WebDavConnectionRecord(
      id: source.id,
      url: source.rootUri,
      displayName: source.displayName,
      status: _toConnectionStatus(source.status),
      allowBadCertificate: _isBadCertAllowed(source.permissionBookmark),
      lastError: source.lastError,
      lastProbedAt: source.updatedAt,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
    );
  }

  static LibrarySourceStatus _toSourceStatus(WebDavConnectionStatus status) {
    return switch (status) {
      WebDavConnectionStatus.idle => LibrarySourceStatus.idle,
      WebDavConnectionStatus.probing => LibrarySourceStatus.scanning,
      WebDavConnectionStatus.connected => LibrarySourceStatus.available,
      WebDavConnectionStatus.authenticationFailed =>
        LibrarySourceStatus.permissionRequired,
      WebDavConnectionStatus.unreachable => LibrarySourceStatus.unavailable,
      WebDavConnectionStatus.error => LibrarySourceStatus.error,
    };
  }

  static WebDavConnectionStatus _toConnectionStatus(
    LibrarySourceStatus status,
  ) {
    return switch (status) {
      LibrarySourceStatus.idle => WebDavConnectionStatus.idle,
      LibrarySourceStatus.scanning => WebDavConnectionStatus.probing,
      LibrarySourceStatus.available => WebDavConnectionStatus.connected,
      LibrarySourceStatus.permissionRequired =>
        WebDavConnectionStatus.authenticationFailed,
      LibrarySourceStatus.unavailable => WebDavConnectionStatus.unreachable,
      LibrarySourceStatus.error => WebDavConnectionStatus.error,
    };
  }
}
