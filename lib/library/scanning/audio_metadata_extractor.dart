import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:convert';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import 'flac_tags_reader.dart';
import 'image_bytes.dart';

class ExtractedArtwork {
  const ExtractedArtwork({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class ExtractedAudioMetadata {
  const ExtractedAudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.isCompilation = false,
    this.duration = Duration.zero,
    this.trackNumber = 0,
    this.discNumber = 0,
    this.year,
    this.genre,
    this.lyrics,
    this.artwork,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final bool isCompilation;
  final Duration duration;
  final int trackNumber;
  final int discNumber;
  final int? year;
  final String? genre;
  final String? lyrics;
  final ExtractedArtwork? artwork;

  ExtractedAudioMetadata copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    bool? isCompilation,
    Duration? duration,
    int? trackNumber,
    int? discNumber,
    int? year,
    String? genre,
    String? lyrics,
    ExtractedArtwork? artwork,
    bool clearArtwork = false,
  }) {
    return ExtractedAudioMetadata(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      isCompilation: isCompilation ?? this.isCompilation,
      duration: duration ?? this.duration,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      lyrics: lyrics ?? this.lyrics,
      artwork: clearArtwork ? null : (artwork ?? this.artwork),
    );
  }
}

/// Contract for local, WebDAV, and future scan providers.
///
/// **Tags outrank artwork.** Identity fields (title / artist / album) must be
/// recoverable even when embedded cover art is missing, truncated (partial
/// HTTP Range), corrupt, or multi‑megabyte. Artwork is always best-effort:
/// `null` means "no cover", never "unknown track".
///
/// Prefer implementing via [PackageAudioMetadataExtractor] or the shared
/// [extractAudioFileMetadata] helper so every provider inherits the same
/// tags-first behavior.
abstract interface class AudioMetadataExtractor {
  /// Extract scan metadata for [file].
  ///
  /// Implementations must not require a successful artwork decode to return
  /// title / artist / album when those tags are present in the container.
  Future<ExtractedAudioMetadata> extract(File file);
}

class PackageAudioMetadataExtractor implements AudioMetadataExtractor {
  const PackageAudioMetadataExtractor();

