import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../library/library_records.dart';
import '../../library/scanning/local_library_scanner.dart';
import '../../sources/local/local_source_service.dart';

class SourceSettingsScreen extends StatefulWidget {
  const SourceSettingsScreen({
    required this.localSources,
    required this.scanner,
    required this.onOpenPlaybackValidation,
    super.key,
  });

  final LocalSourceService localSources;
  final LocalLibraryScanner scanner;
  final VoidCallback onOpenPlaybackValidation;

  @override
  State<SourceSettingsScreen> createState() => _SourceSettingsScreenState();
}

class _SourceSettingsScreenState extends State<SourceSettingsScreen> {
  bool _addingSource = false;
  final Set<String> _scanningSourceIds = {};

  @override
  void initState() {
    super.initState();
    unawaited(widget.localSources.restoreLocalFolders());
  }

  Future<void> _addLocalSource() async {
    if (_addingSource) return;
    setState(() => _addingSource = true);
    try {
      final source = await widget.localSources.addLocalFolder();
      if (source != null && source.status == LibrarySourceStatus.available) {
        await _scanLocalSource(source);
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

  Future<void> _scanLocalSource(LibrarySourceRecord source) async {
    if (!_scanningSourceIds.add(source.id)) return;
    setState(() {});
    try {
      final report = await widget.scanner.scan(source);
      if (!mounted) return;
      final skipped = report.skippedFiles == 0
          ? ''
          : '，跳过 ${report.skippedFiles} 个文件';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已索引 ${report.indexedTracks} 首歌曲$skipped')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('扫描失败：$error')));
    } finally {
      _scanningSourceIds.remove(source.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 140),
      children: [
        const Text(
          '来源',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '管理音乐所在的位置。连接信息和纳入资料库的文件夹彼此独立。',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            const Expanded(
              child: Text(
                '音乐来源',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.icon(
              onPressed: _addingSource ? null : _addLocalSource,
              icon: _addingSource
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('添加本地文件夹'),
              style: FilledButton.styleFrom(
                backgroundColor: SoundColors.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<LibrarySourceRecord>>(
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
                icon: Icons.create_new_folder_outlined,
                message: '尚未添加本地音乐文件夹。',
              );
            }
            return Column(
              children: [
                for (var index = 0; index < sources.length; index++) ...[
                  _SourceCard(
                    icon: Icons.folder_rounded,
                    iconColor: SoundColors.local,
                    title: sources[index].displayName,
                    subtitle: sources[index].rootUri,
                    status: _sourceStatus(sources[index]),
                    statusColor: _sourceStatusColor(sources[index]),
                    folders: [sources[index].displayName],
                    onRemove: () => _removeLocalSource(sources[index]),
                    onRescan: _scanningSourceIds.contains(sources[index].id)
                        ? null
                        : () => _scanLocalSource(sources[index]),
                  ),
                  if (index != sources.length - 1) const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        const _SourceCard(
          icon: Icons.cloud_rounded,
          iconColor: SoundColors.webDav,
          title: '家庭 NAS',
          subtitle: 'https://nas.local/dav',
          status: '在线 · 上次扫描于 8 分钟前',
          folders: ['音乐/华语', '音乐/欧美'],
        ),
        const SizedBox(height: 30),
        const _FirstReleaseNote(),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: widget.onOpenPlaybackValidation,
          icon: const Icon(Icons.science_outlined),
          label: const Text('打开播放验证工具'),
        ),
      ],
    );
  }

  String _sourceStatus(LibrarySourceRecord source) {
    return switch (source.status) {
      LibrarySourceStatus.idle => '等待扫描',
      LibrarySourceStatus.scanning => '正在扫描',
      LibrarySourceStatus.available =>
        source.scanRevision == 0
            ? '已授权 · 等待扫描'
            : '已索引 · 已扫描 ${source.scanRevision} 次',
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

class _SourceMessage extends StatelessWidget {
  const _SourceMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.folders,
    this.statusColor = SoundColors.local,
    this.onRemove,
    this.onRescan,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String status;
  final List<String> folders;
  final Color statusColor;
  final VoidCallback? onRemove;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    _StatusDot(color: statusColor),
                    const SizedBox(width: 7),
                    Text(
                      status,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    onPressed: onRemove,
                    tooltip: onRemove == null ? null : '移除此来源',
                    icon: Icon(
                      onRemove == null
                          ? Icons.more_horiz_rounded
                          : Icons.delete_outline_rounded,
                    ),
                  ),
                ],
              ),
              if (compact)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      _StatusDot(color: statusColor),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          status,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 15),
              Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
              const SizedBox(height: 12),
              for (final folder in folders)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: compact ? 0 : 58),
                      const Icon(
                        Icons.folder_open_rounded,
                        size: 16,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          folder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: onRescan,
                        child: const Text('重新扫描'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _FirstReleaseNote extends StatelessWidget {
  const _FirstReleaseNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoundColors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoundColors.accent.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, color: SoundColors.accent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '首个验证版本只实现本地文件夹和 WebDAV。SMB、在线歌词与在线封面会等播放底座稳定后再评估。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
