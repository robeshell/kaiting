import '../../library/library_records.dart';
import '../source_provider.dart';
import 'webdav_connection_service.dart';
import 'webdav_source_directory_browser.dart';

class WebDavSourceConnectionProvider implements SourceConnectionProvider {
  const WebDavSourceConnectionProvider(this.service);

  final WebDavConnectionService service;

  @override
  LibrarySourceType get type => LibrarySourceType.webDav;

  @override
  Stream<List<SourceManagedResource>> watchResources() {
    return service.watchManagedSources().map((resources) {
      final connections = resources
          .where(
            (resource) =>
                WebDavConnectionService.isConnectionSourceId(resource.id),
          )
          .toList(growable: false);
      return resources
          .map(
            (resource) => _mapResource(
              resource,
              parentConnectionId: _parentConnectionId(resource, connections),
            ),
          )
          .toList(growable: false);
    });
  }

  @override
  Future<SourceManagedResource> probe(String connectionId) async {
    final connection = await service.getManagedSource(connectionId);
    if (connection == null ||
        !WebDavConnectionService.isConnectionSourceId(connection.id)) {
      throw StateError('WebDAV connection is unavailable: $connectionId');
    }
    await service.probeConnection(
      connection,
      allowBadCertificate: connection.allowBadCertificate,
    );
    final updated = await service.getManagedSource(connectionId);
    if (updated == null) {
      throw StateError('WebDAV connection disappeared: $connectionId');
    }
    return _mapResource(updated);
  }

  @override
  Future<SourceDirectoryBrowser> openBrowser(String connectionId) async {
    final connection = await service.getManagedSource(connectionId);
    if (connection == null ||
        !WebDavConnectionService.isConnectionSourceId(connection.id)) {
      throw StateError('WebDAV connection is unavailable: $connectionId');
    }
    return WebDavSourceDirectoryBrowser.forConnection(
      service: service,
      connection: connection,
    );
  }

  @override
  Future<void> remove(String resourceId) =>
      service.removeConnection(resourceId);

  String? _parentConnectionId(
    WebDavConnectionRecord resource,
    List<WebDavConnectionRecord> connections,
  ) {
    if (WebDavConnectionService.isConnectionSourceId(resource.id)) return null;
    for (final connection in connections) {
      if (WebDavConnectionService.isFolderSourceForConnection(
        resource.id,
        connection.id,
      )) {
        return connection.id;
      }
    }
    // Early builds used folder IDs without the connection hash. Preserve a
    // useful hierarchy when there is only one possible owner.
    if (connections.length == 1) return connections.single.id;
    return null;
  }

  SourceManagedResource _mapResource(
    WebDavConnectionRecord resource, {
    String? parentConnectionId,
  }) {
    return SourceManagedResource(
      id: resource.id,
      type: type,
      kind: WebDavConnectionService.isConnectionSourceId(resource.id)
          ? SourceManagedResourceKind.connection
          : SourceManagedResourceKind.catalog,
      displayName: resource.displayName,
      location: resource.url,
      status: switch (resource.status) {
        WebDavConnectionStatus.idle => SourceManagedStatus.idle,
        WebDavConnectionStatus.probing => SourceManagedStatus.working,
        WebDavConnectionStatus.connected => SourceManagedStatus.available,
        WebDavConnectionStatus.authenticationFailed =>
          SourceManagedStatus.authenticationFailed,
        WebDavConnectionStatus.unreachable => SourceManagedStatus.unavailable,
        WebDavConnectionStatus.error => SourceManagedStatus.error,
      },
      parentConnectionId: parentConnectionId,
      errorMessage: resource.lastError,
    );
  }
}
