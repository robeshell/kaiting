import 'dart:io';

import 'package:flutter/foundation.dart';

import 'artwork_uri.dart';

/// Lightweight container checks for embedded / downloaded artwork bytes.
///
/// Some FLAC/WebDAV paths can produce a buffer whose *declared* picture length
/// is larger than the bytes actually available (the rest stays zero-filled).
/// Those buffers look like PNGs/JPEGs in the header but fail Flutter's codec.
bool looksLikeCompleteImageBytes(List<int> bytes) {
  if (bytes.length < 24) return false;
  if (_isPng(bytes)) return _pngHasIend(bytes);
  if (_isJpeg(bytes)) return _jpegHasEoi(bytes);
  if (_isWebp(bytes)) return true;
  return false;
}

/// In-memory validity results for local artwork files.
///
/// Album grids call [artworkFileLooksValid] from build/layout; without a cache
/// each visible cell re-opens the file and reads head/tail on the UI thread.
const int _artworkValidityCacheLimit = 512;
final Map<String, bool> _artworkValidityCache = <String, bool>{};

/// Clears the artwork validity cache. Intended for tests.
void clearArtworkValidityCache() => _artworkValidityCache.clear();

/// Returns false when [artworkUri] is a local file that is missing or truncated.
///
/// Results are cached by URI so scrolling a large album grid does not re-run
/// sync filesystem checks for the same cover on every frame.
bool artworkFileLooksValid(String? artworkUri) {
  if (artworkUri == null || artworkUri.isEmpty) return false;
  final cached = _artworkValidityCache[artworkUri];
  if (cached != null) return cached;
  final valid = _artworkFileLooksValidUncached(artworkUri);
  // Cache only successful checks so scrolling the grid is fast. A failed
  // check during the first cold-start frame (when dozens of cells all read
  // from the filesystem at once) must not be stored permanently — retry on
  // the next rebuild.
  if (valid) {
    if (_artworkValidityCache.length >= _artworkValidityCacheLimit) {
      _artworkValidityCache.remove(_artworkValidityCache.keys.first);
    }
    _artworkValidityCache[artworkUri] = valid;
  }
  return valid;
}

bool _artworkFileLooksValidUncached(String artworkUri) {
  final uri = resolveArtworkUri(artworkUri);
  if (uri == null) {
    // Custom providers may own non-file schemes that this package cannot
    // resolve locally. Preserve their keys; only local cache keys are checked
    // against the filesystem here.
    final unresolved = Uri.tryParse(artworkUri);
    return unresolved != null &&
        unresolved.hasScheme &&
        unresolved.scheme != 'file';
  }
  if (uri.scheme != 'file') return true;
  try {
    final file = File.fromUri(uri);
    if (!file.existsSync()) return false;
    final length = file.lengthSync();
    if (length < 24) return false;
    // Read head + tail only — covers multi-MB album art without loading all.
    final raf = file.openSync();
    try {
      final head = raf.readSync(32);
      raf.setPositionSync(length > 64 ? length - 32 : 0);
      final tail = raf.readSync(32);
      final combined = Uint8List(head.length + tail.length)
        ..setAll(0, head)
        ..setAll(head.length, tail);
      if (_isPng(head)) {
        return tail.contains(0x49) && // rough IEND presence in tail
            _pngTailHasIend(tail);
      }
      if (_isJpeg(head)) return _jpegHasEoi(tail) || _jpegHasEoi(combined);
      if (_isWebp(head)) return length > 16;
      return false;
    } finally {
      raf.closeSync();
    }
  } catch (error) {
    debugPrint('image_bytes: validation failed: $error');
    return false;
  }
}

bool _isPng(List<int> bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4e &&
    bytes[3] == 0x47 &&
    bytes[4] == 0x0d &&
    bytes[5] == 0x0a &&
    bytes[6] == 0x1a &&
    bytes[7] == 0x0a;

bool _isJpeg(List<int> bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[2] == 0xff;

bool _isWebp(List<int> bytes) =>
    bytes.length >= 12 &&
    bytes[0] == 0x52 &&
    bytes[1] == 0x49 &&
    bytes[2] == 0x46 &&
    bytes[3] == 0x46 &&
    bytes[8] == 0x57 &&
    bytes[9] == 0x45 &&
    bytes[10] == 0x42 &&
    bytes[11] == 0x50;

bool _pngHasIend(List<int> bytes) {
  // Trailing IEND chunk is 12 bytes:
  //   00 00 00 00 | 49 45 4E 44 | AE 42 60 82
  // so the type "IEND" starts at length-8, not length-12. Scan the last
  // 512 bytes inclusive of that position (large album-art PNGs never hit the
  // small-image full scan below).
  if (bytes.length < 12) return false;
  final minIndex = bytes.length > 512 ? bytes.length - 512 : 0;
  for (var i = bytes.length - 4; i >= minIndex; i--) {
    if (bytes[i] == 0x49 &&
        bytes[i + 1] == 0x45 &&
        bytes[i + 2] == 0x4e &&
        bytes[i + 3] == 0x44) {
      return true;
    }
  }
  // Full scan for smaller images (truncated buffers, odd layouts).
  if (bytes.length < 4096) {
    for (var i = 0; i + 3 < bytes.length; i++) {
      if (bytes[i] == 0x49 &&
          bytes[i + 1] == 0x45 &&
          bytes[i + 2] == 0x4e &&
          bytes[i + 3] == 0x44) {
        return true;
      }
    }
  }
  return false;
}

bool _pngTailHasIend(List<int> tail) {
  for (var i = 0; i + 3 < tail.length; i++) {
    if (tail[i] == 0x49 &&
        tail[i + 1] == 0x45 &&
        tail[i + 2] == 0x4e &&
        tail[i + 3] == 0x44) {
      return true;
    }
  }
  return false;
}

bool _jpegHasEoi(List<int> bytes) {
  for (var i = bytes.length - 2; i >= 0 && i > bytes.length - 64; i--) {
    if (bytes[i] == 0xff && bytes[i + 1] == 0xd9) return true;
  }
  return false;
}
