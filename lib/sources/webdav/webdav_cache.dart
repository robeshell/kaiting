import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../library/scanning/audio_format_registry.dart';

class WebDavCache {
  WebDavCache({
    required this.cacheDir,
    this.maxBytes = 500 * 1024 * 1024, // 500 MiB
  });

  final Directory cacheDir;
  final int maxBytes;
  final Map<String, _ActiveDownload> _downloads = {};
  final Set<String> _pendingCancellations = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await cacheDir.create(recursive: true);
    await _loadManifest();
    await _cleanStaleFiles();
    await _saveManifest();
    _initialized = true;
  }

  /// Removes interrupted downloads and cache files not present in the
  /// manifest. Extensionless files can be valid audio, so they must not be
  /// deleted merely because their URL had no recognized suffix.
  Future<void> _cleanStaleFiles() async {
    try {
      final referencedPaths = {
        for (final entry in _manifest.values) entry.path,
        '${cacheDir.path}/cache_manifest.json',
      };
      await for (final entry in cacheDir.list()) {
        if (entry is File && !referencedPaths.contains(entry.path)) {
          await entry.delete();
        }
      }
    } catch (_) {
      debugPrint('WebDavCache: failed to clean stale files');
    }
  }

  /// Returns the local file path if [url] is cached, or `null` otherwise.
  Future<String?> get(String url) async {
    await init();
    final entry = _manifest[url];
    if (entry == null) return null;
    final file = File(entry.path);
    if (!await file.exists()) {
      _manifest.remove(url);
      await _saveManifest();
      return null;
    }
    // Touch access time.
    entry.accessedAt = DateTime.now().millisecondsSinceEpoch;
    await _saveManifest();
    return file.path;
  }

  /// Returns a point-in-time view of the cache without exposing credentials.
  Future<WebDavCacheStats> stats() async {
    await init();
    return _stats;
  }

  /// Returns the cached items, most recently used first.
  Future<List<WebDavCacheItem>> items() async {
    await init();
    final items = _manifest.entries
        .map(
          (entry) => WebDavCacheItem(
            url: entry.key,
            path: entry.value.path,
            size: entry.value.size,
            pinned: entry.value.pinned,
            accessedAt: DateTime.fromMillisecondsSinceEpoch(
              entry.value.accessedAt,
            ),
          ),
        )
        .toList(growable: false);
    items.sort((left, right) => right.accessedAt.compareTo(left.accessedAt));
    return List.unmodifiable(items);
  }

  Future<bool> isPinned(String url) async {
    await init();
    return _manifest[url]?.pinned ?? false;
  }

  /// Cancels an in-flight cache download for [url].
  ///
  /// Downloads of the same URL are coalesced, so cancellation applies to the
  /// shared transfer and removes its partial file.
  bool cancel(String url, {bool includePending = false}) {
    final active = _downloads[url];
    if (active == null) {
      if (!includePending) return false;
      _pendingCancellations.add(url);
      return true;
    }
    active.cancel();
    return true;
  }

  /// Makes a WebDAV resource available without a network connection.
  ///
  /// An already cached resource is promoted in place. Pinned resources are
  /// not counted against the transient LRU budget and are never evicted by it.
  Future<String> pin(
    String url, {
    required Map<String, String> headers,
    bool allowBadCertificate = false,
    WebDavDownloadProgressCallback? onProgress,
  }) async {
    await init();
    if (_pendingCancellations.remove(url)) {
      throw const WebDavDownloadCancelledException();
    }
    final existing = _manifest[url];
    if (existing != null && await File(existing.path).exists()) {
      if (_pendingCancellations.remove(url)) {
        throw const WebDavDownloadCancelledException();
      }
      existing
        ..pinned = true
        ..accessedAt = DateTime.now().millisecondsSinceEpoch;
      await _saveManifest();
      onProgress?.call(
        WebDavDownloadProgress(
          receivedBytes: existing.size,
          totalBytes: existing.size,
        ),
      );
      return existing.path;
    }
    return download(
      url,
      headers: headers,
      allowBadCertificate: allowBadCertificate,
      pin: true,
      onProgress: onProgress,
    );
  }

  /// Stops protecting a resource from LRU eviction, while keeping it cached.
  Future<void> unpin(String url) async {
    await init();
    final entry = _manifest[url];
    if (entry == null || !entry.pinned) return;
    entry.pinned = false;
    await _evictIfNeeded();
    await _saveManifest();
  }

  /// Removes a single cached resource, including a pinned one.
  Future<bool> remove(String url) async {
    await init();
    final removed = await _removeEntry(url);
    await _saveManifest();
    return removed;
  }

  /// Clears playback-created cache files, preserving explicit downloads.
  Future<int> clearTransient() async {
    await init();
    final urls = _manifest.entries
        .where((entry) => !entry.value.pinned)
        .map((entry) => entry.key)
        .toList(growable: false);
    var removed = 0;
    for (final url in urls) {
      if (await _removeEntry(url)) removed++;
    }
    await _saveManifest();
    return removed;
  }

  /// Clears the cache. Explicit downloads require an opt-in destructive flag.
  Future<int> clear({bool includePinned = false}) async {
    await init();
    final urls = _manifest.entries
        .where((entry) => includePinned || !entry.value.pinned)
        .map((entry) => entry.key)
        .toList(growable: false);
    var removed = 0;
    for (final url in urls) {
      if (await _removeEntry(url)) removed++;
    }
    await _saveManifest();
    return removed;
  }

  /// Downloads [url] into the cache and returns the local file path.
  Future<String> download(
    String url, {
    required Map<String, String> headers,
    bool allowBadCertificate = false,
    bool pin = false,
    WebDavDownloadProgressCallback? onProgress,
  }) {
    final existing = _downloads[url];
    if (existing != null) {
      existing.pinRequested |= pin;
      if (onProgress != null) existing.listeners.add(onProgress);
      return existing.future;
    }

    late final Future<String> operation;
    final active = _ActiveDownload(pinRequested: pin);
    if (_pendingCancellations.remove(url)) active.cancel();
    if (onProgress != null) active.listeners.add(onProgress);
    operation =
        _download(
          url,
          headers: headers,
          allowBadCertificate: allowBadCertificate,
          active: active,
        ).whenComplete(() {
          if (identical(_downloads[url], active)) {
            _downloads.remove(url);
          }
        });
    active.future = operation;
    _downloads[url] = active;
    return operation;
  }

  Future<String> _download(
    String url, {
    required Map<String, String> headers,
    required bool allowBadCertificate,
    required _ActiveDownload active,
  }) async {
    await init();
    if (active.cancelled) throw const WebDavDownloadCancelledException();

    final ext = _extensionForUrl(url);
    final cacheFile = File('${cacheDir.path}/${_cacheKey(url)}$ext');
    final partialFile = File(
      '${cacheFile.path}.part-${DateTime.now().microsecondsSinceEpoch}',
    );
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    active.client = httpClient;
    if (allowBadCertificate) {
      httpClient.badCertificateCallback = (_, _, _) => true;
    }

    try {
      await _downloadFull(
        httpClient,
        url,
        headers,
        partialFile,
        onProgress: active.report,
      );
    } catch (_) {
      // Clean up partial file on failure.
      try {
        await partialFile.delete();
      } catch (_) {
        debugPrint('WebDavCache: failed to delete partial file on error');
      }
      if (active.cancelled) {

        throw const WebDavDownloadCancelledException();
      }
      rethrow;
    } finally {
      active.client = null;
      httpClient.close(force: true);
    }

    if (active.cancelled) {
      try {
        await partialFile.delete();
      } catch (_) {
        debugPrint('WebDavCache: failed to delete partial file (cancelled)');
      }
      throw const WebDavDownloadCancelledException();
    }

    final size = await partialFile.length();
    // Reject files smaller than 1 KiB — they're likely error pages.
    if (size < 1024) {
      try {
        await partialFile.delete();
      } catch (_) {
        debugPrint('WebDavCache: failed to delete partial file (rejected, too small)');
      }
      throw HttpException(
        'Downloaded file too small ($size bytes) — likely an error page',
      );
    }
    if (size > maxBytes && !active.pinRequested) {
      try {
        await partialFile.delete();
      } catch (_) {
        debugPrint('WebDavCache: failed to delete partial file (rejected, exceeds limit)');
      }
      throw HttpException(
        'Downloaded file exceeds cache limit ($size > $maxBytes bytes)',
      );
    }

    try {
      if (await cacheFile.exists()) await cacheFile.delete();
      if (active.cancelled) {
        await partialFile.delete();
        throw const WebDavDownloadCancelledException();
      }
      await partialFile.rename(cacheFile.path);
      if (active.cancelled) {
        await cacheFile.delete();
        throw const WebDavDownloadCancelledException();
      }
    } catch (_) {
      try {
        await partialFile.delete();
      } catch (_) {
        debugPrint('WebDavCache: failed to delete partial file (rename fallback)');
      }
      rethrow;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = _manifest[url];
    if (previous != null) _totalBytes -= previous.size;
    _manifest[url] = _CacheEntry(
      path: cacheFile.path,
      size: size,
      accessedAt: now,
      pinned: active.pinRequested || (previous?.pinned ?? false),
    );
    _totalBytes += size;
    await _evictIfNeeded();
    await _saveManifest();

    return cacheFile.path;
  }

  Future<void> _downloadFull(
    HttpClient client,
    String url,
    Map<String, String> headers,
    File cacheFile, {
    WebDavDownloadProgressCallback? onProgress,
  }) async {
    final uri = Uri.parse(url);
    final request = await client.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(
      const Duration(seconds: 120),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw HttpException(
        'Download failed: HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final contentType = response.headers.contentType?.mimeType ?? '';
    if (contentType.isNotEmpty &&
        contentType.startsWith('text/') &&
        !contentType.contains('xml')) {
      await response.drain<void>();
      throw HttpException(
        'Unexpected content type: $contentType (likely an error page)',
        uri: uri,
      );
    }

    final totalBytes = response.contentLength >= 0
        ? response.contentLength
        : null;
    var receivedBytes = 0;
    final sink = cacheFile.openWrite();
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(
          WebDavDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// Evicts transient entries until their LRU budget is satisfied.
  Future<void> _evictIfNeeded() async {
    while (_transientBytes > maxBytes) {
      final candidates = _manifest.entries.where(
        (entry) => !entry.value.pinned,
      );
      if (candidates.isEmpty) return;
      final first = candidates.first;
      var oldestUrl = first.key;
      var oldestAt = first.value.accessedAt;
      for (final entry in candidates) {
        if (entry.value.accessedAt < oldestAt) {
          oldestUrl = entry.key;
          oldestAt = entry.value.accessedAt;
        }
      }
      if (!await _removeEntry(oldestUrl)) return;
    }
  }

  Future<bool> _removeEntry(String url) async {
    final entry = _manifest[url];
    if (entry == null) return false;
    try {
      final file = File(entry.path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Keep the manifest entry when the platform still has the file open.
      return false;
    }
    _totalBytes -= entry.size;
    _manifest.remove(url);
    return true;
  }

  String _cacheKey(String url) {
    return sha256.convert(utf8.encode(url)).toString();
  }

  static String _extensionForUrl(String url) {
    return audioExtensionForPath(url);
  }

  // --- manifest ---

  Future<void> _loadManifest() async {
    final file = File('${cacheDir.path}/cache_manifest.json');
    try {
      if (!await file.exists()) return;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _manifest.clear();
      _totalBytes = 0;
      for (final entry in json.entries) {
        final value = entry.value as Map<String, dynamic>;
        final rawSize = value['size'] as int;
        final item = _CacheEntry(
          path:
              '${cacheDir.path}/${_cacheKey(entry.key)}${_extensionForUrl(entry.key)}',
          size: max(0, rawSize),
          accessedAt: value['accessedAt'] as int,
          pinned: value['pinned'] == true,
        );
        if (!await File(item.path).exists()) continue;
        _manifest[entry.key] = item;
        _totalBytes += item.size;
      }
      await _evictIfNeeded();
    } catch (_) {
      // Corrupt manifest — start fresh.
      _manifest.clear();
      _totalBytes = 0;
    }
  }

  Future<void> _saveManifest() async {
    final json = {
      for (final entry in _manifest.entries)
        entry.key: {
          'path': entry.value.path,
          'size': entry.value.size,
          'accessedAt': entry.value.accessedAt,
          'pinned': entry.value.pinned,
        },
    };
    final file = File('${cacheDir.path}/cache_manifest.json');
    try {
      await file.writeAsString(jsonEncode(json), flush: true);
    } catch (error) {
      if (kDebugMode) debugPrint('WebDavCache: failed to save manifest: $error');
    }
  }

  final Map<String, _CacheEntry> _manifest = {};
  int _totalBytes = 0;

  int get _pinnedBytes => _manifest.values
      .where((entry) => entry.pinned)
      .fold(0, (total, entry) => total + entry.size);

  int get _transientBytes => _totalBytes - _pinnedBytes;

  WebDavCacheStats get _stats {
    final pinnedEntries = _manifest.values
        .where((entry) => entry.pinned)
        .length;
    final pinnedBytes = _pinnedBytes;
    return WebDavCacheStats(
      totalBytes: _totalBytes,
      pinnedBytes: pinnedBytes,
      transientBytes: _totalBytes - pinnedBytes,
      totalEntries: _manifest.length,
      pinnedEntries: pinnedEntries,
    );
  }
}

class _CacheEntry {
  _CacheEntry({
    required this.path,
    required this.size,
    required this.accessedAt,
    required this.pinned,
  });

  final String path;
  final int size;
  int accessedAt;
  bool pinned;
}

typedef WebDavDownloadProgressCallback =
    void Function(WebDavDownloadProgress progress);

@immutable
class WebDavDownloadProgress {
  const WebDavDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0, 1);
  }
}

@immutable
class WebDavCacheStats {
  const WebDavCacheStats({
    required this.totalBytes,
    required this.pinnedBytes,
    required this.transientBytes,
    required this.totalEntries,
    required this.pinnedEntries,
  });

  final int totalBytes;
  final int pinnedBytes;
  final int transientBytes;
  final int totalEntries;
  final int pinnedEntries;

  int get transientEntries => totalEntries - pinnedEntries;
}

@immutable
class WebDavCacheItem {
  const WebDavCacheItem({
    required this.url,
    required this.path,
    required this.size,
    required this.pinned,
    required this.accessedAt,
  });

  final String url;
  final String path;
  final int size;
  final bool pinned;
  final DateTime accessedAt;
}

class WebDavDownloadCancelledException implements Exception {
  const WebDavDownloadCancelledException();

  @override
  String toString() => '下载已取消';
}

class _ActiveDownload {
  _ActiveDownload({required this.pinRequested});

  bool pinRequested;
  bool cancelled = false;
  HttpClient? client;
  late final Future<String> future;
  final List<WebDavDownloadProgressCallback> listeners = [];

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    client?.close(force: true);
  }

  void report(WebDavDownloadProgress progress) {
    for (final listener in List.of(listeners)) {
      listener(progress);
    }
  }
}
