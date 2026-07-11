import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

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
  final metadata = readMetadata(File(path), getImage: true);
  final picture = metadata.pictures
      .where((picture) => picture.pictureType == PictureType.coverFront)
      .firstOrNull;
  final fallbackPicture = metadata.pictures.firstOrNull;
  final selectedPicture = picture ?? fallbackPicture;
  final year = metadata.year?.year;
  return ExtractedAudioMetadata(
    title: metadata.title,
    artist: metadata.artist,
    album: metadata.album,
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