  @override
  Future<ExtractedAudioMetadata> extract(File file) {
    return Isolate.run(() => extractAudioFileMetadata(file.path));
  }
}

/// Shared package-backed extract used by [PackageAudioMetadataExtractor].
///
/// Order:
/// 1. Full parse with images (local files, small covers).
/// 2. Tags-only package parse if (1) fails (truncated Range + large art).
/// 3. Dedicated FLAC Vorbis walker that never loads `PICTURE` payloads —
///    shared by every provider so multi‑MB covers cannot erase identity.
ExtractedAudioMetadata extractAudioFileMetadata(String path) {
  try {
    final withArt = _extractMetadata(path, getImage: true);
    // Truncated FLAC/WebDAV reads can return a zero-padded picture buffer
    // that still has a PNG/JPEG header. Drop invalid art so callers retry
    // with a larger range or keep tags-only without poisoning the cache.
    final art = withArt.artwork;
    if (art == null || looksLikeCompleteImageBytes(art.bytes)) {
      return withArt;
    }
    return withArt.copyWith(clearArtwork: true);
  } catch (_) {
    // Fall through to tags-only paths.
  }
  try {
    return _extractMetadata(path, getImage: false);
  } catch (error) {
    final flac = _extractFlacTagsOnly(path);
    if (flac != null) return flac;
    Error.throwWithStackTrace(error, StackTrace.current);
  }
}

ExtractedAudioMetadata? _extractFlacTagsOnly(String path) {
  if (!path.toLowerCase().endsWith('.flac')) return null;
  final tags = readFlacTags(File(path));
  if (tags == null) return null;
  return ExtractedAudioMetadata(
    title: tags.title,
    artist: tags.artist,
    album: tags.album,
    albumArtist: tags.albumArtist,
    isCompilation: tags.isCompilation,
    duration: tags.duration,
    trackNumber: tags.trackNumber,
    discNumber: tags.discNumber,
    year: tags.year,
    genre: tags.genre,
    lyrics: tags.lyrics,
  );
}

ExtractedAudioMetadata _extractMetadata(String path, {required bool getImage}) {
  final file = File(path);
  final metadata = readMetadata(file, getImage: getImage);
  final identity = _extractAlbumIdentity(file);
  final picture = getImage
      ? metadata.pictures
            .where((picture) => picture.pictureType == PictureType.coverFront)
            .firstOrNull
      : null;
  final fallbackPicture = getImage ? metadata.pictures.firstOrNull : null;
  final selectedPicture = picture ?? fallbackPicture;
  final year = metadata.year?.year;
  final duration = readMp3SeekHeaderDuration(file) ?? metadata.duration;
  return ExtractedAudioMetadata(
    title: metadata.title,
    artist: identity.trackArtist ?? metadata.artist,
    album: metadata.album,
    albumArtist: identity.albumArtist,
    isCompilation: identity.isCompilation,
    duration: duration ?? Duration.zero,
    trackNumber: metadata.trackNumber ?? 0,
    discNumber: metadata.discNumber ?? 0,
    year: year == null || year <= 0 ? null : year,
    genre: metadata.genres.firstOrNull,
    lyrics: metadata.lyrics,
    artwork: selectedPicture == null
        ? null
        : ExtractedArtwork(
            bytes: selectedPicture.bytes,
            mimeType: selectedPicture.mimetype,
          ),
  );
}

_AlbumIdentity _extractAlbumIdentity(File file) {
  String? trackArtist;
  String? albumArtist;
  var isCompilation = false;
  try {
    for (final bytes in _readTagRegions(file)) {
      trackArtist ??= _readId3TextFrame(bytes, 'TPE1');
      albumArtist ??= _readId3TextFrame(bytes, 'TPE2');
      isCompilation =
          isCompilation || _truthy(_readId3TextFrame(bytes, 'TCMP'));
      albumArtist ??= _readLengthPrefixedTag(bytes, const [
        'ALBUMARTIST',
        'ALBUM ARTIST',
      ]);
      trackArtist ??= _readLengthPrefixedTag(bytes, const ['ARTIST']);
      isCompilation =
          isCompilation ||
          _truthy(_readLengthPrefixedTag(bytes, const ['COMPILATION']));
      albumArtist ??= _readMp4StringTag(bytes, 'aART');
      isCompilation = isCompilation || _readMp4BooleanTag(bytes, 'cpil');
    }
  } catch (_) {
    // The generic reader already produced usable metadata. Supplementary
    // release identity must never make a playable track disappear.
  }
  return _AlbumIdentity(
    trackArtist: trackArtist,
    albumArtist: albumArtist,
    isCompilation: isCompilation,
  );
}

List<Uint8List> _readTagRegions(File file) {
  const prefixLimit = 1024 * 1024;
  const id3Limit = 8 * 1024 * 1024;
  const tailLimit = 1024 * 1024;
  final reader = file.openSync();
  try {
    final length = reader.lengthSync();
    if (length == 0) return const [];
    var prefixLength = length < prefixLimit ? length : prefixLimit;
    reader.setPositionSync(0);
    var prefix = reader.readSync(prefixLength);
    if (prefix.length >= 10 &&
        prefix[0] == 0x49 &&
        prefix[1] == 0x44 &&
        prefix[2] == 0x33) {
      final tagLength = 10 + _syncSafeUint32(prefix, 6);
      final cappedTagLength = tagLength < id3Limit ? tagLength : id3Limit;
      if (cappedTagLength > prefixLength) {
        prefixLength = cappedTagLength < length ? cappedTagLength : length;
        reader.setPositionSync(0);
        prefix = reader.readSync(prefixLength);
      }
    }
    if (length <= prefixLength) return [prefix];
    final tailLength = length < tailLimit ? length : tailLimit;
    reader.setPositionSync(length - tailLength);
    return [prefix, reader.readSync(tailLength)];
  } finally {
    reader.closeSync();
  }
}

String? _readId3TextFrame(Uint8List bytes, String frameId) {
  if (bytes.length < 10 ||
      bytes[0] != 0x49 ||
      bytes[1] != 0x44 ||
      bytes[2] != 0x33) {
    return null;
  }
  final version = bytes[3];
  if (version != 3 && version != 4) return null;
  final tagEnd = (10 + _syncSafeUint32(bytes, 6)).clamp(10, bytes.length);
  var offset = 10;
  while (offset + 10 <= tagEnd) {
    if (bytes.sublist(offset, offset + 4).every((value) => value == 0)) {
      break;
    }
    final id = ascii.decode(bytes.sublist(offset, offset + 4));
    final frameLength = version == 4
        ? _syncSafeUint32(bytes, offset + 4)
        : _bigEndianUint32(bytes, offset + 4);
    final payloadStart = offset + 10;
    final payloadEnd = payloadStart + frameLength;
    if (frameLength <= 0 || payloadEnd > tagEnd) break;
    if (id == frameId) {
      return _decodeId3Text(bytes.sublist(payloadStart, payloadEnd));
    }
    offset = payloadEnd;
  }
  return null;
}

String? _decodeId3Text(Uint8List payload) {
  if (payload.isEmpty) return null;
  final encoding = payload.first;
  final data = payload.sublist(1);
  String value;
  switch (encoding) {
    case 0:
      value = latin1.decode(data, allowInvalid: true);
    case 1:
      final littleEndian =
          data.length >= 2 && data[0] == 0xff && data[1] == 0xfe;
      final hasBom =
          data.length >= 2 &&
          ((data[0] == 0xff && data[1] == 0xfe) ||
              (data[0] == 0xfe && data[1] == 0xff));
      value = _decodeUtf16(
        data,
        start: hasBom ? 2 : 0,
        littleEndian: littleEndian,
      );
    case 2:
      value = _decodeUtf16(data, start: 0, littleEndian: false);
    case 3:
      value = utf8.decode(data, allowMalformed: true);
    default:
      return null;
  }
  return _clean(value.replaceAll('\u0000', ''));
}

String _decodeUtf16(
  Uint8List bytes, {
  required int start,
  required bool littleEndian,
}) {
  final codeUnits = <int>[];
  for (var index = start; index + 1 < bytes.length; index += 2) {
    codeUnits.add(
      littleEndian
          ? bytes[index] | (bytes[index + 1] << 8)
          : (bytes[index] << 8) | bytes[index + 1],
    );
  }
  return String.fromCharCodes(codeUnits);
}

int _syncSafeUint32(Uint8List bytes, int offset) =>
    ((bytes[offset] & 0x7f) << 21) |
    ((bytes[offset + 1] & 0x7f) << 14) |
    ((bytes[offset + 2] & 0x7f) << 7) |
    (bytes[offset + 3] & 0x7f);

String? _readLengthPrefixedTag(Uint8List bytes, List<String> names) {
  for (final name in names) {
    final pattern = ascii.encode('$name=');
    for (var offset = 4; offset + pattern.length <= bytes.length; offset++) {
      if (!_matchesAsciiCaseInsensitive(bytes, offset, pattern)) continue;
      final length =
          bytes[offset - 4] |
          (bytes[offset - 3] << 8) |
          (bytes[offset - 2] << 16) |
          (bytes[offset - 1] << 24);
      if (length < pattern.length ||
          length > 64 * 1024 ||
          offset + length > bytes.length) {
        continue;
      }
      return _clean(
        utf8.decode(
          bytes.sublist(offset + pattern.length, offset + length),
          allowMalformed: true,
        ),
      );
    }
  }
  return null;
}

/// Reads the frame count from a bounded MP3 Xing/Info header.
///
/// Some VBR encoders write `Info` rather than `Xing`. The generic metadata
/// reader currently falls back to first-frame bitrate in that case, which can
/// be badly wrong for long files. This parser never scans the audio payload.
Duration? readMp3SeekHeaderDuration(File file) {
  if (!file.path.toLowerCase().endsWith('.mp3')) return null;
  final reader = file.openSync();
  try {
    if (reader.lengthSync() < 16) return null;
    reader.setPositionSync(0);
    final prefix = reader.readSync(10);
    var audioOffset = 0;
    if (prefix.length == 10 &&
        prefix[0] == 0x49 &&
        prefix[1] == 0x44 &&
        prefix[2] == 0x33) {
      audioOffset = 10 + _syncSafeUint32(prefix, 6);
    }
    if (audioOffset >= reader.lengthSync()) return null;
    reader.setPositionSync(audioOffset);
    final available = reader.lengthSync() - audioOffset;
    final probeLength = available < 8192 ? available : 8192;
    final bytes = reader.readSync(probeLength);
    final frameOffset = _findMp3FrameOffset(bytes);
    if (frameOffset == null) return null;
    final header = bytes.sublist(frameOffset, frameOffset + 4);
    final versionBits = (header[1] >> 3) & 0x03;
    final layerBits = (header[1] >> 1) & 0x03;
    final sampleRateIndex = (header[2] >> 2) & 0x03;
    final sampleRate = _mp3SampleRate(versionBits, sampleRateIndex);
    final samplesPerFrame = _mp3SamplesPerFrame(versionBits, layerBits);
    if (sampleRate == null || samplesPerFrame == null) return null;

    for (final marker in const <String>['Xing', 'Info']) {
      final markerOffset = _indexOfAscii(
        bytes,
        marker,
        frameOffset + 4,
        bytes.length,
      );
      if (markerOffset < 0 || markerOffset + 12 > bytes.length) continue;
      final flags = _bigEndianUint32(bytes, markerOffset + 4);
      if (flags & 0x01 == 0) continue;
      final frameCount = _bigEndianUint32(bytes, markerOffset + 8);
      if (frameCount <= 0) continue;
      return Duration(
        microseconds: (frameCount * samplesPerFrame * 1000000) ~/ sampleRate,
      );
    }
    return null;
  } finally {
    reader.closeSync();
  }
}

int? _findMp3FrameOffset(Uint8List bytes) {
  for (var index = 0; index + 4 <= bytes.length; index++) {
    if (bytes[index] != 0xff || (bytes[index + 1] & 0xe0) != 0xe0) continue;
    final versionBits = (bytes[index + 1] >> 3) & 0x03;
    final layerBits = (bytes[index + 1] >> 1) & 0x03;
    final bitrateIndex = (bytes[index + 2] >> 4) & 0x0f;
    final sampleRateIndex = (bytes[index + 2] >> 2) & 0x03;
    if (versionBits == 0x01 ||
        layerBits == 0 ||
        bitrateIndex == 0 ||
        bitrateIndex == 0x0f ||
        sampleRateIndex == 0x03) {
      continue;
    }
    return index;
  }
  return null;
}

int? _mp3SampleRate(int versionBits, int index) {
  const rates = <int, List<int>>{
    0x03: <int>[44100, 48000, 32000],
    0x02: <int>[22050, 24000, 16000],
    0x00: <int>[11025, 12000, 8000],
  };
  final values = rates[versionBits];
  return values == null || index >= values.length ? null : values[index];
}

int? _mp3SamplesPerFrame(int versionBits, int layerBits) {
  return switch (layerBits) {
    0x03 => 384,
    0x02 => 1152,
    0x01 => versionBits == 0x03 ? 1152 : 576,
    _ => null,
  };
}

bool _matchesAsciiCaseInsensitive(
  Uint8List bytes,
  int offset,
  List<int> pattern,
) {
  if (offset < 0 || offset + pattern.length > bytes.length) return false;
  for (var index = 0; index < pattern.length; index++) {
    final actual = bytes[offset + index];
    final expected = pattern[index];
    final normalizedActual = actual >= 0x61 && actual <= 0x7a
        ? actual - 0x20
        : actual;
    final normalizedExpected = expected >= 0x61 && expected <= 0x7a
        ? expected - 0x20
        : expected;
    if (normalizedActual != normalizedExpected) return false;
  }
  return true;
}

String? _readMp4StringTag(Uint8List bytes, String atom) {
  final atomBytes = ascii.encode(atom);
  for (var index = 4; index + atomBytes.length < bytes.length; index++) {
    if (!_matches(bytes, index, atomBytes)) continue;
    final outerSize = _bigEndianUint32(bytes, index - 4);
    final outerEnd = index - 4 + outerSize;
    if (outerSize < 24 || outerEnd > bytes.length) continue;
    final dataIndex = _indexOfAscii(bytes, 'data', index + 4, outerEnd);
    if (dataIndex < 0 || dataIndex + 12 > outerEnd) continue;
    return _clean(
      utf8.decode(
        bytes.sublist(dataIndex + 12, outerEnd),
        allowMalformed: true,
      ),
    );
  }
  return null;
}

bool _readMp4BooleanTag(Uint8List bytes, String atom) {
  final atomBytes = ascii.encode(atom);
  for (var index = 4; index + atomBytes.length < bytes.length; index++) {
    if (!_matches(bytes, index, atomBytes)) continue;
    final outerSize = _bigEndianUint32(bytes, index - 4);
    final outerEnd = index - 4 + outerSize;
    if (outerSize < 20 || outerEnd > bytes.length) continue;
    final dataIndex = _indexOfAscii(bytes, 'data', index + 4, outerEnd);
    if (dataIndex < 0 || dataIndex + 12 >= outerEnd) continue;
    return bytes.sublist(dataIndex + 12, outerEnd).any((value) => value != 0);
  }
  return false;
}

int _indexOfAscii(Uint8List bytes, String value, int start, int end) {
  final pattern = ascii.encode(value);
  for (var index = start; index + pattern.length <= end; index++) {
    if (_matches(bytes, index, pattern)) return index;
  }
  return -1;
}

bool _matches(Uint8List bytes, int offset, List<int> pattern) {
  if (offset < 0 || offset + pattern.length > bytes.length) return false;
  for (var index = 0; index < pattern.length; index++) {
    if (bytes[offset + index] != pattern[index]) return false;
  }
  return true;
}

int _bigEndianUint32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

String? _clean(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}

bool _truthy(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

class _AlbumIdentity {
  const _AlbumIdentity({
    required this.trackArtist,
    required this.albumArtist,
    required this.isCompilation,
  });

  final String? trackArtist;
  final String? albumArtist;
  final bool isCompilation;
}
