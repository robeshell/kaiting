import 'package:flutter/material.dart';

import '../core/kaiting_icons.dart';

class SourceKind {
  const SourceKind(this.name);

  static const local = SourceKind('local');
  static const webDav = SourceKind('webDav');
  static const values = [local, webDav];

  factory SourceKind.fromName(String name) {
    return switch (name) {
      'local' => local,
      'webDav' => webDav,
      _ => SourceKind(name),
    };
  }

  final String name;

  @override
  bool operator ==(Object other) {
    return other is SourceKind && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

extension SourceKindLabel on SourceKind {
  String get label {
    if (this == SourceKind.local) return '本地';
    if (this == SourceKind.webDav) return 'WebDAV';
    return name;
  }

  IconData get icon =>
      this == SourceKind.local ? KaitingIcons.localSource : KaitingIcons.cloud;
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
  final String? artworkUri;
  final int? year;
  final String? genre;

  bool get isPlayable => mediaUri != null && mediaUri!.trim().isNotEmpty;

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? albumTitle,
    Duration? duration,
    SourceKind? source,
    int? trackNumber,
    int? discNumber,
    List<LyricLine>? lyrics,
    String? mediaUri,
    String? artworkUri,
    int? year,
    String? genre,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumTitle: albumTitle ?? this.albumTitle,
      duration: duration ?? this.duration,
      source: source ?? this.source,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      lyrics: lyrics ?? this.lyrics,
      mediaUri: mediaUri ?? this.mediaUri,
      artworkUri: artworkUri ?? this.artworkUri,
      year: year ?? this.year,
      genre: genre ?? this.genre,
    );
  }
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
    this.featuredTracks = const [],
  });

  final String id;
  final LibraryCollectionKind kind;
  final String title;
  final List<Album> albums;

  /// All tracks under this collection (primary + featured).
  final List<Track> tracks;

  /// Tracks where this artist only appears as a collab credit (not lead /
  /// album artist). Empty for genres. Subset of [tracks].
  final List<Track> featuredTracks;

  /// Tracks that are not collab-only appearances.
  List<Track> get primaryTracks {
    if (featuredTracks.isEmpty) return tracks;
    final featuredIds = {for (final track in featuredTracks) track.id};
    return [
      for (final track in tracks)
        if (!featuredIds.contains(track.id)) track,
    ];
  }

  /// Albums where this collection title appears in the album artist credit.
  ///
  /// For split multi-artist browsing these are "their" releases, as opposed to
  /// albums they only appear on as a featured track credit.
  List<Album> get ownedAlbums {
    if (kind != LibraryCollectionKind.artist || albums.isEmpty) {
      return albums;
    }
    final key = _collectionKey(title);
    final owned = [
      for (final album in albums)
        if (_albumCreditIncludes(album.artist, key)) album,
    ];
    return owned.isEmpty ? const [] : owned;
  }

  /// Whether the artist avatar should be a monogram (no reliable self-cover).
  ///
  /// Featured-only artists and artists whose own albums have no artwork fall
  /// back to a letter tile instead of a random collab cover.
  bool get prefersMonogramAvatar {
    if (kind != LibraryCollectionKind.artist) return false;
    final owned = ownedAlbums;
    if (owned.isEmpty) return true;
    return !owned.any(_albumHasArtworkHint);
  }

  /// Best album to use as a circular artist avatar cover.
  ///
  /// Prefers owned albums with artwork and more tracks. Null when a monogram
  /// should be shown instead.
  Album? get representativeAlbum {
    if (prefersMonogramAvatar) return null;
    final pool = ownedAlbums.isNotEmpty ? ownedAlbums : albums;
    if (pool.isEmpty) return null;
    final ranked = [...pool]
      ..sort((left, right) {
        final art = (_albumHasArtworkHint(right) ? 1 : 0).compareTo(
          _albumHasArtworkHint(left) ? 1 : 0,
        );
        if (art != 0) return art;
        final tracks = right.tracks.length.compareTo(left.tracks.length);
        if (tracks != 0) return tracks;
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
    return ranked.first;
  }

  /// Single character for monogram avatars (first rune, uppercased when Latin).
  String get monogram => artistMonogram(title);

  List<Color> get monogramPalette => artistMonogramPalette(title);

  List<Color> get palette {
    final album = representativeAlbum ?? (albums.isEmpty ? null : albums.first);
    if (album != null) return album.palette;
    if (kind == LibraryCollectionKind.artist) return monogramPalette;
    return const [Color(0xFF385057), Color(0xFF11191C)];
  }
}

bool _albumHasArtworkHint(Album album) {
  final uri = album.artworkUri?.trim();
  return uri != null && uri.isNotEmpty;
}

bool _albumCreditIncludes(String albumArtist, String artistKey) {
  final credit = albumArtist.trim();
  if (credit.isEmpty) return false;
  if (_collectionKey(credit) == artistKey) return true;
  return splitArtistCredit(
    credit,
  ).any((part) => _collectionKey(part) == artistKey);
}

/// First visible character for artist monogram tiles.
String artistMonogram(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed == '未知艺人') return '?';
  final iterator = trimmed.runes.iterator;
  if (!iterator.moveNext()) return '?';
  final char = String.fromCharCode(iterator.current);
  return char.toUpperCase();
}

