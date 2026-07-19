import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Lightweight FLAC identity reader for scan providers.
///
/// Walks metadata block headers and only materializes `VORBIS_COMMENT` payloads.
/// `PICTURE` / padding / seek tables are skipped by size so a multi‑megabyte
/// cover never has to be loaded. Works on truncated files (e.g. WebDAV Range
/// prefixes) as long as the Vorbis comment block itself is fully present.
class FlacTags {
  const FlacTags({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.lyrics,
    this.year,
    this.trackNumber = 0,
    this.discNumber = 0,
    this.isCompilation = false,
    this.duration = Duration.zero,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final String? lyrics;
  final int? year;
  final int trackNumber;
  final int discNumber;
  final bool isCompilation;
  final Duration duration;
}

/// Returns null when the file is not FLAC or has no readable Vorbis comments.
FlacTags? readFlacTags(File file) {
  RandomAccessFile? reader;
  try {
    reader = file.openSync();
    final length = reader.lengthSync();
    if (length < 8) return null;
    final magic = reader.readSync(4);
    if (magic.length < 4 ||
        magic[0] != 0x66 ||
        magic[1] != 0x4c ||
        magic[2] != 0x61 ||
        magic[3] != 0x43) {
      return null;
    }

    String? title;
    String? artist;
    String? album;
    String? albumArtist;
    String? genre;
    String? lyrics;
    int? year;
    var trackNumber = 0;
    var discNumber = 0;
    var isCompilation = false;
    var duration = Duration.zero;
    var sawVorbis = false;

    var isLast = false;
    while (!isLast) {
      final position = reader.positionSync();
      if (position + 4 > length) break;
      final header = reader.readSync(4);
      if (header.length < 4) break;
      isLast = header[0] >> 7 == 1;
      final type = header[0] & 0x7f;
      final blockLength =
          (header[1] << 16) | (header[2] << 8) | header[3];
      final payloadStart = position + 4;
      final payloadEnd = payloadStart + blockLength;
      if (blockLength < 0 || payloadEnd > length) {
        // Truncated Range: cannot finish this block.
        break;
      }

      if (type == 0 && blockLength >= 34) {
        // STREAMINFO — sample rate + total samples for duration.
        final info = reader.readSync(blockLength);
        if (info.length >= 18) {
          final packed = ByteData.sublistView(
            Uint8List.fromList(info),
            10,
            18,
          ).getUint64(0);
          final sampleRate = (packed >> 44) & 0xfffff;
          final totalSamples = packed & 0xfffffffff;
          if (sampleRate > 0 && totalSamples > 0) {
            duration = Duration(
              milliseconds: (totalSamples * 1000) ~/ sampleRate,
            );
          }
        }
      } else if (type == 4) {
        final payload = reader.readSync(blockLength);
        final comments = _parseVorbisCommentBlock(payload);
        if (comments != null) {
          sawVorbis = true;
          title ??= comments['title'];
          artist ??= comments['artist'];
          album ??= comments['album'];
          albumArtist ??=
              comments['albumartist'] ?? comments['album artist'];
          genre ??= comments['genre'];
          lyrics ??= comments['lyrics'] ?? comments['unsyncedlyrics'];
          year ??= _parseYear(comments['date'] ?? comments['year']);
          trackNumber = _parseLeadingInt(
            comments['tracknumber'] ?? comments['track'],
          );
          discNumber = _parseLeadingInt(
            comments['discnumber'] ?? comments['disc'],
          );
          isCompilation =
              isCompilation || _truthy(comments['compilation']);
        }
      } else {
        // Skip padding, seektable, picture, application, …
        reader.setPositionSync(payloadEnd);
      }
    }

    if (!sawVorbis &&
        title == null &&
        artist == null &&
        album == null) {
      return null;
    }
    return FlacTags(
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      genre: genre,
      lyrics: lyrics,
      year: year,
      trackNumber: trackNumber,
      discNumber: discNumber,
      isCompilation: isCompilation,
      duration: duration,
    );
  } catch (_) {
    return null;
  } finally {
    reader?.closeSync();
  }
}

Map<String, String>? _parseVorbisCommentBlock(Uint8List bytes) {
  if (bytes.length < 8) return null;
  try {
    var offset = 0;
    final vendorLength = _le32(bytes, offset);
    offset += 4;
    if (vendorLength < 0 || offset + vendorLength > bytes.length) return null;
    offset += vendorLength;
    if (offset + 4 > bytes.length) return null;
    final count = _le32(bytes, offset);
    offset += 4;
    if (count < 0 || count > 10000) return null;
    final out = <String, String>{};
    for (var i = 0; i < count; i++) {
      if (offset + 4 > bytes.length) break;
      final commentLength = _le32(bytes, offset);
      offset += 4;
      if (commentLength < 0 ||
          offset + commentLength > bytes.length) {
        break;
      }
      final raw = utf8.decode(
        bytes.sublist(offset, offset + commentLength),
        allowMalformed: true,
      );
      offset += commentLength;
      final separator = raw.indexOf('=');
      if (separator <= 0) continue;
      final key = raw.substring(0, separator).trim().toLowerCase();
      final value = raw.substring(separator + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      // First value wins for identity fields.
      out.putIfAbsent(key, () => value);
    }
    return out;
  } catch (_) {
    return null;
  }
}

int _le32(Uint8List bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

int? _parseYear(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final match = RegExp(r'(\d{4})').firstMatch(raw);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  if (year == null || year <= 0) return null;
  return year;
}

int _parseLeadingInt(String? raw) {
  if (raw == null || raw.isEmpty) return 0;
  final match = RegExp(r'^(\d+)').firstMatch(raw.trim());
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

bool _truthy(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes';
}
