import 'package:drift/drift.dart';

import '../library_records.dart';
import '../library_repository.dart';
import 'library_database.dart' as db;

class DriftLibraryRepository implements LibraryRepository {
  DriftLibraryRepository(this._database);

  factory DriftLibraryRepository.defaults() =>
      DriftLibraryRepository(db.LibraryDatabase.defaults());

  final db.LibraryDatabase _database;

  @override
  Stream<List<LibrarySourceRecord>> watchSources() {
    final query = _database.select(_database.librarySources)
      ..orderBy([(row) => OrderingTerm.asc(row.displayName)]);
    return query.watch().map(
      (rows) => rows.map(_sourceRecord).toList(growable: false),
    );
  }

  @override
  Stream<List<LibraryAlbumRecord>> watchAlbums() {
    final query = _database.select(_database.libraryAlbums)
      ..orderBy([(row) => OrderingTerm.asc(row.sortTitle)]);
    return query.watch().map(
      (rows) => rows.map(_albumRecord).toList(growable: false),
    );
  }

  @override
  Stream<List<LibraryArtistRecord>> watchArtists() {
    final query = _database.select(_database.libraryArtists)
      ..orderBy([(row) => OrderingTerm.asc(row.sortName)]);
    return query.watch().map(
      (rows) => rows.map(_artistRecord).toList(growable: false),
    );
  }

  @override
  Stream<List<LibraryTrackRecord>> watchTracks() {
    final query = _database.select(_database.libraryTracks)
      ..orderBy([
        (row) => OrderingTerm.asc(row.albumTitle),
        (row) => OrderingTerm.asc(row.discNumber),
        (row) => OrderingTerm.asc(row.trackNumber),
        (row) => OrderingTerm.asc(row.title),
      ]);
    return query.watch().map(
      (rows) => rows.map(_trackRecord).toList(growable: false),
    );
  }

  @override
  Future<List<LibrarySourceRecord>> getSources() async {
    final query = _database.select(_database.librarySources)
      ..orderBy([(row) => OrderingTerm.asc(row.displayName)]);
    final rows = await query.get();
    return rows.map(_sourceRecord).toList(growable: false);
  }

  @override
  Future<LibrarySourceRecord?> getSource(String id) async {
    final query = _database.select(_database.librarySources)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _sourceRecord(row);
  }

  @override
  Future<List<LibraryAlbumRecord>> getAlbums({String? sourceId}) async {
    final query = _database.select(_database.libraryAlbums);
    if (sourceId != null) {
      query.where((row) => row.sourceId.equals(sourceId));
    }
    query.orderBy([(row) => OrderingTerm.asc(row.sortTitle)]);
    final rows = await query.get();
    return rows.map(_albumRecord).toList(growable: false);
  }

  @override
  Future<List<LibraryArtistRecord>> getArtists({String? sourceId}) async {
    final query = _database.select(_database.libraryArtists);
    if (sourceId != null) {
      query.where((row) => row.sourceId.equals(sourceId));
    }
    query.orderBy([(row) => OrderingTerm.asc(row.sortName)]);
    final rows = await query.get();
    return rows.map(_artistRecord).toList(growable: false);
  }

  @override
  Future<List<LibraryTrackRecord>> getTracks({String? sourceId}) async {
    final query = _database.select(_database.libraryTracks);
    if (sourceId != null) {
      query.where((row) => row.sourceId.equals(sourceId));
    }
    query.orderBy([
      (row) => OrderingTerm.asc(row.albumTitle),
      (row) => OrderingTerm.asc(row.discNumber),
      (row) => OrderingTerm.asc(row.trackNumber),
      (row) => OrderingTerm.asc(row.title),
    ]);
    final rows = await query.get();
    return rows.map(_trackRecord).toList(growable: false);
  }

