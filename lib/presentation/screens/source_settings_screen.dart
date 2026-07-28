import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../library/library_records.dart';
import '../../library/scanning/local_library_scanner.dart';
import '../../library/scanning/scan_cancellation.dart';
import '../../sources/local/local_source_scan_provider.dart';
import '../../sources/local/local_source_service.dart';
import '../../sources/source_provider.dart';
import '../../sources/webdav/webdav_connection_service.dart';
import '../../sources/webdav/webdav_discovery.dart';
import '../../library/scanning/artwork_store.dart';
import '../../sources/webdav/webdav_folder_scanner.dart';
import '../../sources/webdav/webdav_source_connection_provider.dart';
import '../../sources/webdav/webdav_source_scan_provider.dart';
import '../widgets/sound_components.dart';
import '../widgets/settings_components.dart';
import 'webdav_add_dialog.dart';
import 'webdav_folder_picker.dart';

typedef SourceEditorCallback =
    Future<void> Function(
      BuildContext context,
      SourceManagedResource? resource,
    );
typedef SourceDirectoryScanCallback =
    Future<SourceScanSummary> Function(
      String connectionId,
      List<String> directoryIds,
    );

Color _sourcePrimaryText(BuildContext context) => context.settingsPrimary;

Color _sourceSecondaryText(BuildContext context) => context.settingsSecondary;

class RemoteSourceSettingsAdapter {
  const RemoteSourceSettingsAdapter({
    required this.definition,
    required this.connections,
    required this.scanner,
    required this.openEditor,
    required this.scanDirectories,
    required this.color,
    required this.connectionIcon,
    required this.catalogIcon,
  });

  final SourceProviderDefinition definition;
  final SourceConnectionProvider connections;
  final SourceScanProvider scanner;
  final SourceEditorCallback openEditor;
  final SourceDirectoryScanCallback scanDirectories;
  final Color color;
  final IconData connectionIcon;
  final IconData catalogIcon;
}

class SourceSettingsScreen extends StatefulWidget {
  const SourceSettingsScreen({
    required this.localSources,
    required this.scanner,
    this.webDavService,
    this.sourceProviders,
    this.remoteAdapters,
    this.onBack,
    super.key,
  });

  final LocalSourceService localSources;
  final LocalLibraryScanner scanner;
  final WebDavConnectionService? webDavService;
  final SourceProviderRegistry? sourceProviders;
  final List<RemoteSourceSettingsAdapter>? remoteAdapters;
  final VoidCallback? onBack;

  @override
  State<SourceSettingsScreen> createState() => _SourceSettingsScreenState();
}

class _SourceSettingsScreenState extends State<SourceSettingsScreen> {
  bool _addingSource = false;
  final Set<String> _scanningSourceIds = {};
  late final LocalSourceScanProvider _localScanProvider;
  late final WebDavSourceScanProvider? _webDavScanProvider;
  late final WebDavSourceConnectionProvider? _webDavConnectionProvider;
  late final List<RemoteSourceSettingsAdapter> _remoteAdapters;
  late final SourceScanProviderRegistry _scanProviders;
  late final SourceConnectionProviderRegistry _connectionProviders;

  SourceProviderRegistry get _sourceProviders =>
      widget.sourceProviders ?? builtInSourceProviders;

