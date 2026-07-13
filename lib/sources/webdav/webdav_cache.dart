import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class WebDavCache {
  WebDavCache({
    required this.cacheDir,
    this.maxBytes = 500 * 1024 * 1024, // 500 MiB
  });

  final Directory cacheDir;
  final int maxBytes;
  final Map<String, Future<String>> _downloads = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await cacheDir.create(recursive: true);
    await _loadManifest();
    await _cleanStaleFiles();
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
    } catch (_) {}
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

  /// Downloads [url] into the cache and returns the local file path.
  Future<String> download(
    String url, {
    required Map<String, String> headers,
    bool allowBadCertificate = false,
  }) {
    final existing = _downloads[url];
    if (existing != null) return existing;

    late final Future<String> operation;
    operation =
        _download(
          url,
          headers: headers,
          allowBadCertificate: allowBadCertificate,
        ).whenComplete(() {
          if (identical(_downloads[url], operation)) {
            _downloads.remove(url);
          }
        });
    _downloads[url] = operation;
    return operation;
  }

  Future<String> _download(
    String url, {
    required Map<String, String> headers,
    required bool allowBadCertificate,
  }) async {
    await init();

    final ext = _extensionForUrl(url);
    final cacheFile = File('${cacheDir.path}/${_cacheKey(url)}$ext');
    final partialFile = File(
      '${cacheFile.path}.part-${DateTime.now().microsecondsSinceEpoch}',
    );
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    if (allowBadCertificate) {
      httpClient.badCertificateCallback = (_, _, _) => true;
    }

    try {
      await _downloadFull(httpClient, url, headers, partialFile);
    } catch (e) {
      // Clean up partial file on failure.
      try {
        await partialFile.delete();
      } catch (_) {}
      rethrow;
    } finally {
      httpClient.close(force: true);
    }

    final size = await partialFile.length();
    // Reject files smaller than 1 KiB — they're likely error pages.
    if (size < 1024) {
      try {
        await partialFile.delete();
      } catch (_) {}
      throw HttpException(
        'Downloaded file too small ($size bytes) — likely an error page',
      );
    }
    if (size > maxBytes) {
      try {
        await partialFile.delete();
      } catch (_) {}
      throw HttpException(
        'Downloaded file exceeds cache limit ($size > $maxBytes bytes)',
      );
    }

    try {
      if (await cacheFile.exists()) await cacheFile.delete();
      await partialFile.rename(cacheFile.path);
    } catch (_) {
      try {
        await partialFile.delete();
      } catch (_) {}
      rethrow;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = _manifest[url];
    if (previous != null) _totalBytes -= previous.size;
    _manifest[url] = _CacheEntry(
      path: cacheFile.path,
      size: size,
      accessedAt: now,
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
    File cacheFile,
  ) async {
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

    final sink = cacheFile.openWrite();
    try {
      await response.pipe(sink);
    } finally {
      await sink.close();
    }
  }

  /// Evicts the least-recently-accessed entries until [maxBytes] is satisfied.
  Future<void> _evictIfNeeded() async {
    while (_totalBytes > maxBytes && _manifest.isNotEmpty) {
      var oldestUrl = _manifest.keys.first;
      var oldestAt = _manifest[oldestUrl]!.accessedAt;
      for (final entry in _manifest.entries) {
        if (entry.value.accessedAt < oldestAt) {
          oldestUrl = entry.key;
          oldestAt = entry.value.accessedAt;
        }
      }
      await _removeEntry(oldestUrl);
    }
  }

  Future<void> _removeEntry(String url) async {
    final entry = _manifest[url];
    if (entry == null) return;
    try {
      await File(entry.path).delete();
    } catch (_) {
      // Best-effort deletion.
    }
    _totalBytes -= entry.size;
    _manifest.remove(url);
  }

  String _cacheKey(String url) {
    return sha256.convert(utf8.encode(url)).toString();
  }

  static String _extensionForUrl(String url) {
    final withoutQuery = url.split('?').first;
    final dotIndex = withoutQuery.lastIndexOf('.');
    if (dotIndex < 0) return '';
    final ext = withoutQuery.substring(dotIndex).toLowerCase();
    if (ext == '.mp3' ||
        ext == '.flac' ||
        ext == '.m4a' ||
        ext == '.ogg' ||
        ext == '.opus' ||
        ext == '.wav' ||
        ext == '.aac' ||
        ext == '.wma') {
      return ext;
    }
    return '';
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
        );
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
        },
    };
    final file = File('${cacheDir.path}/cache_manifest.json');
    try {
      await file.writeAsString(jsonEncode(json), flush: true);
    } catch (error) {
      debugPrint('WebDavCache: failed to save manifest: $error');
    }
  }

  final Map<String, _CacheEntry> _manifest = {};
  int _totalBytes = 0;
}

class _CacheEntry {
  _CacheEntry({
    required this.path,
    required this.size,
    required this.accessedAt,
  });

  final String path;
  final int size;
  int accessedAt;
}
