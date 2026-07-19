import 'dart:io';
import 'dart:typed_data';

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

/// Returns false when [artworkUri] is a local file that is missing or truncated.
bool artworkFileLooksValid(String? artworkUri) {
  if (artworkUri == null || artworkUri.isEmpty) return false;
  final uri = Uri.tryParse(artworkUri);
  if (uri == null || uri.scheme != 'file') return true;
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
  } catch (_) {
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
    bytes.length >= 4 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;

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
