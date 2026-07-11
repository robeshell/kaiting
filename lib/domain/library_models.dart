import 'package:flutter/material.dart';

enum SourceKind { local, webDav }

extension SourceKindLabel on SourceKind {
  String get label => switch (this) {
    SourceKind.local => '本地',
    SourceKind.webDav => 'WebDAV',
  };

  IconData get icon => switch (this) {
    SourceKind.local => Icons.laptop_mac_rounded,
    SourceKind.webDav => Icons.cloud_outlined,
  };
}

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumTitle,
    required this.duration,
    required this.source,
    this.trackNumber = 1,
    this.lyrics = const [],
    this.mediaUri,
    this.httpHeaders = const {},
    this.artworkUri,
    this.year,
    this.genre,
  });

  final String id;
  final String title;
  final String artist;
  final String albumTitle;
  final Duration duration;
  final SourceKind source;
  final int trackNumber;
  final List<LyricLine> lyrics;
  final String? mediaUri;
  final Map<String, String> httpHeaders;
  final String? artworkUri;
  final int? year;
  final String? genre;

  bool get isPlayable => mediaUri != null && mediaUri!.trim().isNotEmpty;
}

class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.source,
    required this.palette,
    required this.tracks,
    this.year,
    this.genre,
    this.artworkUri,
  });

  final String id;
  final String title;
  final String artist;
  final int? year;
  final String? genre;
  final SourceKind source;
  final List<Color> palette;
  final List<Track> tracks;
  final String? artworkUri;
}

Album albumForTrack(Track track) {
  return Album(
    id: 'playing:${track.id}',
    title: track.albumTitle,
    artist: track.artist,
    year: track.year,
    genre: track.genre,
    source: track.source,
    palette: albumPaletteForId(track.albumTitle),
    tracks: [track],
    artworkUri: track.artworkUri,
  );
}

List<Color> albumPaletteForId(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = 0x1fffffff & (hash * 31 + unit);
  }
  final hue = (hash % 360).toDouble();
  return [
    HSLColor.fromAHSL(1, hue, 0.42, 0.38).toColor(),
    HSLColor.fromAHSL(1, hue, 0.24, 0.12).toColor(),
  ];
}
