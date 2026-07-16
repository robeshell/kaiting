import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../sources/source_provider.dart';
import '../widgets/sound_components.dart';

class WebDavFolderPicker extends StatefulWidget {
  const WebDavFolderPicker({required this.browser, super.key});

  final SourceDirectoryBrowser browser;

  @override
  State<WebDavFolderPicker> createState() => _WebDavFolderPickerState();
}

class _WebDavFolderPickerState extends State<WebDavFolderPicker> {
  final Set<String> _selected = {};
  final Map<String, List<SourceDirectoryEntry>> _cache = {};
  final Set<String> _loading = {};
  String? _errorMessage;
  late String _currentPath;
  final List<String> _pathStack = [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.browser.rootId;
    _pathStack.add(_currentPath);
    _browse(_currentPath);
  }

  Future<void> _browse(String path) async {
    if (_cache.containsKey(path)) return;
    setState(() {
      _loading.add(path);
      _errorMessage = null;
    });

    try {
      final entries = await widget.browser.browse(path);

      if (!mounted) return;
      setState(() {
        _loading.remove(path);
        _cache[path] = entries;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading.remove(path);
        _errorMessage = error.toString();
      });
    }
  }

  void _navigateTo(String path) {
    setState(() {
      _currentPath = path;
      _pathStack.add(path);
      _errorMessage = null;
    });
    _browse(path);
  }

  void _goBack() {
    if (_pathStack.length <= 1) return;
    setState(() {
      _pathStack.removeLast();
      _currentPath = _pathStack.last;
      _errorMessage = null;
    });
    _browse(_currentPath);
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _cache[_currentPath] ?? [];
    final isLoading = _loading.contains(_currentPath);

    return SoundDialog(
      maxWidth: 540,
      title: Row(
        children: [
          const Text('选择 WebDAV 文件夹'),
          const Spacer(),
          Text(
            '已选 ${_selected.length}',
            style: TextStyle(
              fontSize: 13,
              color: context.soundSecondaryText,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BreadcrumbBar(
              path: _currentPath,
              canGoBack: _pathStack.length > 1,
              onBack: _goBack,
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _ErrorBanner(message: _errorMessage!),
              )
            else if (isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in entries)
                      _FolderEntry(
                        entry: entry,
                        isSelected: _selected.contains(entry.id),
                        onTap: () {
                          if (entry.isDirectory) _navigateTo(entry.id);
                        },
                        onToggle: () => _toggleSelection(entry.id),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_selected.toList()),
          icon: const Icon(Icons.check_rounded),
          label: Text(
            _selected.isEmpty ? '暂不选择' : '选择 ${_selected.length} 个文件夹',
          ),
        ),
      ],
    );
  }
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.path,
    required this.canGoBack,
    required this.onBack,
  });

  final String path;
  final bool canGoBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (canGoBack)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            visualDensity: VisualDensity.compact,
          )
        else
          const SizedBox(width: 8),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: context.soundSecondaryText,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

class _FolderEntry extends StatelessWidget {
  const _FolderEntry({
    required this.entry,
    required this.isSelected,
    required this.onTap,
    required this.onToggle,
  });

  final SourceDirectoryEntry entry;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        entry.isDirectory ? Icons.folder_rounded : Icons.audio_file_rounded,
        color: entry.isDirectory
            ? SoundColors.webDav
            : context.soundSecondaryText,
        size: 20,
      ),
      title: Text(
        entry.displayName,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      trailing: entry.isDirectory
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
              activeColor: SoundColors.accent,
              visualDensity: VisualDensity.compact,
            )
          : null,
      onTap: entry.isDirectory ? onTap : null,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.soundColors.error,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.soundColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