  @override
  Future<List<LibraryLyricRecord>> getLyrics(String trackId) async {
    final query = _database.select(_database.libraryLyrics)
      ..where((row) => row.trackId.equals(trackId))
      ..orderBy([(row) => OrderingTerm.asc(row.sequence)]);
    final rows = await query.get();
    return rows.map(_lyricRecord).toList(growable: false);
  }

  @override
  Future<void> upsertSource(LibrarySourceRecord source) async {
    await _database
        .into(_database.librarySources)
        .insertOnConflictUpdate(_sourceCompanion(source));
  }

  @override
  Future<void> deleteSource(String id) async {
    await (_database.delete(
      _database.librarySources,
    )..where((row) => row.id.equals(id))).go();
  }

  @override
  Future<void> markSourceScanning(
    String id, {
    required DateTime startedAt,
  }) async {
    final changed =
        await (_database.update(
          _database.librarySources,
        )..where((row) => row.id.equals(id))).write(
          db.LibrarySourcesCompanion(
            status: Value(LibrarySourceStatus.scanning.name),
            lastScanStartedAt: Value(startedAt.toUtc()),
            lastError: const Value(null),
            updatedAt: Value(startedAt.toUtc()),
          ),
        );
    if (changed == 0) throw StateError('Unknown library source: $id');
  }

  @override
  Future<void> markSourceFailure(
    String id, {
    required LibrarySourceStatus status,
    required String message,
    required DateTime occurredAt,
  }) async {
    if (status != LibrarySourceStatus.error &&
        status != LibrarySourceStatus.permissionRequired &&
        status != LibrarySourceStatus.unavailable) {
      throw ArgumentError.value(status, 'status', 'Not a failure status.');
    }
    final changed =
        await (_database.update(
          _database.librarySources,
        )..where((row) => row.id.equals(id))).write(
          db.LibrarySourcesCompanion(
            status: Value(status.name),
            lastError: Value(message.trim()),
            updatedAt: Value(occurredAt.toUtc()),
          ),
        );
    if (changed == 0) throw StateError('Unknown library source: $id');
  }

  @override
  Future<void> replaceSourceScan(LibraryScanBatch batch) async {
    _validateBatch(batch);
    await _database.transaction(() async {
      final sourceQuery = _database.select(_database.librarySources)
        ..where((row) => row.id.equals(batch.sourceId));
      final source = await sourceQuery.getSingleOrNull();
      if (source == null) {
        throw StateError('Unknown library source: ${batch.sourceId}');
      }

      // Remove identities that are no longer part of the scan before
      // inserting replacements. Scanner upgrades may assign a new primary key
      // to the same semantic artist or album, whose alternate unique key is
      // still occupied by the legacy row. The transaction keeps this atomic.
      await _deleteMissingTracks(batch.sourceId, batch.tracks);
      await _deleteMissingAlbums(batch.sourceId, batch.albums);
      await _deleteMissingArtists(batch.sourceId, batch.artists);

      for (final artist in batch.artists) {
        await _database
            .into(_database.libraryArtists)
            .insertOnConflictUpdate(_artistCompanion(artist));
      }
      for (final album in batch.albums) {
        await _database
            .into(_database.libraryAlbums)
            .insertOnConflictUpdate(_albumCompanion(album));
      }
      for (final track in batch.tracks) {
        await _database
            .into(_database.libraryTracks)
            .insertOnConflictUpdate(_trackCompanion(track));
      }

      await _database.customStatement(
        'DELETE FROM library_lyrics '
        'WHERE track_id IN ('
        'SELECT id FROM library_tracks WHERE source_id = ?'
        ')',
        [batch.sourceId],
      );
      for (final lyric in batch.lyrics) {
        await _database
            .into(_database.libraryLyrics)
            .insert(_lyricCompanion(lyric));
      }

      await (_database.update(
        _database.librarySources,
      )..where((row) => row.id.equals(batch.sourceId))).write(
        db.LibrarySourcesCompanion(
          status: Value(LibrarySourceStatus.available.name),
          scanRevision: Value(source.scanRevision + 1),
          lastScanCompletedAt: Value(batch.completedAt.toUtc()),
          lastError: const Value(null),
          updatedAt: Value(batch.completedAt.toUtc()),
        ),
      );
    });
  }

