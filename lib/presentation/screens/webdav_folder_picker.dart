import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../sources/source_provider.dart';
import '../widgets/sound_components.dart';

class WebDavFolderPicker extends StatefulWidget {
  const WebDavFolderPicker({
    required this.browser,
    this.bottomSheet = false,
    super.key,
  });

  final SourceDirectoryBrowser browser;
  final bool bottomSheet;

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
    final content = _pickerContent(
      context,
      entries: entries,
      isLoading: isLoading,
    );
    final actions = _pickerActions(context);

    if (widget.bottomSheet) {
      final height = MediaQuery.sizeOf(context).height * 0.78;
      return SizedBox(
        height: height.clamp(420.0, 720.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 18, 10),
              child: _PickerTitle(selectedCount: _selected.length),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: content,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 10,
                children: actions,
              ),
            ),
          ],
        ),
      );
    }

    return SoundDialog(
      maxWidth: 540,
      title: _PickerTitle(selectedCount: _selected.length),
      content: SizedBox(width: 480, height: 440, child: content),
      actions: actions,
    );
  }

  Widget _pickerContent(
    BuildContext context, {
    required List<SourceDirectoryEntry> entries,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BreadcrumbBar(
          path: _currentPath,
          canGoBack: _pathStack.length > 1,
          onBack: _goBack,
        ),
        Divider(height: 1, color: context.soundDivider),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _ErrorBanner(message: _errorMessage!),
          )
        else if (isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (entries.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                '这个目录是空的',
                style: TextStyle(color: context.soundMutedText),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: 34, color: context.soundDivider),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _FolderEntry(
                  entry: entry,
                  isSelected: _selected.contains(entry.id),
                  onTap: () {
                    if (entry.isDirectory) _navigateTo(entry.id);
                  },
                  onToggle: () => _toggleSelection(entry.id),
                );
              },
            ),
          ),
      ],
    );
  }

  List<Widget> _pickerActions(BuildContext context) => [
    TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('取消'),
    ),
    FilledButton(
      onPressed: () => Navigator.of(context).pop(_selected.toList()),
      child: Text(_selected.isEmpty ? '暂不选择' : '选择 ${_selected.length} 个目录'),
    ),
  ];
}

class _PickerTitle extends StatelessWidget {
  const _PickerTitle({required this.selectedCount});

  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('选择目录')),
        Text(
          '已选 $selectedCount',
          style: TextStyle(
            fontSize: 13,
            color: context.soundSecondaryText,
            fontWeight: FontWeight.w400,
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
          const SizedBox(width: 40),
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
        color: context.soundSecondaryText,
        size: 20,
      ),
      title: Text(
        entry.displayName,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      trailing: entry.isDirectory
          ? IconButton(
              onPressed: onToggle,
              tooltip: isSelected ? '取消选择' : '选择此目录',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isSelected ? Icons.check_rounded : Icons.add_rounded,
                color: isSelected
                    ? SoundColors.accent
                    : context.soundSecondaryText,
                size: 20,
              ),
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
