import 'package:drift/drift.dart';

import '../library_records.dart';
import '../library_repository.dart';
import 'library_database.dart' as db;

class DriftLibraryRepository implements LibraryRepository {
  DriftLibraryRepository(this._database);

  static const _maximumHistoryEntries = 1000;

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
  Stream<List<LibraryFavoriteTrackRecord>> watchFavoriteTracks() {
    final query = _database.select(_database.libraryFavoriteTracks)
      ..orderBy([(row) => OrderingTerm.desc(row.addedAt)]);
    return query.watch().map(
      (rows) => rows.map(_favoriteRecord).toList(growable: false),
    );
  }

  @override
  Stream<List<LibraryPlayHistoryRecord>> watchPlayHistory({int limit = 500}) {
    if (limit <= 0) {
      return Stream.value(const <LibraryPlayHistoryRecord>[]);
    }
    final query = _database.select(_database.libraryPlayHistory)
      ..orderBy([(row) => OrderingTerm.desc(row.playedAt)])
      ..limit(limit);
    return query.watch().map(
      (rows) => rows.map(_historyRecord).toList(growable: false),
    );
  }

  @override
  Stream<List<LibraryPlaylistRecord>> watchPlaylists() {
    final query = _database.select(_database.libraryPlaylists)
      ..orderBy([
        (row) => OrderingTerm.desc(row.updatedAt),
        (row) => OrderingTerm.asc(row.name),
      ]);
    return query.watch().map(
      (rows) => rows.map(_playlistRecord).toList(growable: false),
    );
  }