  @override
  void initState() {
    super.initState();
    _localScanProvider = LocalSourceScanProvider(
      sourceService: widget.localSources,
      scanner: widget.scanner,
    );
    final webDav = widget.webDavService;
    _webDavScanProvider = webDav == null
        ? null
        : WebDavSourceScanProvider(
            connectionService: webDav,
            scanner: WebDavFolderScanner(
              repository: webDav.repository,
              artworkStore: FileArtworkStore(),
            ),
          );
    _webDavConnectionProvider = webDav == null
        ? null
        : WebDavSourceConnectionProvider(webDav);
    final webDavDefinition = _sourceProviders.providerFor(
      LibrarySourceType.webDav,
    );
    _remoteAdapters =
        widget.remoteAdapters ??
        [
          if (_webDavConnectionProvider case final connections?)
            RemoteSourceSettingsAdapter(
              definition:
                  webDavDefinition ??
                  const SourceProviderDefinition(
                    type: LibrarySourceType.webDav,
                    displayName: 'WebDAV',
                    addActionLabel: '添加 WebDAV',
                    sectionDescription: '服务器连接和已加入资料库的远程目录',
                    capabilities: {
                      SourceProviderCapability.connectionManagement,
                      SourceProviderCapability.directoryBrowsing,
                      SourceProviderCapability.scanning,
                    },
                  ),
              connections: connections,
              scanner: _webDavScanProvider!,
              openEditor: _openWebDavEditor,
              scanDirectories: (connectionId, directoryIds) =>
                  _webDavScanProvider.scanFolders(
                    connectionId: connectionId,
                    folderUrls: directoryIds,
                  ),
              color: SoundColors.webDav,
              connectionIcon: KaitingIcons.cloudFilled,
              catalogIcon: KaitingIcons.folderFilled,
            ),
        ];
    _scanProviders = SourceScanProviderRegistry([
      _localScanProvider,
      for (final adapter in _remoteAdapters) adapter.scanner,
    ]);
    _connectionProviders = SourceConnectionProviderRegistry([
      for (final adapter in _remoteAdapters) adapter.connections,
    ]);
    unawaited(widget.localSources.restoreLocalFolders());
  }

  Future<void> _addLocalSource() async {
    if (_addingSource) return;
    setState(() => _addingSource = true);
    try {
      final source = await widget.localSources.addLocalFolder();
      if (source != null && source.status == LibrarySourceStatus.available) {
        await _scanSource(source.type, source.id);
      }
    } catch (error) {
      if (!mounted) return;
      showSoundSnackBar(context, '无法添加文件夹：$error');
    } finally {
      if (mounted) setState(() => _addingSource = false);
    }
  }

  Future<void> _removeLocalSource(LibrarySourceRecord source) async {
    try {
      await widget.localSources.removeLocalFolder(source);
    } catch (error) {
      if (!mounted) return;
      showSoundSnackBar(context, '无法移除文件夹：$error');
    }
  }

