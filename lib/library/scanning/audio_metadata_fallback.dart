import 'dart:io';
import 'dart:typed_data';

import 'audio_format_registry.dart';
import 'audio_metadata_extractor.dart';

const filenameOnlyAudioMetadata = ExtractedAudioMetadata();

/// Allows filename-only import only when the bytes identify a format whose
/// tags are intentionally unsupported (raw AAC), or a recognisable MP3 whose
/// non-essential tags are malformed. A renamed damaged file is not imported.
bool canUseFilenameMetadataFallback(String path, Uint8List bytes) {
  final format = audioFormatForPath(path);
  if (format == null || bytes.isEmpty) return false;
  return switch (format.extension) {
    '.mp3' => _looksLikeMp3(bytes),
    '.aac' => _looksLikeAdtsAac(bytes),
    _ => false,
  };
}

Future<ExtractedAudioMetadata?> readFilenameMetadataFallback(
  File file,
  String sourcePath,
) async {
  final reader = await file.open();
  try {
    final bytes = await reader.read(64 * 1024);
    return canUseFilenameMetadataFallback(sourcePath, bytes)
        ? filenameOnlyAudioMetadata
        : null;
  } finally {
    await reader.close();
  }
}

bool _looksLikeMp3(Uint8List bytes) {
  // An ID3 marker alone does not prove that an audio stream survived a
  // truncated download. Require an MPEG frame signature in the probe bytes.
  final searchLength = bytes.length > 65537 ? 65536 : bytes.length - 1;
  for (var index = 0; index < searchLength; index++) {
    if (bytes[index] != 0xff || (bytes[index + 1] & 0xe0) != 0xe0) continue;
    final version = (bytes[index + 1] >> 3) & 0x03;
    final layer = (bytes[index + 1] >> 1) & 0x03;
    if (version != 0x01 && layer != 0) return true;
  }
  return false;
}

bool _looksLikeAdtsAac(Uint8List bytes) {
  var start = 0;
  if (bytes.length >= 10 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33) {
    final tagSize =
        ((bytes[6] & 0x7f) << 21) |
        ((bytes[7] & 0x7f) << 14) |
        ((bytes[8] & 0x7f) << 7) |
        (bytes[9] & 0x7f);
    start = 10 + tagSize;
  }
  final searchEnd = bytes.length > start + 4096
      ? start + 4096
      : bytes.length - 1;
  for (var index = start; index < searchEnd; index++) {
    // ADTS: 12-bit sync word, MPEG ID may vary, layer must be 00.
    if (bytes[index] == 0xff && (bytes[index + 1] & 0xf6) == 0xf0) {
      return true;
    }
  }
  return false;
}