/// Stable two-stop gradient from an artist name (no network, no artwork).
List<Color> artistMonogramPalette(String name) {
  final hash = name.trim().toLowerCase().hashCode;
  final hue = (hash % 360).abs().toDouble();
  final primary = HSLColor.fromAHSL(1, hue, 0.40, 0.40).toColor();
  final deep = HSLColor.fromAHSL(1, (hue + 26) % 360, 0.34, 0.24).toColor();
  return [primary, deep];
}

/// Splits a multi-artist credit into individual display names.
///
/// Used for artist browsing so "A feat. B" yields separate people. Track
/// rows still show the original credit string.
List<String> splitArtistCredit(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return const [];
  return cleaned
      .split(
        RegExp(
          // featuring/feat/ft before shorter tokens; optional "." is not
          // wrapped in \b or "feat." leaves a leading ". B" fragment.
          r'\s*(?:&|/|、|,|，|;|；|\bfeaturing\b|\bfeat\.?|\bft\.?|\bwith\b)\s*',
          caseSensitive: false,
        ),
      )
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

List<LibraryCollection> buildArtistCollections(List<Album> albums) {
  final groups = <String, _LibraryCollectionAccumulator>{};

  _LibraryCollectionAccumulator groupFor(String displayName) {
    final cleaned = _cleanCollectionName(displayName, fallback: '未知艺人');
    final key = _collectionKey(cleaned);
    return groups.putIfAbsent(
      key,
      () => _LibraryCollectionAccumulator(
        kind: LibraryCollectionKind.artist,
        title: cleaned,
      ),
    );
  }

  for (final album in albums) {
    final albumCredit = _cleanCollectionName(album.artist, fallback: '未知艺人');
    final albumParts = splitArtistCredit(albumCredit);
    final resolvedAlbumParts = albumParts.isEmpty
        ? <String>[albumCredit]
        : albumParts;
    final albumPartKeys = {
      for (final part in resolvedAlbumParts) _collectionKey(part),
    };

    // Album-level credits own the full album as primary work.
    for (final part in resolvedAlbumParts) {
      groupFor(part).add(album, album.tracks, featured: false);
    }

    for (final track in album.tracks) {
      final trackCredit = _cleanCollectionName(
        track.artist,
        fallback: albumCredit,
      );
      final trackParts = splitArtistCredit(trackCredit);
      final resolvedTrackParts = trackParts.isEmpty
          ? <String>[trackCredit]
          : trackParts;

      for (var index = 0; index < resolvedTrackParts.length; index++) {
        final part = resolvedTrackParts[index];
        final partKey = _collectionKey(part);
        // Already counted via album credit.
        if (albumPartKeys.contains(partKey)) continue;
        // Lead token stays in the main song list; later collab tokens go to
        // "参与" so the artist page stays scannable.
        final featured = index > 0;
        groupFor(part).add(album, [track], featured: featured);
      }
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
  final Set<String> _featuredTrackIds = {};

  void add(Album album, Iterable<Track> tracks, {bool featured = false}) {
    _albums[album.id] = album;
    for (final track in tracks) {
      if (featured) {
        // Do not demote a track that is already primary work.
        if (_tracks.containsKey(track.id) &&
            !_featuredTrackIds.contains(track.id)) {
          continue;
        }
        _tracks[track.id] = track;
        _featuredTrackIds.add(track.id);
      } else {
        _tracks[track.id] = track;
        _featuredTrackIds.remove(track.id);
      }
    }
  }

  LibraryCollection build() {
    final prefix = kind == LibraryCollectionKind.artist ? 'artist' : 'genre';
    final tracks = List<Track>.unmodifiable(_tracks.values);
    final featured = _featuredTrackIds.isEmpty
        ? const <Track>[]
        : List<Track>.unmodifiable([
            for (final track in tracks)
              if (_featuredTrackIds.contains(track.id)) track,
          ]);
    return LibraryCollection(
      id: '$prefix:${_collectionKey(title)}',
      kind: kind,
      title: title,
      albums: List.unmodifiable(_albums.values),
      tracks: tracks,
      featuredTracks: featured,
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

/// Resolves an artist name to a [LibraryCollection] from the current catalog.
///
/// Prefers an exact title match (case-insensitive), then a unique contains
/// match. Returns null when the name is empty or ambiguous/missing.
///
/// Pass [collections] when the caller already built artist collections for
/// [albums] so large libraries do not regroup the full catalog on every
/// metadata tap.
LibraryCollection? findArtistCollection(
  List<Album> albums,
  String artistName, {
  List<LibraryCollection>? collections,
}) {
  final cleaned = artistName.trim();
  if (cleaned.isEmpty || cleaned == '未知艺人') return null;
  final key = _collectionKey(cleaned);
  final resolved = collections ?? buildArtistCollections(albums);
  final exact = resolved
      .where((collection) => _collectionKey(collection.title) == key)
      .toList(growable: false);
  if (exact.length == 1) return exact.single;
  if (exact.length > 1) return exact.first;

  // Multi-credit strings no longer exist as collection titles after split;
  // open the lead (first) individual artist when possible.
  final parts = splitArtistCredit(cleaned);
  if (parts.length > 1) {
    for (final part in parts) {
      final partKey = _collectionKey(part);
      for (final collection in resolved) {
        if (_collectionKey(collection.title) == partKey) {
          return collection;
        }
      }
    }
  }

  final partial = resolved
      .where((collection) => _collectionKey(collection.title).contains(key))
      .toList(growable: false);
  if (partial.length == 1) return partial.single;
  return null;
}

/// Looks up a catalog album by stable id when present.
Album? findAlbumById(List<Album> albums, String albumId) {
  for (final album in albums) {
    if (album.id == albumId) return album;
  }
  return null;
}

/// Best-effort resolve of a track's album from the catalog (shared artwork and
/// full track list). Falls back to [albumForTrack] when the scan id is unknown.
Album resolveAlbumForTrack(List<Album> albums, Track track) {
  for (final album in albums) {
    if (album.tracks.any((candidate) => candidate.id == track.id)) {
      return album;
    }
  }
  final titleKey = _collectionKey(track.albumTitle);
  final artistKey = _collectionKey(track.artist);
  for (final album in albums) {
    if (_collectionKey(album.title) == titleKey &&
        (_collectionKey(album.artist) == artistKey ||
            album.tracks.any(
              (candidate) => _collectionKey(candidate.artist) == artistKey,
            ))) {
      return album;
    }
  }
  return albumForTrack(track);
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