  Future<void> _scanSource(LibrarySourceType type, String sourceId) async {
    if (!_scanningSourceIds.add(sourceId)) return;
    setState(() {});
    try {
      final report = await _scanProviders
          .requireProvider(type)
          .rescan(sourceId);
      if (!mounted) return;
      final skipped = report.skippedFiles == 0
          ? ''
          : '，跳过 ${report.skippedFiles} 个文件';
      final changes = [
        if (report.addedTracks > 0) '新增 ${report.addedTracks}',
        if (report.modifiedTracks > 0) '更新 ${report.modifiedTracks}',
        if (report.movedTracks > 0) '移动 ${report.movedTracks}',
        if (report.removedTracks > 0) '移除 ${report.removedTracks}',
      ];
      final changeSummary = changes.isEmpty
          ? '，没有文件变化'
          : '，${changes.join('、')}';
      showSoundSnackBar(
        context,
        '已索引 ${report.indexedTracks} 首歌曲$changeSummary$skipped'
        '${_scanWarningSuffix(report)}',
      );
    } on ScanCancelledException {
      if (!mounted) return;
      showSoundSnackBar(context, '扫描已取消，原资料库保持不变');
    } catch (error) {
      if (!mounted) return;
      showSoundSnackBar(context, '扫描失败：$error');
    } finally {
      _scanningSourceIds.remove(sourceId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _addWebDavSource() async {
    final webDav = widget.webDavService;
    if (webDav == null) return;
    final result = await _showWebDavEditor(webDav);
    if (result != null && mounted) {
      final fileCount = result.files.where((f) => !f.isCollection).length;
      final dirCount = result.files.where((f) => f.isCollection).length;
      var msg = 'WebDAV 服务器已连接';
      if (fileCount > 0) msg += '，发现 $fileCount 个文件、$dirCount 个目录';
      showSoundSnackBar(context, msg);
    }
  }

  Future<void> _openWebDavEditor(
    BuildContext context,
    SourceManagedResource? resource,
  ) {
    return resource == null ? _addWebDavSource() : _editWebDavSource(resource);
  }

  Future<void> _removeRemoteSource(
    RemoteSourceSettingsAdapter adapter,
    SourceManagedResource resource,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SoundDialog(
        maxWidth: 460,
        title: Text(
          resource.kind == SourceManagedResourceKind.connection
              ? '移除${adapter.definition.displayName}连接'
              : '移除${adapter.definition.displayName}目录',
        ),
        content: Text(
          resource.kind == SourceManagedResourceKind.connection
              ? '确定要移除「${resource.displayName}」吗？'
              : '确定要移除「${resource.displayName}」吗？\n资料库中对应的歌曲也会被移除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: context.soundDestructiveButtonStyle,
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _connectionProviders
            .requireProvider(resource.type)
            .remove(resource.id);
      } catch (error) {
        if (!mounted) return;
        showSoundSnackBar(context, '移除失败：$error');
      }
    }
  }

  Future<void> _editWebDavSource(SourceManagedResource resource) async {
    final webDav = widget.webDavService;
    if (webDav == null) return;
    final connection = await webDav.getManagedSource(resource.id);
    if (connection == null || !mounted) return;
    final result = await _showWebDavEditor(webDav, connection: connection);
    if (result != null && mounted) {
      final message = result.error == null
          ? 'WebDAV 连接已更新'
          : '连接信息已保存：${result.errorMessage ?? '探测失败'}';
      showSoundSnackBar(context, message);
    }
  }

  Future<WebDavDiscoveryResult?> _showWebDavEditor(
    WebDavConnectionService service, {
    WebDavConnectionRecord? connection,
  }) {
    if (context.soundIsCompact) {
      return showSoundBottomSheet<WebDavDiscoveryResult>(
        context,
        builder: (_) => WebDavAddDialog(
          service: service,
          connection: connection,
          bottomSheet: true,
        ),
      );
    }
    return showDialog<WebDavDiscoveryResult>(
      context: context,
      builder: (_) => WebDavAddDialog(service: service, connection: connection),
    );
  }

  Future<void> _probeRemoteConnection(
    RemoteSourceSettingsAdapter adapter,
    SourceManagedResource connection,
  ) async {
    try {
      final result = await adapter.connections.probe(connection.id);
      if (!mounted) return;
      if (!result.isAvailable) {
        showSoundSnackBar(context, '连接失败：${result.errorMessage ?? '未知错误'}');
      } else {
        showSoundSnackBar(context, '连接成功');
      }
    } catch (error) {
      if (!mounted) return;
      showSoundSnackBar(context, '探测失败：$error');
    }
  }

  Future<void> _browseRemoteDirectories(
    RemoteSourceSettingsAdapter adapter,
    SourceManagedResource connection,
  ) async {
    if (!mounted) return;

    SourceDirectoryBrowser browser;
    try {
      browser = await adapter.connections.openBrowser(connection.id);
    } catch (error) {
      if (!mounted) return;
      showSoundSnackBar(context, error.toString());
      return;
    }
    if (!mounted) return;

    final selected = context.soundIsCompact
        ? await showSoundBottomSheet<List<String>>(
            context,
            builder: (_) =>
                WebDavFolderPicker(browser: browser, bottomSheet: true),
          )
        : await showDialog<List<String>>(
            context: context,
            builder: (_) => WebDavFolderPicker(browser: browser),
          );
    if (!mounted || selected == null || selected.isEmpty) return;

    try {
      final result = await adapter.scanDirectories(connection.id, selected);
      if (!mounted) return;
      showSoundSnackBar(context, _scanSummary(result));
    } on ScanCancelledException {
      if (!mounted) return;
      showSoundSnackBar(context, 'WebDAV 扫描已取消，原资料库保持不变');
    } catch (error) {
      if (!mounted) return;
      showSoundSnackBar(context, '扫描失败：$error');
    }
  }

  String _managedStatus(SourceManagedResource resource) {
    return switch (resource.status) {
      SourceManagedStatus.idle =>
        resource.kind == SourceManagedResourceKind.connection ? '未探测' : '未扫描',
      SourceManagedStatus.working =>
        resource.kind == SourceManagedResourceKind.connection ? '正在探测' : '正在扫描',
      SourceManagedStatus.available =>
        resource.kind == SourceManagedResourceKind.connection ? '已连接' : '已索引',
      SourceManagedStatus.authenticationFailed =>
        resource.errorMessage ?? '认证失败',
      SourceManagedStatus.unavailable => resource.errorMessage ?? '无法连接',
      SourceManagedStatus.error => resource.errorMessage ?? '错误',
    };
  }

  String _scanSummary(SourceScanSummary result) {
    final changes = [
      if (result.addedTracks > 0) '新增 ${result.addedTracks}',
      if (result.modifiedTracks > 0) '更新 ${result.modifiedTracks}',
      if (result.movedTracks > 0) '移动 ${result.movedTracks}',
      if (result.removedTracks > 0) '移除 ${result.removedTracks}',
    ];
    final changeSummary = changes.isEmpty ? '，没有文件变化' : '，${changes.join('、')}';
    final skipped = result.skippedFiles == 0
        ? ''
        : '，跳过 ${result.skippedFiles} 个文件';
    return '已索引 ${result.indexedTracks} 首歌曲$changeSummary$skipped'
        '${_scanWarningSuffix(result)}';
  }

  String _scanWarningSuffix(SourceScanSummary result) {
    if (result.warnings.isEmpty) return '';
    return '；首个原因：${result.warnings.first}';
  }

  Widget _remoteSection(RemoteSourceSettingsAdapter adapter) {
    return _SourceSection(
      title: '远程连接',
      actionLabel: '添加连接',
      onAction: () => adapter.openEditor(context, null),
      child: StreamBuilder<List<SourceManagedResource>>(
        stream: adapter.connections.watchResources(),
        builder: (context, snapshot) {
          final resources = snapshot.data ?? const [];
          if (snapshot.hasError) {
            return _SourceMessage(
              message:
                  '无法读取${adapter.definition.displayName}来源：${snapshot.error}',
            );
          }
          if (resources.isEmpty) {
            return const _SourceMessage(message: '还没有远程连接');
          }
          final connections = resources
              .where(
                (resource) =>
                    resource.kind == SourceManagedResourceKind.connection,
              )
              .toList(growable: false);
          final catalogs = resources
              .where(
                (resource) =>
                    resource.kind == SourceManagedResourceKind.catalog,
              )
              .toList(growable: false);
          final orphanCatalogs = catalogs
              .where(
                (catalog) => !connections.any(
                  (connection) => connection.id == catalog.parentConnectionId,
                ),
              )
              .toList(growable: false);
          return _SourceGroup(
            children: [
              for (final connection in connections) ...[
                // Flat list: one card, hierarchy only via indent — no nested
                // frames that stack borders and double the chrome.
                KeyedSubtree(
                  key: ValueKey('source-connection-tree-${connection.id}'),
                  child: _SourceRow(
                    key: ValueKey('source-connection-${connection.id}'),
                    title: connection.displayName,
                    subtitle: _connectionSubtitle(adapter, connection),
                    emphasis: _statusEmphasis(connection.status),
                    primaryActionLabel: connection.isAvailable
                        ? '选择目录'
                        : '重新连接',
                    primaryActionIcon: connection.isAvailable
                        ? KaitingIcons.add
                        : KaitingIcons.refresh,
                    onPrimaryAction: connection.isAvailable
                        ? () => _browseRemoteDirectories(adapter, connection)
                        : () => _probeRemoteConnection(adapter, connection),
                    onEdit: () => adapter.openEditor(context, connection),
                    onRemove: () => _removeRemoteSource(adapter, connection),
                  ),
                ),
                ...catalogs
                    .where(
                      (catalog) => catalog.parentConnectionId == connection.id,
                    )
                    .map((source) => _remoteCatalogRow(adapter, source)),
                if (!catalogs.any(
                  (catalog) => catalog.parentConnectionId == connection.id,
                ))
                  _EmptyDirectoryBranch(
                    onAddDirectory: connection.isAvailable
                        ? () => _browseRemoteDirectories(adapter, connection)
                        : null,
                  ),
              ],
              if (orphanCatalogs.isNotEmpty) ...[
                const _OrphanDirectoriesLabel(),
                for (final source in orphanCatalogs)
                  _remoteCatalogRow(adapter, source),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _remoteCatalogRow(
    RemoteSourceSettingsAdapter adapter,
    SourceManagedResource source,
  ) {
    final scanning =
        _scanningSourceIds.contains(source.id) ||
        adapter.scanner.isScanning(source.id);
    final path = formatSourceLocation(source.location);
    return _SourceRow(
      key: ValueKey('source-directory-${source.id}'),
      title: preferredSourceTitle(source.displayName, path),
      subtitle: _catalogSubtitle(source, path),
      emphasis: _statusEmphasis(source.status),
      nested: true,
      primaryActionLabel: scanning ? '取消扫描' : '重新扫描',
      primaryActionIcon: scanning ? KaitingIcons.close : KaitingIcons.sync,
      onPrimaryAction: scanning
          ? () => adapter.scanner.cancel(source.id)
          : () => _scanSource(source.type, source.id),
      onRemove: scanning ? null : () => _removeRemoteSource(adapter, source),
    );
  }

  String _connectionSubtitle(
    RemoteSourceSettingsAdapter adapter,
    SourceManagedResource connection,
  ) {
    final host = formatSourceLocation(connection.location);
    final type = adapter.definition.displayName;
    final status = _managedStatus(connection);
    // Healthy connections only need type + host; keep status for errors / work.
    return switch (connection.status) {
      SourceManagedStatus.available => host.isEmpty ? type : '$type · $host',
      SourceManagedStatus.working || SourceManagedStatus.idle =>
        host.isEmpty ? status : '$status · $type · $host',
      _ => host.isEmpty ? status : '$status · $host',
    };
  }

  String _catalogSubtitle(SourceManagedResource source, String path) {
    final status = _managedStatus(source);
    final title = preferredSourceTitle(source.displayName, path);
    // Avoid repeating the same string as title and path.
    final showPath =
        path.isNotEmpty && path != title && path != source.displayName;
    return switch (source.status) {
      SourceManagedStatus.available => showPath ? path : status,
      SourceManagedStatus.working ||
      SourceManagedStatus.idle => showPath ? '$status · $path' : status,
      _ => showPath ? '$status · $path' : status,
    };
  }

  _SourceEmphasis _statusEmphasis(SourceManagedStatus status) {
    return switch (status) {
      SourceManagedStatus.authenticationFailed => _SourceEmphasis.warning,
      SourceManagedStatus.unavailable ||
      SourceManagedStatus.error => _SourceEmphasis.error,
      SourceManagedStatus.working => _SourceEmphasis.working,
      SourceManagedStatus.idle ||
      SourceManagedStatus.available => _SourceEmphasis.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    final localProvider = _sourceProviders.providerFor(LibrarySourceType.local);
    return ListView(
      key: const ValueKey('source-settings'),
      padding: EdgeInsets.zero,
      children: [
        SoundSettingsContent(
          padding: EdgeInsets.fromLTRB(
            context.soundPageGutter,
            28,
            context.soundPageGutter,
            context.soundContentBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SoundSettingsPageHeader(
                title: '音乐来源',
                subtitle: kIsWeb
                    ? '管理远程连接和已加入资料库的目录。'
                    : '管理本地文件夹、远程连接和已加入资料库的目录。',
                onBack: widget.onBack,
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: SoundSettingsMetrics.sectionGap),
                _SourceSection(
                  title: '本机',
                  actionLabel: _addingSource ? '正在添加…' : '添加文件夹',
                  onAction: _addingSource || localProvider == null
                      ? null
                      : _addLocalSource,
                  child: StreamBuilder<List<LibrarySourceRecord>>(
                    stream: widget.localSources.watchLocalSources(),
                    builder: (context, snapshot) {
                      final sources = snapshot.data ?? const [];
                      if (snapshot.hasError) {
                        return _SourceMessage(
                          message: '无法读取本机来源：${snapshot.error}',
                        );
                      }
                      if (sources.isEmpty) {
                        return const _SourceMessage(message: '还没有添加本机文件夹');
                      }
                      return _SourceGroup(
                        children: [
                          for (final source in sources)
                            Builder(
                              builder: (context) {
                                final scanning = _scanningSourceIds.contains(
                                  source.id,
                                );
                                final path = formatSourceLocation(
                                  source.rootUri,
                                );
                                return _SourceRow(
                                  key: ValueKey('local-source-${source.id}'),
                                  title: preferredSourceTitle(
                                    source.displayName,
                                    path,
                                  ),
                                  subtitle: _localSubtitle(source, path),
                                  emphasis: _localEmphasis(source),
                                  primaryActionLabel: scanning
                                      ? '取消扫描'
                                      : '重新扫描',
                                  primaryActionIcon: scanning
                                      ? KaitingIcons.close
                                      : KaitingIcons.sync,
                                  onPrimaryAction: scanning
                                      ? () =>
                                            _localScanProvider.cancel(source.id)
                                      : () =>
                                            _scanSource(source.type, source.id),
                                  onRemove: scanning
                                      ? null
                                      : () => _removeLocalSource(source),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              for (final adapter in _remoteAdapters) ...[
                const SizedBox(height: SoundSettingsMetrics.sectionGap),
                _remoteSection(adapter),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _sourceStatus(LibrarySourceRecord source) {
    return switch (source.status) {
      LibrarySourceStatus.idle => '等待扫描',
      LibrarySourceStatus.scanning => '正在扫描',
      LibrarySourceStatus.available => source.scanRevision == 0 ? '已授权' : '已索引',
      LibrarySourceStatus.permissionRequired => '需要重新授权',
      LibrarySourceStatus.unavailable => '文件夹不可用',
      LibrarySourceStatus.error => source.lastError ?? '来源错误',
    };
  }

  String _localSubtitle(LibrarySourceRecord source, String path) {
    final status = _sourceStatus(source);
    final title = preferredSourceTitle(source.displayName, path);
    final showPath =
        path.isNotEmpty && path != title && path != source.displayName;
    return switch (source.status) {
      LibrarySourceStatus.available => showPath ? path : status,
      LibrarySourceStatus.scanning ||
      LibrarySourceStatus.idle => showPath ? '$status · $path' : status,
      _ => showPath ? '$status · $path' : status,
    };
  }

  _SourceEmphasis _localEmphasis(LibrarySourceRecord source) {
    return switch (source.status) {
      LibrarySourceStatus.permissionRequired => _SourceEmphasis.warning,
      LibrarySourceStatus.unavailable ||
      LibrarySourceStatus.error => _SourceEmphasis.error,
      LibrarySourceStatus.scanning => _SourceEmphasis.working,
      LibrarySourceStatus.idle ||
      LibrarySourceStatus.available => _SourceEmphasis.neutral,
    };
  }
}

String formatSourceLocation(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return _decodeLoose(value);
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  final decodedPath = segments.join('/');

  if (uri.scheme == 'file') {
    if (segments.isNotEmpty && segments.first.endsWith(':')) {
      return decodedPath;
    }
    return '/$decodedPath';
  }
  if (uri.scheme == 'content') {
    if (segments.isEmpty) return '设备存储';
    var location = segments.last.replaceAll(':', ' / ');
    if (location.startsWith('primary / ')) {
      location = '内部存储 / ${location.substring('primary / '.length)}';
    }
    return location;
  }
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    final defaultPort =
        (uri.scheme == 'http' && uri.port == 80) ||
        (uri.scheme == 'https' && uri.port == 443);
    final authority = defaultPort ? uri.host : '${uri.host}:${uri.port}';
    return decodedPath.isEmpty ? authority : '$authority/$decodedPath';
  }
  if (uri.scheme.isEmpty && value.startsWith('/')) return '/$decodedPath';
  if (decodedPath.isNotEmpty) return decodedPath;
  return _decodeLoose(value);
}

/// Prefer a short leaf name when the display name is a path-like label.
String preferredSourceTitle(String displayName, String formattedLocation) {
  final name = displayName.trim();
  if (name.isEmpty) {
    return formattedLocation.isEmpty ? '未命名' : formattedLocation;
  }
  if (name.contains(' / ')) {
    final leaf = name.split(' / ').last.trim();
    if (leaf.isNotEmpty) return leaf;
  }
  final slash = name.contains('/') ? name.split('/').last.trim() : '';
  if (slash.isNotEmpty && slash != name) return slash;

  final pathLeaf = formattedLocation
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .lastOrNull;
  if (pathLeaf != null &&
      (name == formattedLocation ||
          name.endsWith(pathLeaf) ||
          formattedLocation.endsWith(name))) {
    return pathLeaf;
  }
  return name;
}

String _decodeLoose(String value) {
  try {
    return Uri.decodeFull(value);
  } on FormatException {
    return value;
  }
}

enum _SourceEmphasis { neutral, working, warning, error }

class _SourceSection extends StatelessWidget {
  const _SourceSection({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _sourceSecondaryText(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _SourceMessage extends StatelessWidget {
  const _SourceMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
      child: Text(
        message,
        style: TextStyle(color: _sourceSecondaryText(context), fontSize: 12),
      ),
    );
  }
}

class _SourceGroup extends StatelessWidget {
  const _SourceGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoundSettingsGroup(children: children);
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.title,
    required this.subtitle,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onPrimaryAction,
    this.emphasis = _SourceEmphasis.neutral,
    this.nested = false,
    this.onEdit,
    this.onRemove,
    super.key,
  });

  final String title;
  final String subtitle;
  final _SourceEmphasis emphasis;
  final bool nested;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  Color _subtitleColor(BuildContext context) {
    return switch (emphasis) {
      _SourceEmphasis.neutral => context.settingsMuted,
      _SourceEmphasis.working => context.settingsSecondary,
      _SourceEmphasis.warning => context.soundWarning,
      _SourceEmphasis.error => context.soundColors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(nested ? 28 : 14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _sourcePrimaryText(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: -0.1,
                  ),
                ),
                if (subtitleText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitleText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _subtitleColor(context),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onPrimaryAction,
            tooltip: primaryActionLabel,
            icon: Icon(primaryActionIcon, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          if (onEdit != null || onRemove != null)
            SoundMenuButton<_SourceMenuAction>(
              tooltip: '更多操作',
              icon: const Icon(KaitingIcons.moreHorizontal, size: 20),
              padding: const EdgeInsets.all(8),
              onSelected: (action) {
                switch (action) {
                  case _SourceMenuAction.edit:
                    onEdit?.call();
                  case _SourceMenuAction.remove:
                    onRemove?.call();
                }
              },
              actions: [
                if (onEdit != null)
                  const SoundMenuAction(
                    value: _SourceMenuAction.edit,
                    label: '编辑',
                    icon: KaitingIcons.edit,
                  ),
                if (onRemove != null)
                  const SoundMenuAction(
                    value: _SourceMenuAction.remove,
                    label: '移除',
                    icon: KaitingIcons.delete,
                    destructive: true,
                    dividerBefore: true,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyDirectoryBranch extends StatelessWidget {
  const _EmptyDirectoryBranch({required this.onAddDirectory});

  final VoidCallback? onAddDirectory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 10, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '尚未选择目录',
              style: TextStyle(
                color: context.settingsMuted,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
          if (onAddDirectory != null)
            TextButton(
              onPressed: onAddDirectory,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('选择目录'),
            ),
        ],
      ),
    );
  }
}

class _OrphanDirectoriesLabel extends StatelessWidget {
  const _OrphanDirectoriesLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Text(
        '待确认归属的目录',
        style: TextStyle(
          color: context.settingsMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _SourceMenuAction { edit, remove }