  Future<void> _deleteMissingTracks(
    String sourceId,
    List<LibraryTrackRecord> records,
  ) async {
    final ids = records.map((record) => record.id).toList(growable: false);
    final deletion = _database.delete(_database.libraryTracks)
      ..where((row) => row.sourceId.equals(sourceId));
    if (ids.isNotEmpty) deletion.where((row) => row.id.isNotIn(ids));
    await deletion.go();
  }

  Future<void> _deleteMissingAlbums(
    String sourceId,
    List<LibraryAlbumRecord> records,
  ) async {
    final ids = records.map((record) => record.id).toList(growable: false);
    final deletion = _database.delete(_database.libraryAlbums)
      ..where((row) => row.sourceId.equals(sourceId));
    if (ids.isNotEmpty) deletion.where((row) => row.id.isNotIn(ids));
    await deletion.go();
  }

  Future<void> _deleteMissingArtists(
    String sourceId,
    List<LibraryArtistRecord> records,
  ) async {
    final ids = records.map((record) => record.id).toList(growable: false);
    final deletion = _database.delete(_database.libraryArtists)
      ..where((row) => row.sourceId.equals(sourceId));
    if (ids.isNotEmpty) deletion.where((row) => row.id.isNotIn(ids));
    await deletion.go();
  }

  void _validateBatch(LibraryScanBatch batch) {
    final artistIds = batch.artists.map((record) => record.id).toSet();
    final albumIds = batch.albums.map((record) => record.id).toSet();
    final trackIds = batch.tracks.map((record) => record.id).toSet();

    for (final artist in batch.artists) {
      _expectSource(batch.sourceId, artist.sourceId, 'artist ${artist.id}');
    }
    for (final album in batch.albums) {
      _expectSource(batch.sourceId, album.sourceId, 'album ${album.id}');
      final artistId = album.artistId;
      if (artistId != null && !artistIds.contains(artistId)) {
        throw ArgumentError('Album ${album.id} references missing artist.');
      }
    }
    for (final track in batch.tracks) {
      _expectSource(batch.sourceId, track.sourceId, 'track ${track.id}');
      final artistId = track.artistId;
      final albumId = track.albumId;
      if (artistId != null && !artistIds.contains(artistId)) {
        throw ArgumentError('Track ${track.id} references missing artist.');
      }
      if (albumId != null && !albumIds.contains(albumId)) {
        throw ArgumentError('Track ${track.id} references missing album.');
      }
    }
    for (final lyric in batch.lyrics) {
      if (!trackIds.contains(lyric.trackId)) {
        throw ArgumentError(
          'Lyric ${lyric.trackId}/${lyric.sequence} references missing track.',
        );
      }
    }
  }

  void _expectSource(String expected, String actual, String label) {
    if (actual != expected) {
      throw ArgumentError('$label belongs to $actual instead of $expected.');
    }
  }

  @override
  Future<void> close() => _database.close();
}

LibrarySourceRecord _sourceRecord(db.LibrarySource row) {
  return LibrarySourceRecord(
    id: row.id,
    type: LibrarySourceType.values.byName(row.type),
    displayName: row.displayName,
    rootUri: row.rootUri,
    permissionBookmark: row.permissionBookmark,
    status: LibrarySourceStatus.values.byName(row.status),
    scanRevision: row.scanRevision,
    lastScanStartedAt: row.lastScanStartedAt?.toUtc(),
    lastScanCompletedAt: row.lastScanCompletedAt?.toUtc(),
    lastError: row.lastError,
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
  );
}

LibraryAlbumRecord _albumRecord(db.LibraryAlbum row) {
  return LibraryAlbumRecord(
    id: row.id,
    sourceId: row.sourceId,
    title: row.title,
    sortTitle: row.sortTitle,
    albumArtist: row.albumArtist,
    artistId: row.artistId,
    year: row.year,
    genre: row.genre,
    artworkKey: row.artworkKey,
  );
}

