import 'dart:typed_data';

enum LibrarySourceType { local, webDav }

enum LibrarySourceStatus {
  idle,
  scanning,
  available,
  permissionRequired,
  unavailable,
  error,
}

class LibrarySourceRecord {
  const LibrarySourceRecord({
    required this.id,
    required this.type,
    required this.displayName,
    required this.rootUri,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.permissionBookmark,
    this.scanRevision = 0,
    this.lastScanStartedAt,
    this.lastScanCompletedAt,
    this.lastError,
  });

  final String id;
  final LibrarySourceType type;
  final String displayName;
  final String rootUri;
  final Uint8List? permissionBookmark;
  final LibrarySourceStatus status;
  final int scanRevision;
  final DateTime? lastScanStartedAt;
  final DateTime? lastScanCompletedAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class LibraryArtistRecord {
  const LibraryArtistRecord({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.sortName,
  });

  final String id;
  final String sourceId;
  final String name;
  final String sortName;
}

class LibraryAlbumRecord {
  const LibraryAlbumRecord({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.sortTitle,
    required this.albumArtist,
    this.artistId,
    this.year,
    this.genre,
    this.artworkKey,
  });

  final String id;
  final String sourceId;
  final String title;
  final String sortTitle;
  final String albumArtist;
  final String? artistId;
  final int? year;
  final String? genre;
  final String? artworkKey;
}

class LibraryTrackRecord {
  const LibraryTrackRecord({
    required this.id,
    required this.sourceId,
    required this.relativePath,
    required this.mediaUri,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.durationMs,
    required this.modifiedAt,
    this.albumId,
    this.artistId,
    this.trackNumber = 0,
    this.discNumber = 0,
    this.year,
    this.genre,
    this.contentType,
    this.fileSize,
    this.artworkKey,
  });

  final String id;
  final String sourceId;
  final String? albumId;
  final String? artistId;
  final String relativePath;
  final String mediaUri;
  final String title;
  final String artistName;
  final String albumTitle;
  final int durationMs;
  final int trackNumber;
  final int discNumber;
  final int? year;
  final String? genre;
  final String? contentType;
  final int? fileSize;
  final DateTime modifiedAt;
  final String? artworkKey;
}

class LibraryLyricRecord {
  const LibraryLyricRecord({
    required this.trackId,
    required this.sequence,
    required this.timestampMs,
    required this.text,
  });

  final String trackId;
  final int sequence;
  final int timestampMs;
  final String text;
}

class LibraryFavoriteTrackRecord {
  const LibraryFavoriteTrackRecord({
    required this.trackId,
    required this.addedAt,
  });

  final String trackId;
  final DateTime addedAt;
}

class LibraryPlayHistoryRecord {
  const LibraryPlayHistoryRecord({
    required this.id,
    required this.trackId,
    required this.playedAt,
  });

  final int id;
  final String trackId;
  final DateTime playedAt;
}

class LibraryScanBatch {
  const LibraryScanBatch({
    required this.sourceId,
    required this.completedAt,
    this.artists = const [],
    this.albums = const [],
    this.tracks = const [],
    this.lyrics = const [],
  });

  final String sourceId;
  final DateTime completedAt;
  final List<LibraryArtistRecord> artists;
  final List<LibraryAlbumRecord> albums;
  final List<LibraryTrackRecord> tracks;
  final List<LibraryLyricRecord> lyrics;
}
