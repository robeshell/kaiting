import 'dart:async';

import '../../library/library_records.dart';
import '../source_provider.dart';
import 'webdav_connection_service.dart';
import 'webdav_folder_scanner.dart';

class WebDavSourceScanProvider implements SourceScanProvider {
  WebDavSourceScanProvider({
    required this.connectionService,
    required this.scanner,
  });

  final WebDavConnectionService connectionService;
  final WebDavFolderScanner scanner;

  @override
  LibrarySourceType get type => LibrarySourceType.webDav;

  @override
  bool isScanning(String sourceId) => scanner.isScanning(sourceId);

  @override
  bool cancel(String sourceId) => scanner.cancel(sourceId);

  final _progressControllers = <String, StreamController<ScanProgress>>{};

  @override
  Stream<ScanProgress> watchProgress(String sourceId) {
    final existing = _progressControllers[sourceId];
    if (existing != null) return existing.stream;
    final controller = StreamController<ScanProgress>.broadcast();
    _progressControllers[sourceId] = controller;
    return controller.stream;
  }

  @override
  Future<SourceScanSummary> rescan(String sourceId) async {
    try {
      final source = await connectionService.getManagedSource(sourceId);
      if (source == null ||
          WebDavConnectionService.isConnectionSourceId(source.id)) {
        throw StateError('WebDAV folder source is unavailable: $sourceId');
      }
      final parent = await connectionService.resolveParentConnection(source);
      if (parent == null) {
        throw StateError('找不到父级 WebDAV 连接');
      }
      final credentials = await connectionService.readCredentials(parent.id);
      if (credentials == null) {
        throw StateError('无法读取连接凭据');
      }
      final report = await scanner.scan(
        connectionId: parent.id,
        folderUrls: [source.url],
        baseUrl: parent.url,
        credentials: credentials,
        allowBadCertificate: parent.allowBadCertificate,
        existingSourceId: source.id,
        onProgress: (progress) {
          _progressControllers[sourceId]?.add(progress);
        },
      );
      return _summary(report);
    } finally {
      await _progressControllers.remove(sourceId)?.close();
    }
  }

  Future<SourceScanSummary> scanFolders({
    required String connectionId,
    required List<String> folderUrls,
  }) async {
    try {
      final connection = await connectionService.getManagedSource(connectionId);
      if (connection == null ||
          !WebDavConnectionService.isConnectionSourceId(connection.id)) {
        throw StateError('WebDAV connection is unavailable: $connectionId');
      }
      final credentials = await connectionService.readCredentials(
        connection.id,
      );
      if (credentials == null) {
        throw StateError('无法读取连接凭据');
      }
      final report = await scanner.scan(
        connectionId: connection.id,
        folderUrls: folderUrls,
        baseUrl: connection.url,
        credentials: credentials,
        allowBadCertificate: connection.allowBadCertificate,
        onProgress: (progress) {
          _progressControllers[connectionId]?.add(progress);
        },
      );
      return _summary(report);
    } finally {
      await _progressControllers.remove(connectionId)?.close();
    }
  }
}

SourceScanSummary _summary(WebDavFolderScanResult report) {
  return SourceScanSummary(
    indexedTracks: report.indexedTracks,
    skippedFiles: report.skippedFiles,
    addedTracks: report.addedTracks,
    modifiedTracks: report.modifiedTracks,
    movedTracks: report.movedTracks,
    removedTracks: report.removedTracks,
    unchangedTracks: report.unchangedTracks,
    warnings: report.warnings,
  );
}