LibraryArtistRecord _artistRecord(db.LibraryArtist row) {
  return LibraryArtistRecord(
    id: row.id,
    sourceId: row.sourceId,
    name: row.name,
    sortName: row.sortName,
  );
}

LibraryTrackRecord _trackRecord(db.LibraryTrack row) {
  return LibraryTrackRecord(
    id: row.id,
    sourceId: row.sourceId,
    albumId: row.albumId,
    artistId: row.artistId,
    relativePath: row.relativePath,
    mediaUri: row.mediaUri,
    title: row.title,
    artistName: row.artistName,
    albumTitle: row.albumTitle,
    durationMs: row.durationMs,
    trackNumber: row.trackNumber,
    discNumber: row.discNumber,
    year: row.year,
    genre: row.genre,
    contentType: row.contentType,
    fileSize: row.fileSize,
    modifiedAt: row.modifiedAt.toUtc(),
    artworkKey: row.artworkKey,
  );
}

LibraryLyricRecord _lyricRecord(db.LibraryLyric row) {
  return LibraryLyricRecord(
    trackId: row.trackId,
    sequence: row.sequence,
    timestampMs: row.timestampMs,
    text: row.content,
  );
}

db.LibrarySourcesCompanion _sourceCompanion(LibrarySourceRecord source) {
  return db.LibrarySourcesCompanion.insert(
    id: source.id,
    type: source.type.name,
    displayName: source.displayName,
    rootUri: source.rootUri,
    permissionBookmark: Value(source.permissionBookmark),
    status: source.status.name,
    scanRevision: Value(source.scanRevision),
    lastScanStartedAt: Value(source.lastScanStartedAt?.toUtc()),
    lastScanCompletedAt: Value(source.lastScanCompletedAt?.toUtc()),
    lastError: Value(source.lastError),
    createdAt: source.createdAt.toUtc(),
    updatedAt: source.updatedAt.toUtc(),
  );
}

db.LibraryArtistsCompanion _artistCompanion(LibraryArtistRecord artist) {
  return db.LibraryArtistsCompanion.insert(
    id: artist.id,
    sourceId: artist.sourceId,
    name: artist.name,
    sortName: artist.sortName,
  );
}

db.LibraryAlbumsCompanion _albumCompanion(LibraryAlbumRecord album) {
  return db.LibraryAlbumsCompanion.insert(
    id: album.id,
    sourceId: album.sourceId,
    artistId: Value(album.artistId),
    title: album.title,
    sortTitle: album.sortTitle,
    albumArtist: album.albumArtist,
    year: Value(album.year),
    genre: Value(album.genre),
    artworkKey: Value(album.artworkKey),
  );
}

db.LibraryTracksCompanion _trackCompanion(LibraryTrackRecord track) {
  return db.LibraryTracksCompanion.insert(
    id: track.id,
    sourceId: track.sourceId,
    albumId: Value(track.albumId),
    artistId: Value(track.artistId),
    relativePath: track.relativePath,
    mediaUri: track.mediaUri,
    title: track.title,
    artistName: track.artistName,
    albumTitle: track.albumTitle,
    durationMs: track.durationMs,
    trackNumber: Value(track.trackNumber),
    discNumber: Value(track.discNumber),
    year: Value(track.year),
    genre: Value(track.genre),
    contentType: Value(track.contentType),
    fileSize: Value(track.fileSize),
    modifiedAt: track.modifiedAt.toUtc(),
    artworkKey: Value(track.artworkKey),
  );
}

db.LibraryLyricsCompanion _lyricCompanion(LibraryLyricRecord lyric) {
  return db.LibraryLyricsCompanion.insert(
    trackId: lyric.trackId,
    sequence: lyric.sequence,
    timestampMs: lyric.timestampMs,
    content: lyric.text,
  );
}
