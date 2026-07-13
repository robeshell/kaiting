import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:convert';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

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
}

abstract interface class AudioMetadataExtractor {
  Future<ExtractedAudioMetadata> extract(File file);
}

class PackageAudioMetadataExtractor implements AudioMetadataExtractor {
  const PackageAudioMetadataExtractor();

  @override
  Future<ExtractedAudioMetadata> extract(File file) {
    return Isolate.run(() => _extractMetadata(file.path));
  }
}

ExtractedAudioMetadata _extractMetadata(String path) {
  final file = File(path);
  final metadata = readMetadata(file, getImage: true);
  final identity = _extractAlbumIdentity(file);
  final picture = metadata.pictures
      .where((picture) => picture.pictureType == PictureType.coverFront)
      .firstOrNull;
  final fallbackPicture = metadata.pictures.firstOrNull;
  final selectedPicture = picture ?? fallbackPicture;
  final year = metadata.year?.year;
  return ExtractedAudioMetadata(
    title: metadata.title,
    artist: identity.trackArtist ?? metadata.artist,
    album: metadata.album,
    albumArtist: identity.albumArtist,
    isCompilation: identity.isCompilation,
    duration: metadata.duration ?? Duration.zero,
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
  for (var offset = 4; offset < bytes.length; offset++) {
    final length =
        bytes[offset - 4] |
        (bytes[offset - 3] << 8) |
        (bytes[offset - 2] << 16) |
        (bytes[offset - 1] << 24);
    if (length <= 0 || length > 64 * 1024 || offset + length > bytes.length) {
      continue;
    }
    final text = utf8.decode(
      bytes.sublist(offset, offset + length),
      allowMalformed: true,
    );
    final separator = text.indexOf('=');
    if (separator <= 0) continue;
    final key = text.substring(0, separator).trim().toUpperCase();
    if (!names.contains(key)) continue;
    return _clean(text.substring(separator + 1));
  }
  return null;
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
