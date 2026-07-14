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
    this.discNumber = 0,
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
  final int discNumber;
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

  /// Null for plain, unsynchronized lyrics.
  final Duration? time;
  final String text;

  bool get isSynchronized => time != null;
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

enum LibraryCollectionKind { artist, genre }

class LibraryCollection {
  const LibraryCollection({
    required this.id,
    required this.kind,
    required this.title,
    required this.albums,
    required this.tracks,
  });

  final String id;
  final LibraryCollectionKind kind;
  final String title;
  final List<Album> albums;
  final List<Track> tracks;

  List<Color> get palette => albums.isEmpty
      ? const [Color(0xFF385057), Color(0xFF11191C)]
      : albums.first.palette;
}

List<LibraryCollection> buildArtistCollections(List<Album> albums) {
  final groups = <String, _LibraryCollectionAccumulator>{};
  for (final album in albums) {
    final albumArtist = _cleanCollectionName(album.artist, fallback: '未知艺人');
    final albumArtistKey = _collectionKey(albumArtist);
    final albumGroup = groups.putIfAbsent(
      albumArtistKey,
      () => _LibraryCollectionAccumulator(
        kind: LibraryCollectionKind.artist,
        title: albumArtist,
      ),
    );
    albumGroup.add(album, album.tracks);

    for (final track in album.tracks) {
      final trackArtist = _cleanCollectionName(
        track.artist,
        fallback: albumArtist,
      );
      final trackArtistKey = _collectionKey(trackArtist);
      if (trackArtistKey == albumArtistKey) continue;
      groups
          .putIfAbsent(
            trackArtistKey,
            () => _LibraryCollectionAccumulator(
              kind: LibraryCollectionKind.artist,
              title: trackArtist,
            ),
          )
          .add(album, [track]);
    }
  }
  return _sortedCollections(groups.values);
}

List<LibraryCollection> buildGenreCollections(List<Album> albums) {
  final groups = <String, _LibraryCollectionAccumulator>{};
  for (final album in albums) {
    for (final track in album.tracks) {
      final genre = _cleanCollectionName(
        track.genre ?? album.genre ?? '',
        fallback: '未分类',
      );
      final key = _collectionKey(genre);
      groups
          .putIfAbsent(
            key,
            () => _LibraryCollectionAccumulator(
              kind: LibraryCollectionKind.genre,
              title: genre,
            ),
          )
          .add(album, [track]);
    }
  }
  return _sortedCollections(groups.values);
}

class _LibraryCollectionAccumulator {
  _LibraryCollectionAccumulator({required this.kind, required this.title});

  final LibraryCollectionKind kind;
  final String title;
  final Map<String, Album> _albums = {};
  final Map<String, Track> _tracks = {};

  void add(Album album, Iterable<Track> tracks) {
    _albums[album.id] = album;
    for (final track in tracks) {
      _tracks[track.id] = track;
    }
  }

  LibraryCollection build() {
    final prefix = kind == LibraryCollectionKind.artist ? 'artist' : 'genre';
    return LibraryCollection(
      id: '$prefix:${_collectionKey(title)}',
      kind: kind,
      title: title,
      albums: List.unmodifiable(_albums.values),
      tracks: List.unmodifiable(_tracks.values),
    );
  }
}

List<LibraryCollection> _sortedCollections(
  Iterable<_LibraryCollectionAccumulator> groups,
) {
  final collections = groups.map((group) => group.build()).toList();
  collections.sort(
    (left, right) =>
        left.title.toLowerCase().compareTo(right.title.toLowerCase()),
  );
  return List.unmodifiable(collections);
}

String _cleanCollectionName(String value, {required String fallback}) {
  final cleaned = value.trim();
  return cleaned.isEmpty ? fallback : cleaned;
}

String _collectionKey(String value) => value.trim().toLowerCase();

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
