import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../library/scanning/audio_format_registry.dart';
import '../../sources/webdav/webdav_credentials.dart';
import '../../sources/webdav/webdav_discovery.dart';
import '../widgets/sound_components.dart';

class WebDavFolderPicker extends StatefulWidget {
  const WebDavFolderPicker({
    required this.url,
    required this.credentials,
    required this.allowBadCertificate,
    super.key,
  });

  final String url;
  final WebDavCredentials credentials;
  final bool allowBadCertificate;

  @override
  State<WebDavFolderPicker> createState() => _WebDavFolderPickerState();
}

class _WebDavFolderPickerState extends State<WebDavFolderPicker> {
  late final WebDavDiscoveryService _discovery;
  final Set<String> _selected = {};
  final Map<String, List<WebDavFileEntry>> _cache = {};
  final Set<String> _loading = {};
  String? _errorMessage;
  late String _currentPath;
  final List<String> _pathStack = [];

  String get _url => widget.url;
  WebDavCredentials get _credentials => widget.credentials;

  @override
  void initState() {
    super.initState();
    _discovery = WebDavDiscoveryService(
      allowBadCertificate: widget.allowBadCertificate,
    );
    final rootPath = Uri.parse(widget.url).path;
    _currentPath = rootPath.isEmpty ? '/' : rootPath;
    _pathStack.add(_currentPath);
    _browse(_currentPath);
  }

  String _fullUrl(String path) {
    return Uri.parse(_url).resolve(path).toString();
  }

  /// Extracts the path portion from an absolute href returned by the server.
  String? _pathFromHref(String href) {
    if (href.isEmpty) return null;
    final root = Uri.parse(_url);
    final hrefUri = Uri.tryParse(href);
    if (hrefUri == null) return null;
    final resolved = hrefUri.hasScheme ? hrefUri : root.resolveUri(hrefUri);
    if (resolved.scheme.toLowerCase() != root.scheme.toLowerCase() ||
        resolved.host.toLowerCase() != root.host.toLowerCase() ||
        resolved.port != root.port) {
      return null;
    }
    return resolved.path.isEmpty ? '/' : resolved.path;
  }

  Future<void> _browse(String path) async {
    if (_cache.containsKey(path)) return;
    setState(() {
      _loading.add(path);
      _errorMessage = null;
    });

    final result = await _discovery.probe(
      _fullUrl(path),
      credentials: _credentials,
    );

    if (!mounted) return;
    setState(() {
      _loading.remove(path);
      if (result.error != null) {
        _errorMessage = result.errorMessage ?? '无法读取目录';
      } else {
        // Filter out the directory's own entry (href matches requested path).
        final selfHref = path.length > 1 && path.endsWith('/')
            ? path.substring(0, path.length - 1)
            : path;
        _cache[path] = result.files.where((f) {
          final entryPath = _pathFromHref(f.href);
          return entryPath != null &&
              (f.isCollection || _isAudioFile(f.displayName)) &&
              entryPath != path &&
              entryPath != selfHref;
        }).toList();
      }
    });
  }

  bool _isAudioFile(String name) {
    return isSupportedAudioPath(name);
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
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white54,
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
                        isSelected: _selected.contains(
                          _pathFromHref(entry.href),
                        ),
                        onTap: () {
                          if (entry.isCollection) {
                            final path = _pathFromHref(entry.href);
                            if (path != null) _navigateTo(path);
                          }
                        },
                        onToggle: () {
                          final path = _pathFromHref(entry.href);
                          if (path != null) _toggleSelection(path);
                        },
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
          style: FilledButton.styleFrom(
            backgroundColor: SoundColors.accent,
            foregroundColor: Colors.white,
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
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white54,
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

  final WebDavFileEntry entry;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        entry.isCollection ? Icons.folder_rounded : Icons.audio_file_rounded,
        color: entry.isCollection ? SoundColors.webDav : Colors.white54,
        size: 20,
      ),
      title: Text(
        entry.displayName,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      trailing: entry.isCollection
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
              activeColor: SoundColors.accent,
              visualDensity: VisualDensity.compact,
            )
          : null,
      onTap: entry.isCollection ? onTap : null,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SoundColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: SoundColors.accent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: SoundColors.accent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