  @override
  Stream<List<LibraryPlaylistTrackRecord>> watchPlaylistTracks() {
    final query = _database.select(_database.libraryPlaylistTracks)
      ..orderBy([
        (row) => OrderingTerm.asc(row.playlistId),
        (row) => OrderingTerm.asc(row.position),
      ]);
    return query.watch().map(
      (rows) => rows.map(_playlistTrackRecord).toList(growable: false),
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
  Future<Map<String, List<LibraryLyricRecord>>> getAllLyrics() async {
    final query = _database.select(_database.libraryLyrics)
      ..orderBy([
        (row) => OrderingTerm.asc(row.trackId),
        (row) => OrderingTerm.asc(row.sequence),
      ]);
    final rows = await query.get();
    return _groupLyricRows(rows);
  }

  @override
  Future<Map<String, List<LibraryLyricRecord>>> getLyricsForTrackIds(
    Iterable<String> trackIds,
  ) async {
    final ids = trackIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};
    if (ids.length == 1) {
      final records = await getLyrics(ids.single);
      return records.isEmpty ? const {} : {ids.single: records};
    }
    final query = _database.select(_database.libraryLyrics)
      ..where((row) => row.trackId.isIn(ids))
      ..orderBy([
        (row) => OrderingTerm.asc(row.trackId),
        (row) => OrderingTerm.asc(row.sequence),
      ]);
    final rows = await query.get();
    return _groupLyricRows(rows);
  }

  Map<String, List<LibraryLyricRecord>> _groupLyricRows(
    List<db.LibraryLyric> rows,
  ) {
    final grouped = <String, List<LibraryLyricRecord>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.trackId, () => []).add(_lyricRecord(row));
    }
    return {
      for (final entry in grouped.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  @override
  Future<List<LibraryFavoriteTrackRecord>> getFavoriteTracks() async {
    final query = _database.select(_database.libraryFavoriteTracks)
      ..orderBy([(row) => OrderingTerm.desc(row.addedAt)]);
    final rows = await query.get();
    return rows.map(_favoriteRecord).toList(growable: false);
  }

  @override
  Future<List<LibraryPlayHistoryRecord>> getPlayHistory({
    int limit = 500,
  }) async {
    if (limit <= 0) return const [];
    final query = _database.select(_database.libraryPlayHistory)
      ..orderBy([(row) => OrderingTerm.desc(row.playedAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_historyRecord).toList(growable: false);
  }

  @override
  Future<List<LibraryPlaylistRecord>> getPlaylists() async {
    final query = _database.select(_database.libraryPlaylists)
      ..orderBy([
        (row) => OrderingTerm.desc(row.updatedAt),
        (row) => OrderingTerm.asc(row.name),
      ]);
    final rows = await query.get();
    return rows.map(_playlistRecord).toList(growable: false);
  }

  @override
  Future<List<LibraryPlaylistTrackRecord>> getPlaylistTracks({
    int? playlistId,
  }) async {
    final query = _database.select(_database.libraryPlaylistTracks);
    if (playlistId != null) {
      query.where((row) => row.playlistId.equals(playlistId));
    }
    query.orderBy([
      (row) => OrderingTerm.asc(row.playlistId),
      (row) => OrderingTerm.asc(row.position),
    ]);
    final rows = await query.get();
    return rows.map(_playlistTrackRecord).toList(growable: false);
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

      // A scan batch remains a complete source snapshot, but applying it is
      // differential. Unchanged rows are left untouched, which avoids a full
      // delete/reinsert cycle on every rescan and keeps moved tracks connected
      // to user state when the scanner deliberately preserves their IDs.
      await _applySourceScanDelta(batch);

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

  Future<void> _applySourceScanDelta(LibraryScanBatch batch) async {
    final existingArtists = await (_database.select(
      _database.libraryArtists,
    )..where((row) => row.sourceId.equals(batch.sourceId))).get();
    final existingAlbums = await (_database.select(
      _database.libraryAlbums,
    )..where((row) => row.sourceId.equals(batch.sourceId))).get();
    final existingTracks = await (_database.select(
      _database.libraryTracks,
    )..where((row) => row.sourceId.equals(batch.sourceId))).get();
    final existingLyricRows =
        await (_database.select(_database.libraryLyrics).join([
          innerJoin(
            _database.libraryTracks,
            _database.libraryTracks.id.equalsExp(
                  _database.libraryLyrics.trackId,
                ) &
                _database.libraryTracks.sourceId.equals(batch.sourceId),
          ),
        ])).get();

    final oldArtists = {for (final row in existingArtists) row.id: row};
    final oldAlbums = {for (final row in existingAlbums) row.id: row};
    final oldTracks = {for (final row in existingTracks) row.id: row};
    final newArtists = {for (final record in batch.artists) record.id: record};
    final newAlbums = {for (final record in batch.albums) record.id: record};
    final newTracks = {for (final record in batch.tracks) record.id: record};

    final removedTrackIds = oldTracks.keys
        .where((id) => !newTracks.containsKey(id))
        .toList(growable: false);
    final removedAlbumIds = oldAlbums.keys
        .where((id) => !newAlbums.containsKey(id))
        .toList(growable: false);
    final removedArtistIds = oldArtists.keys
        .where((id) => !newArtists.containsKey(id))
        .toList(growable: false);

    await _deleteIdsInChunks(
      removedTrackIds,
      (ids) => (_database.delete(
        _database.libraryTracks,
      )..where((row) => row.id.isIn(ids))).go(),
    );
    await _deleteIdsInChunks(
      removedAlbumIds,
      (ids) => (_database.delete(
        _database.libraryAlbums,
      )..where((row) => row.id.isIn(ids))).go(),
    );
    await _deleteIdsInChunks(
      removedArtistIds,
      (ids) => (_database.delete(
        _database.libraryArtists,
      )..where((row) => row.id.isIn(ids))).go(),
    );

    final changedArtists = batch.artists
        .where((record) {
          final old = oldArtists[record.id];
          return old == null || !_sameArtist(old, record);
        })
        .toList(growable: false);
    final changedAlbums = batch.albums
        .where((record) {
          final old = oldAlbums[record.id];
          return old == null || !_sameAlbum(old, record);
        })
        .toList(growable: false);
    final changedTracks = batch.tracks
        .where((record) {
          final old = oldTracks[record.id];
          return old == null || !_sameTrack(old, record);
        })
        .toList(growable: false);

    await _database.batch((writer) {
      writer.insertAllOnConflictUpdate(
        _database.libraryArtists,
        changedArtists.map(_artistCompanion),
      );
      writer.insertAllOnConflictUpdate(
        _database.libraryAlbums,
        changedAlbums.map(_albumCompanion),
      );
      writer.insertAllOnConflictUpdate(
        _database.libraryTracks,
        changedTracks.map(_trackCompanion),
      );
    });

    final oldLyrics = <String, List<db.LibraryLyric>>{};
    for (final joined in existingLyricRows) {
      final row = joined.readTable(_database.libraryLyrics);
      oldLyrics.putIfAbsent(row.trackId, () => []).add(row);
    }
    final newLyrics = <String, List<LibraryLyricRecord>>{};
    for (final lyric in batch.lyrics) {
      newLyrics.putIfAbsent(lyric.trackId, () => []).add(lyric);
    }
    final changedLyricTrackIds = <String>{};
    for (final trackId in newTracks.keys) {
      if (!_sameLyrics(
        oldLyrics[trackId] ?? const [],
        newLyrics[trackId] ?? const [],
      )) {
        changedLyricTrackIds.add(trackId);
      }
    }
    await _deleteIdsInChunks(
      changedLyricTrackIds.toList(growable: false),
      (ids) => (_database.delete(
        _database.libraryLyrics,
      )..where((row) => row.trackId.isIn(ids))).go(),
    );
    final changedLyrics = batch.lyrics
        .where((lyric) => changedLyricTrackIds.contains(lyric.trackId))
        .toList(growable: false);
    if (changedLyrics.isNotEmpty) {
      await _database.batch(
        (writer) => writer.insertAll(
          _database.libraryLyrics,
          changedLyrics.map(_lyricCompanion),
        ),
      );
    }
  }

  Future<void> _deleteIdsInChunks(
    List<String> ids,
    Future<int> Function(List<String> chunk) delete,
  ) async {
    const chunkSize = 400;
    for (var start = 0; start < ids.length; start += chunkSize) {
      final end = start + chunkSize < ids.length
          ? start + chunkSize
          : ids.length;
      await delete(ids.sublist(start, end));
    }
  }

  @override
  Future<void> setTrackFavorite(
    String trackId, {
    required bool favorite,
    required DateTime changedAt,
  }) async {
    if (favorite) {
      await _database
          .into(_database.libraryFavoriteTracks)
          .insertOnConflictUpdate(
            db.LibraryFavoriteTracksCompanion.insert(
              trackId: trackId,
              addedAt: changedAt.toUtc(),
            ),
          );
      return;
    }
    await (_database.delete(
      _database.libraryFavoriteTracks,
    )..where((row) => row.trackId.equals(trackId))).go();
  }

  @override
  Future<void> addPlayHistory(
    String trackId, {
    required DateTime playedAt,
  }) async {
    await _database.transaction(() async {
      await _database
          .into(_database.libraryPlayHistory)
          .insert(
            db.LibraryPlayHistoryCompanion.insert(
              trackId: trackId,
              playedAt: playedAt.toUtc(),
            ),
          );
      final newest =
          await (_database.select(_database.libraryPlayHistory)
                ..orderBy([(row) => OrderingTerm.desc(row.id)])
                ..limit(_maximumHistoryEntries + 1))
              .get();
      if (newest.length <= _maximumHistoryEntries) return;
      final oldestRetainedBoundary = newest.last.id;
      await (_database.delete(_database.libraryPlayHistory)..where(
            (row) => row.id.isSmallerOrEqualValue(oldestRetainedBoundary),
          ))
          .go();
    });
  }

  @override
  Future<void> clearPlayHistory() =>
      _database.delete(_database.libraryPlayHistory).go();

  @override
  Future<int> createPlaylist({
    required String name,
    required DateTime createdAt,
  }) {
    final normalizedName = _validatedPlaylistName(name);
    final timestamp = createdAt.toUtc();
    return _database
        .into(_database.libraryPlaylists)
        .insert(
          db.LibraryPlaylistsCompanion.insert(
            name: normalizedName,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  @override
  Future<void> renamePlaylist(
    int playlistId, {
    required String name,
    required DateTime changedAt,
  }) async {
    final changed =
        await (_database.update(
          _database.libraryPlaylists,
        )..where((row) => row.id.equals(playlistId))).write(
          db.LibraryPlaylistsCompanion(
            name: Value(_validatedPlaylistName(name)),
            updatedAt: Value(changedAt.toUtc()),
          ),
        );
    if (changed == 0) throw StateError('Unknown playlist: $playlistId');
  }

  @override
  Future<void> deletePlaylist(int playlistId) async {
    final changed = await (_database.delete(
      _database.libraryPlaylists,
    )..where((row) => row.id.equals(playlistId))).go();
    if (changed == 0) throw StateError('Unknown playlist: $playlistId');
  }

  @override
  Future<bool> addTrackToPlaylist(
    int playlistId,
    String trackId, {
    required DateTime addedAt,
  }) async {
    if (trackId.trim().isEmpty) {
      throw ArgumentError.value(trackId, 'trackId', 'Must not be empty.');
    }
    return _database.transaction(() async {
      final existing =
          await (_database.select(_database.libraryPlaylistTracks)..where(
                (row) =>
                    row.playlistId.equals(playlistId) &
                    row.trackId.equals(trackId),
              ))
              .getSingleOrNull();
      if (existing != null) return false;

      final playlist = await (_database.select(
        _database.libraryPlaylists,
      )..where((row) => row.id.equals(playlistId))).getSingleOrNull();
      if (playlist == null) throw StateError('Unknown playlist: $playlistId');

      final last =
          await (_database.select(_database.libraryPlaylistTracks)
                ..where((row) => row.playlistId.equals(playlistId))
                ..orderBy([(row) => OrderingTerm.desc(row.position)])
                ..limit(1))
              .getSingleOrNull();
      final timestamp = addedAt.toUtc();
      await _database
          .into(_database.libraryPlaylistTracks)
          .insert(
            db.LibraryPlaylistTracksCompanion.insert(
              playlistId: playlistId,
              trackId: trackId,
              position: (last?.position ?? -1) + 1,
              addedAt: timestamp,
            ),
          );
      await _touchPlaylist(playlistId, timestamp);
      return true;
    });
  }

  @override
  Future<void> removeTrackFromPlaylist(
    int playlistId,
    String trackId, {
    required DateTime changedAt,
  }) async {
    await _database.transaction(() async {
      final changed =
          await (_database.delete(_database.libraryPlaylistTracks)..where(
                (row) =>
                    row.playlistId.equals(playlistId) &
                    row.trackId.equals(trackId),
              ))
              .go();
      if (changed > 0) await _touchPlaylist(playlistId, changedAt.toUtc());
    });
  }

  @override
  Future<void> reorderPlaylistTracks(
    int playlistId,
    List<String> orderedTrackIds, {
    required DateTime changedAt,
  }) async {
    if (orderedTrackIds.toSet().length != orderedTrackIds.length) {
      throw ArgumentError('Playlist order contains duplicate track IDs.');
    }
    await _database.transaction(() async {
      final current = await (_database.select(
        _database.libraryPlaylistTracks,
      )..where((row) => row.playlistId.equals(playlistId))).get();
      final currentIds = current.map((row) => row.trackId).toSet();
      if (currentIds.length != orderedTrackIds.length ||
          !currentIds.containsAll(orderedTrackIds)) {
        throw ArgumentError('Playlist order must contain every track once.');
      }
      await _database.batch((writer) {
        for (var index = 0; index < orderedTrackIds.length; index++) {
          writer.update(
            _database.libraryPlaylistTracks,
            db.LibraryPlaylistTracksCompanion(position: Value(index)),
            where: (row) =>
                row.playlistId.equals(playlistId) &
                row.trackId.equals(orderedTrackIds[index]),
          );
        }
      });
      await _touchPlaylist(playlistId, changedAt.toUtc());
    });
  }

  Future<void> _touchPlaylist(int playlistId, DateTime changedAt) async {
    final changed =
        await (_database.update(
          _database.libraryPlaylists,
        )..where((row) => row.id.equals(playlistId))).write(
          db.LibraryPlaylistsCompanion(updatedAt: Value(changedAt.toUtc())),
        );
    if (changed == 0) throw StateError('Unknown playlist: $playlistId');
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
    type: LibrarySourceType.fromName(row.type),
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

LibraryFavoriteTrackRecord _favoriteRecord(db.LibraryFavoriteTrack row) {
  return LibraryFavoriteTrackRecord(
    trackId: row.trackId,
    addedAt: row.addedAt.toUtc(),
  );
}

LibraryPlayHistoryRecord _historyRecord(db.LibraryPlayHistoryData row) {
  return LibraryPlayHistoryRecord(
    id: row.id,
    trackId: row.trackId,
    playedAt: row.playedAt.toUtc(),
  );
}

LibraryPlaylistRecord _playlistRecord(db.LibraryPlaylist row) {
  return LibraryPlaylistRecord(
    id: row.id,
    name: row.name,
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
  );
}

LibraryPlaylistTrackRecord _playlistTrackRecord(db.LibraryPlaylistTrack row) {
  return LibraryPlaylistTrackRecord(
    playlistId: row.playlistId,
    trackId: row.trackId,
    position: row.position,
    addedAt: row.addedAt.toUtc(),
  );
}

String _validatedPlaylistName(String name) {
  final normalized = name.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(name, 'name', 'Must not be empty.');
  }
  if (normalized.length > 100) {
    throw ArgumentError.value(name, 'name', 'Must be at most 100 characters.');
  }
  return normalized;
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

bool _sameArtist(db.LibraryArtist old, LibraryArtistRecord current) {
  return old.id == current.id &&
      old.sourceId == current.sourceId &&
      old.name == current.name &&
      old.sortName == current.sortName;
}

bool _sameAlbum(db.LibraryAlbum old, LibraryAlbumRecord current) {
  return old.id == current.id &&
      old.sourceId == current.sourceId &&
      old.artistId == current.artistId &&
      old.title == current.title &&
      old.sortTitle == current.sortTitle &&
      old.albumArtist == current.albumArtist &&
      old.year == current.year &&
      old.genre == current.genre &&
      old.artworkKey == current.artworkKey;
}

bool _sameTrack(db.LibraryTrack old, LibraryTrackRecord current) {
  return old.id == current.id &&
      old.sourceId == current.sourceId &&
      old.albumId == current.albumId &&
      old.artistId == current.artistId &&
      old.relativePath == current.relativePath &&
      old.mediaUri == current.mediaUri &&
      old.title == current.title &&
      old.artistName == current.artistName &&
      old.albumTitle == current.albumTitle &&
      old.durationMs == current.durationMs &&
      old.trackNumber == current.trackNumber &&
      old.discNumber == current.discNumber &&
      old.year == current.year &&
      old.genre == current.genre &&
      old.contentType == current.contentType &&
      old.fileSize == current.fileSize &&
      old.modifiedAt.toUtc() == current.modifiedAt.toUtc() &&
      old.artworkKey == current.artworkKey;
}

bool _sameLyrics(List<db.LibraryLyric> old, List<LibraryLyricRecord> current) {
  if (old.length != current.length) return false;
  final sortedOld = [...old]
    ..sort((left, right) {
      final bySequence = left.sequence.compareTo(right.sequence);
      return bySequence != 0
          ? bySequence
          : left.timestampMs.compareTo(right.timestampMs);
    });
  final sortedCurrent = [...current]
    ..sort((left, right) {
      final bySequence = left.sequence.compareTo(right.sequence);
      return bySequence != 0
          ? bySequence
          : left.timestampMs.compareTo(right.timestampMs);
    });
  for (var index = 0; index < sortedOld.length; index++) {
    final left = sortedOld[index];
    final right = sortedCurrent[index];
    if (left.trackId != right.trackId ||
        left.sequence != right.sequence ||
        left.timestampMs != right.timestampMs ||
        left.content != right.text) {
      return false;
    }
  }
  return true;
}
