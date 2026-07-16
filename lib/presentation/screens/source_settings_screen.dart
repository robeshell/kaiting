import 'dart:async';

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

Color _sourcePrimaryText(BuildContext context) => context.soundPrimaryText
    .withValues(alpha: context.soundPrimaryText.a * 0.88);

Color _sourceSecondaryText(BuildContext context) =>
    context.soundMutedText.withValues(alpha: context.soundMutedText.a * 0.76);

Color _sourceHairline(BuildContext context) =>
    context.soundDivider.withValues(alpha: context.soundDivider.a * 0.68);

class RemoteSourceSettingsAdapter {
  const RemoteSourceSettingsAdapter({
    required this.definition,
    required this.connections,
    required this.scanner,
    required this.openEditor,
    required this.scanDirectories,
    required this.color,
    required this.addIcon,
    required this.connectionIcon,
    required this.catalogIcon,
  });

  final SourceProviderDefinition definition;
  final SourceConnectionProvider connections;
  final SourceScanProvider scanner;
  final SourceEditorCallback openEditor;
  final SourceDirectoryScanCallback scanDirectories;
  final Color color;
  final IconData addIcon;
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
              addIcon: Icons.add_to_drive_outlined,
              connectionIcon: Icons.cloud_rounded,
              catalogIcon: Icons.folder_rounded,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法添加文件夹：$error')));
    } finally {
      if (mounted) setState(() => _addingSource = false);
    }
  }

  Future<void> _removeLocalSource(LibrarySourceRecord source) async {
    try {
      await widget.localSources.removeLocalFolder(source);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法移除文件夹：$error')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已索引 ${report.indexedTracks} 首歌曲$changeSummary$skipped'
            '${_scanWarningSuffix(report)}',
          ),
        ),
      );
    } on ScanCancelledException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('扫描已取消，原资料库保持不变')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('扫描失败：$error')));
    } finally {
      _scanningSourceIds.remove(sourceId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _addWebDavSource() async {
    final webDav = widget.webDavService;
    if (webDav == null) return;
    final result = await showDialog<WebDavDiscoveryResult>(
      context: context,
      builder: (_) => WebDavAddDialog(service: webDav),
    );
    if (result != null && mounted) {
      final fileCount = result.files.where((f) => !f.isCollection).length;
      final dirCount = result.files.where((f) => f.isCollection).length;
      var msg = 'WebDAV 服务器已连接';
      if (fileCount > 0) msg += '，发现 $fileCount 个文件、$dirCount 个目录';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('移除失败：$error')));
      }
    }
  }

  Future<void> _editWebDavSource(SourceManagedResource resource) async {
    final webDav = widget.webDavService;
    if (webDav == null) return;
    final connection = await webDav.getManagedSource(resource.id);
    if (connection == null || !mounted) return;
    final result = await showDialog<WebDavDiscoveryResult>(
      context: context,
      builder: (_) => WebDavAddDialog(service: webDav, connection: connection),
    );
    if (result != null && mounted) {
      final message = result.error == null
          ? 'WebDAV 连接已更新'
          : '连接信息已保存：${result.errorMessage ?? '探测失败'}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _probeRemoteConnection(
    RemoteSourceSettingsAdapter adapter,
    SourceManagedResource connection,
  ) async {
    try {
      final result = await adapter.connections.probe(connection.id);
      if (!mounted) return;
      if (!result.isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败：${result.errorMessage ?? '未知错误'}')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接成功')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('探测失败：$error')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    if (!mounted) return;

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => WebDavFolderPicker(browser: browser),
    );
    if (!mounted || selected == null || selected.isEmpty) return;

    try {
      final result = await adapter.scanDirectories(connection.id, selected);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_scanSummary(result))));
    } on ScanCancelledException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('WebDAV 扫描已取消，原资料库保持不变')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('扫描失败：$error')));
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

  Color _managedStatusColor(SourceManagedResource resource, Color readyColor) {
    return switch (resource.status) {
      SourceManagedStatus.idle ||
      SourceManagedStatus.working ||
      SourceManagedStatus.available => readyColor,
      SourceManagedStatus.authenticationFailed => Colors.orangeAccent,
      SourceManagedStatus.unavailable ||
      SourceManagedStatus.error => Colors.redAccent,
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
      title: adapter.definition.displayName,
      description: adapter.definition.sectionDescription,
      child: StreamBuilder<List<SourceManagedResource>>(
        stream: adapter.connections.watchResources(),
        builder: (context, snapshot) {
          final resources = snapshot.data ?? const [];
          if (snapshot.hasError) {
            return _SourceMessage(
              icon: Icons.error_outline_rounded,
              message:
                  '无法读取${adapter.definition.displayName}来源：${snapshot.error}',
            );
          }
          if (resources.isEmpty) {
            return _SourceMessage(
              icon: Icons.cloud_off_outlined,
              message: '还没有添加${adapter.definition.displayName}来源',
            );
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
          return _SourceGroup(
            children: [
              for (final connection in connections)
                _SourceRow(
                  icon: adapter.connectionIcon,
                  iconColor: adapter.color,
                  title: connection.displayName,
                  location: formatSourceLocation(connection.location),
                  status: _managedStatus(connection),
                  statusColor: _managedStatusColor(connection, adapter.color),
                  primaryActionLabel: connection.isAvailable
                      ? '选择扫描目录'
                      : '重新探测',
                  primaryActionIcon: connection.isAvailable
                      ? Icons.folder_open_rounded
                      : Icons.refresh_rounded,
                  onPrimaryAction: connection.isAvailable
                      ? () => _browseRemoteDirectories(adapter, connection)
                      : () => _probeRemoteConnection(adapter, connection),
                  onEdit: () => adapter.openEditor(context, connection),
                  onRemove: () => _removeRemoteSource(adapter, connection),
                ),
              for (final source in catalogs)
                Builder(
                  builder: (context) {
                    final scanning =
                        _scanningSourceIds.contains(source.id) ||
                        adapter.scanner.isScanning(source.id);
                    return _SourceRow(
                      icon: adapter.catalogIcon,
                      iconColor: adapter.color,
                      title: source.displayName,
                      location: formatSourceLocation(source.location),
                      status: _managedStatus(source),
                      statusColor: _managedStatusColor(source, adapter.color),
                      primaryActionLabel: scanning ? '取消扫描' : '重新扫描',
                      primaryActionIcon: scanning
                          ? Icons.close_rounded
                          : Icons.sync_rounded,
                      onPrimaryAction: scanning
                          ? () => adapter.scanner.cancel(source.id)
                          : () => _scanSource(source.type, source.id),
                      onRemove: scanning
                          ? null
                          : () => _removeRemoteSource(adapter, source),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localProvider = _sourceProviders.providerFor(LibrarySourceType.local);
    return ListView(
      key: const ValueKey('source-settings'),
      padding: EdgeInsets.fromLTRB(
        context.soundPageGutter,
        28,
        context.soundPageGutter,
        context.soundContentBottomPadding,
      ),
      children: [
        Row(
          children: [
            if (widget.onBack != null) ...[
              IconButton(
                key: const ValueKey('source-settings-back'),
                onPressed: widget.onBack,
                tooltip: '返回设置',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                '音乐来源',
                style: TextStyle(
                  fontSize: context.soundPageTitleSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.45,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '选择 Reverie 要索引的本地文件夹和远程音乐目录。',
            style: TextStyle(
              color: _sourceSecondaryText(context),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _addingSource || localProvider == null
                  ? null
                  : _addLocalSource,
              icon: _addingSource
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.create_new_folder_outlined, size: 17),
              label: Text(localProvider?.addActionLabel ?? '本地来源不可用'),
            ),
            for (final adapter in _remoteAdapters)
              FilledButton.icon(
                onPressed: () => adapter.openEditor(context, null),
                icon: Icon(adapter.addIcon, size: 17),
                label: Text(adapter.definition.addActionLabel),
              ),
          ],
        ),
        const SizedBox(height: 26),
        _SourceSection(
          title: localProvider?.displayName ?? '本地文件夹',
          description: localProvider?.sectionDescription ?? '本地来源 provider 未注册',
          child: StreamBuilder<List<LibrarySourceRecord>>(
            stream: widget.localSources.watchLocalSources(),
            builder: (context, snapshot) {
              final sources = snapshot.data ?? const [];
              if (snapshot.hasError) {
                return _SourceMessage(
                  icon: Icons.error_outline_rounded,
                  message: '无法读取本地来源：${snapshot.error}',
                );
              }
              if (sources.isEmpty) {
                return const _SourceMessage(
                  icon: Icons.folder_off_outlined,
                  message: '还没有添加本地文件夹',
                );
              }
              return _SourceGroup(
                children: [
                  for (final source in sources)
                    Builder(
                      builder: (context) {
                        final scanning = _scanningSourceIds.contains(source.id);
                        return _SourceRow(
                          icon: Icons.folder_rounded,
                          iconColor: SoundColors.local,
                          title: source.displayName,
                          location: formatSourceLocation(source.rootUri),
                          status: _sourceStatus(source),
                          statusColor: _sourceStatusColor(source),
                          primaryActionLabel: scanning ? '取消扫描' : '重新扫描',
                          primaryActionIcon: scanning
                              ? Icons.close_rounded
                              : Icons.sync_rounded,
                          onPrimaryAction: scanning
                              ? () => _localScanProvider.cancel(source.id)
                              : () => _scanSource(source.type, source.id),
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
        for (final adapter in _remoteAdapters) ...[
          const SizedBox(height: 24),
          _remoteSection(adapter),
        ],
      ],
    );
  }

  String _sourceStatus(LibrarySourceRecord source) {
    return switch (source.status) {
      LibrarySourceStatus.idle => '等待扫描',
      LibrarySourceStatus.scanning => '正在扫描',
      LibrarySourceStatus.available =>
        source.scanRevision == 0 ? '已授权' : '已索引 · 第 ${source.scanRevision} 次扫描',
      LibrarySourceStatus.permissionRequired => '需要重新授权',
      LibrarySourceStatus.unavailable => '文件夹不可用',
      LibrarySourceStatus.error => source.lastError ?? '来源错误',
    };
  }

  Color _sourceStatusColor(LibrarySourceRecord source) {
    return switch (source.status) {
      LibrarySourceStatus.idle ||
      LibrarySourceStatus.scanning ||
      LibrarySourceStatus.available => SoundColors.local,
      LibrarySourceStatus.permissionRequired => Colors.orangeAccent,
      LibrarySourceStatus.unavailable ||
      LibrarySourceStatus.error => Colors.redAccent,
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

String _decodeLoose(String value) {
  try {
    return Uri.decodeFull(value);
  } on FormatException {
    return value;
  }
}

class _SourceSection extends StatelessWidget {
  const _SourceSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _sourcePrimaryText(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _sourceSecondaryText(context),
                    fontSize: 11,
                  ),
                ),
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
  const _SourceMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _sourceSecondaryText(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: _sourceSecondaryText(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceGroup extends StatelessWidget {
  const _SourceGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(height: 1, indent: 42, color: _sourceHairline(context)),
        ],
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.location,
    required this.status,
    required this.statusColor,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onPrimaryAction,
    this.onEdit,
    this.onRemove,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String location;
  final String status;
  final Color statusColor;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 0, 10),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor.withValues(alpha: iconColor.a * 0.78),
                ),
              ),
              const SizedBox(width: 10),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      compact ? '$status · $location' : location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _sourceSecondaryText(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 14),
                _StatusDot(color: statusColor),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _sourceSecondaryText(context),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              IconButton(
                onPressed: onPrimaryAction,
                tooltip: primaryActionLabel,
                icon: Icon(primaryActionIcon, size: 19),
              ),
              if (onEdit != null || onRemove != null)
                PopupMenuButton<_SourceMenuAction>(
                  tooltip: '更多操作',
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  onSelected: (action) {
                    switch (action) {
                      case _SourceMenuAction.edit:
                        onEdit?.call();
                      case _SourceMenuAction.remove:
                        onRemove?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: _SourceMenuAction.edit,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('编辑'),
                        ),
                      ),
                    if (onRemove != null)
                      const PopupMenuItem(
                        value: _SourceMenuAction.remove,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('移除'),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _SourceMenuAction { edit, remove }

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
