import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../library_records.dart';
import '../library_repository.dart';
import 'album_artist_resolver.dart';
import 'album_grouping.dart';
import 'artwork_store.dart';
import 'audio_metadata_fallback.dart';
import 'audio_metadata_extractor.dart';
import 'embedded_lyrics_parser.dart';
import 'local_media_catalog.dart';
import 'scan_cancellation.dart';

typedef ScannerUtcClock = DateTime Function();

class LocalScanReport {
  const LocalScanReport({
    required this.discoveredFiles,
    required this.indexedTracks,
    required this.skippedFiles,
    required this.warnings,
    this.addedTracks = 0,
    this.modifiedTracks = 0,
    this.movedTracks = 0,
    this.removedTracks = 0,
    this.unchangedTracks = 0,
  });

  final int discoveredFiles;
  final int indexedTracks;
  final int skippedFiles;
  final List<String> warnings;
  final int addedTracks;
  final int modifiedTracks;
  final int movedTracks;
  final int removedTracks;
  final int unchangedTracks;
}

class LocalLibraryScanner {
  LocalLibraryScanner({
    required this.repository,
    required this.catalog,
    AudioMetadataExtractor? metadataExtractor,
    ArtworkStore? artworkStore,
    ScannerUtcClock? clock,
  }) : metadataExtractor =
           metadataExtractor ?? const PackageAudioMetadataExtractor(),
       artworkStore = artworkStore ?? FileArtworkStore(),
       _clock = clock ?? _utcNow;

  final LibraryRepository repository;
  final LocalMediaCatalog catalog;
  final AudioMetadataExtractor metadataExtractor;
  final ArtworkStore artworkStore;
  final ScannerUtcClock _clock;
  final Map<String, ScanCancellationToken> _activeScans = {};

  bool cancel(String sourceId) {
    final token = _activeScans[sourceId];
    if (token == null) return false;
    token.cancel();
    return true;
  }

  Future<LocalScanReport> scan(
    LibrarySourceRecord source, {
    ScanCancellationToken? cancellationToken,
  }) async {
    if (source.type != LibrarySourceType.local) {
      throw ArgumentError.value(source.type, 'source.type', 'Expected local.');
    }
    if (_activeScans.containsKey(source.id)) {
      throw StateError('A scan is already active for ${source.displayName}.');
    }
    final token = cancellationToken ?? ScanCancellationToken();
    _activeScans[source.id] = token;

    final sourceBeforeScan = await repository.getSource(source.id) ?? source;
    final startedAt = _clock().toUtc();
    await repository.markSourceScanning(source.id, startedAt: startedAt);
    try {
      token.throwIfCancelled();
      final files = await catalog.listAudioFiles(source.rootUri);
      token.throwIfCancelled();
      final existingTracks = await repository.getTracks(sourceId: source.id);
      final existingAlbums = await repository.getAlbums(sourceId: source.id);
      final existingArtists = await repository.getArtists(sourceId: source.id);
      final allLyrics = await repository.getAllLyrics();
      token.throwIfCancelled();

      final existingTracksByPath = {
        for (final track in existingTracks) track.relativePath: track,
      };
      final currentPaths = files.map((file) => file.relativePath).toSet();
      final missingTracks = existingTracks
          .where((track) => !currentPaths.contains(track.relativePath))
          .toList(growable: false);
      final newFiles = files
          .where((file) => !existingTracksByPath.containsKey(file.relativePath))
          .toList(growable: false);
      final movedTracksByNewPath = _matchMovedTracks(missingTracks, newFiles);

      final artists = <String, LibraryArtistRecord>{
        for (final artist in existingArtists) artist.id: artist,
      };
      final albums = <String, LibraryAlbumRecord>{
        for (final album in existingAlbums) album.id: album,
      };
      final albumArtists = <String, AlbumArtistResolver>{};
      final tracks = <LibraryTrackRecord>[];
      final lyrics = <LibraryLyricRecord>[];
      final warnings = <String>[];
      var addedTracks = 0;
      var modifiedTracks = 0;
      var movedTracks = 0;
      var unchangedTracks = 0;

      for (final audioFile in files) {
        token.throwIfCancelled();
        final existing = existingTracksByPath[audioFile.relativePath];
        if (existing != null && _sameFileFingerprint(existing, audioFile)) {
          final reused = _reuseTrack(existing, audioFile);
          tracks.add(reused);
          lyrics.addAll(allLyrics[existing.id] ?? const []);
          _addExistingTrackToAlbumResolver(
            reused,
            albums: albums,
            albumArtists: albumArtists,
          );
          unchangedTracks++;
          continue;
        }

        final movedFrom = movedTracksByNewPath[audioFile.relativePath];
        PreparedLocalAudioFile? prepared;
        try {
          prepared = await catalog.prepareForMetadata(audioFile);
          ExtractedAudioMetadata metadata;
          try {
            metadata = await metadataExtractor.extract(prepared.file);
          } catch (_) {
            final fallback = await readFilenameMetadataFallback(
              prepared.file,
              audioFile.relativePath,
            );
            if (fallback == null) rethrow;
            metadata = fallback;
            warnings.add('${audioFile.relativePath}: 元数据不可读，已按文件名导入');
          }
          token.throwIfCancelled();
          final title = _valueOrFallback(
            metadata.title,
            path.basenameWithoutExtension(audioFile.relativePath),
          );
          final artistName = _valueOrFallback(metadata.artist, '未知艺人');
          final albumTitle = _valueOrFallback(metadata.album, '未知专辑');
          final artistId = stableArtistId(source.id, artistName);
          final albumId = stableAlbumId(
            source.id,
            albumTitle,
            albumArtist: metadata.albumArtist,
            isCompilation: metadata.isCompilation,
            relativePath: audioFile.relativePath,
            discNumber: metadata.discNumber,
          );
          final trackId =
              movedFrom?.id ??
              existing?.id ??
              stableTrackId(source.id, audioFile.relativePath);
          final albumArtistResolver = albumArtists.putIfAbsent(
            albumId,
            AlbumArtistResolver.new,
          );
          albumArtistResolver
            ..add(artistName)
            ..addAlbumArtist(metadata.albumArtist);
          if (metadata.isCompilation) {
            albumArtistResolver.markCompilation();
          }

          artists.putIfAbsent(
            artistId,
            () => LibraryArtistRecord(
              id: artistId,
              sourceId: source.id,
              name: artistName,
              sortName: normalizedLibraryText(artistName),
            ),
          );

          final existingAlbum = albums[albumId];
          var artworkKey = existingAlbum?.artworkKey;
          final artwork = metadata.artwork;
          if (artworkKey == null && artwork != null) {
            try {
              artworkKey = await artworkStore.store(
                albumId: albumId,
                bytes: artwork.bytes,
                mimeType: artwork.mimeType,
              );
            } catch (error) {
              warnings.add('${audioFile.relativePath} 封面：$error');
            }
          }
          albums[albumId] = LibraryAlbumRecord(
            id: albumId,
            sourceId: source.id,
            artistId: artistId,
            title: albumTitle,
            sortTitle: normalizedLibraryText(albumTitle),
            albumArtist: metadata.albumArtist ?? artistName,
            year: metadata.year ?? existingAlbum?.year,
            genre: _nullableValue(metadata.genre) ?? existingAlbum?.genre,
            artworkKey: artworkKey,
          );

          tracks.add(
            LibraryTrackRecord(
              id: trackId,
              sourceId: source.id,
              albumId: albumId,
              artistId: artistId,
              relativePath: audioFile.relativePath,
              mediaUri: audioFile.mediaUri,
              title: title,
              artistName: artistName,
              albumTitle: albumTitle,
              durationMs: metadata.duration.inMilliseconds,
              trackNumber: metadata.trackNumber,
              discNumber: metadata.discNumber,
              year: metadata.year,
              genre: _nullableValue(metadata.genre),
              contentType: audioFile.contentType,
              fileSize: audioFile.fileSize,
              modifiedAt: audioFile.modifiedAt.toUtc(),
              artworkKey: artworkKey,
            ),
          );
          lyrics.addAll(parseEmbeddedLyrics(trackId, metadata.lyrics));
          if (movedFrom != null) {
            movedTracks++;
          } else if (existing != null) {
            modifiedTracks++;
          } else {
            addedTracks++;
          }
        } catch (error) {
          if (error is ScanCancelledException) rethrow;
          warnings.add('${audioFile.relativePath}: $error');
        } finally {
          try {
            await prepared?.release();
          } catch (error) {
            warnings.add('${audioFile.relativePath} 临时文件：$error');
          }
        }
      }

      token.throwIfCancelled();
      final completedAt = _clock().toUtc();
      final referencedAlbumIds = tracks
          .map((track) => track.albumId)
          .whereType<String>()
          .toSet();
      final resolvedAlbums = <LibraryAlbumRecord>[];
      for (final entry in albums.entries) {
        if (!referencedAlbumIds.contains(entry.key)) continue;
        final album = entry.value;
        final albumArtist =
            albumArtists[entry.key]?.resolve() ?? album.albumArtist;
        final albumArtistId = albumArtist == '群星'
            ? null
            : stableArtistId(source.id, albumArtist);
        if (albumArtistId != null) {
          artists.putIfAbsent(
            albumArtistId,
            () => LibraryArtistRecord(
              id: albumArtistId,
              sourceId: source.id,
              name: albumArtist,
              sortName: normalizedLibraryText(albumArtist),
            ),
          );
        }
        resolvedAlbums.add(
          LibraryAlbumRecord(
            id: album.id,
            sourceId: album.sourceId,
            artistId: albumArtistId,
            title: album.title,
            sortTitle: album.sortTitle,
            albumArtist: albumArtist,
            year: album.year,
            genre: album.genre,
            artworkKey: album.artworkKey,
          ),
        );
      }
      final referencedArtistIds = <String>{
        ...tracks.map((track) => track.artistId).whereType<String>(),
        ...resolvedAlbums.map((album) => album.artistId).whereType<String>(),
      };
      final resolvedArtists = artists.values
          .where((artist) => referencedArtistIds.contains(artist.id))
          .toList(growable: false);
      token.throwIfCancelled();
      await repository.replaceSourceScan(
        LibraryScanBatch(
          sourceId: source.id,
          completedAt: completedAt,
          artists: resolvedArtists,
          albums: resolvedAlbums,
          tracks: tracks,
          lyrics: lyrics,
        ),
      );
      return LocalScanReport(
        discoveredFiles: files.length,
        indexedTracks: tracks.length,
        skippedFiles: files.length - tracks.length,
        warnings: List.unmodifiable(warnings),
        addedTracks: addedTracks,
        modifiedTracks: modifiedTracks,
        movedTracks: movedTracks,
        removedTracks: missingTracks.length - movedTracks,
        unchangedTracks: unchangedTracks,
      );
    } on ScanCancelledException {
      await repository.upsertSource(
        _sourceAfterCancelledScan(
          sourceBeforeScan,
          occurredAt: _clock().toUtc(),
        ),
      );
      rethrow;
    } catch (error) {
      await repository.markSourceFailure(
        source.id,
        status: _failureStatus(error),
        message: error.toString(),
        occurredAt: _clock().toUtc(),
      );
      rethrow;
    } finally {
      _activeScans.remove(source.id);
    }
  }
}

Map<String, LibraryTrackRecord> _matchMovedTracks(
  List<LibraryTrackRecord> missingTracks,
  List<LocalAudioFile> newFiles,
) {
  final oldByFingerprint = <_LocalFileFingerprint, List<LibraryTrackRecord>>{};
  for (final track in missingTracks) {
    final fingerprint = _trackFingerprint(track);
    if (fingerprint == null) continue;
    oldByFingerprint.putIfAbsent(fingerprint, () => []).add(track);
  }
  final newByFingerprint = <_LocalFileFingerprint, List<LocalAudioFile>>{};
  for (final file in newFiles) {
    final fingerprint = _audioFileFingerprint(file);
    if (fingerprint == null) continue;
    newByFingerprint.putIfAbsent(fingerprint, () => []).add(file);
  }

  final matches = <String, LibraryTrackRecord>{};
  for (final entry in newByFingerprint.entries) {
    final oldCandidates = oldByFingerprint[entry.key];
    if (entry.value.length != 1 || oldCandidates?.length != 1) continue;
    matches[entry.value.single.relativePath] = oldCandidates!.single;
  }
  return matches;
}

bool _sameFileFingerprint(LibraryTrackRecord track, LocalAudioFile audioFile) {
  return track.fileSize == audioFile.fileSize &&
      track.modifiedAt.toUtc() == audioFile.modifiedAt.toUtc();
}

LibraryTrackRecord _reuseTrack(
  LibraryTrackRecord track,
  LocalAudioFile audioFile,
) {
  return LibraryTrackRecord(
    id: track.id,
    sourceId: track.sourceId,
    albumId: track.albumId,
    artistId: track.artistId,
    relativePath: audioFile.relativePath,
    mediaUri: audioFile.mediaUri,
    title: track.title,
    artistName: track.artistName,
    albumTitle: track.albumTitle,
    durationMs: track.durationMs,
    trackNumber: track.trackNumber,
    discNumber: track.discNumber,
    year: track.year,
    genre: track.genre,
    contentType: audioFile.contentType ?? track.contentType,
    fileSize: audioFile.fileSize,
    modifiedAt: audioFile.modifiedAt.toUtc(),
    artworkKey: track.artworkKey,
  );
}

void _addExistingTrackToAlbumResolver(
  LibraryTrackRecord track, {
  required Map<String, LibraryAlbumRecord> albums,
  required Map<String, AlbumArtistResolver> albumArtists,
}) {
  final albumId = track.albumId;
  if (albumId == null) return;
  final album = albums[albumId];
  if (album == null) return;
  albumArtists.putIfAbsent(albumId, AlbumArtistResolver.new)
    ..add(track.artistName)
    ..addAlbumArtist(album.albumArtist);
}

LibrarySourceRecord _sourceAfterCancelledScan(
  LibrarySourceRecord source, {
  required DateTime occurredAt,
}) {
  final restoredStatus = source.status == LibrarySourceStatus.scanning
      ? (source.scanRevision > 0
            ? LibrarySourceStatus.available
            : LibrarySourceStatus.idle)
      : source.status;
  return LibrarySourceRecord(
    id: source.id,
    type: source.type,
    displayName: source.displayName,
    rootUri: source.rootUri,
    permissionBookmark: source.permissionBookmark,
    status: restoredStatus,
    scanRevision: source.scanRevision,
    lastScanStartedAt: source.lastScanStartedAt,
    lastScanCompletedAt: source.lastScanCompletedAt,
    lastError: source.lastError,
    createdAt: source.createdAt,
    updatedAt: occurredAt.toUtc(),
  );
}

_LocalFileFingerprint? _trackFingerprint(LibraryTrackRecord track) {
  final size = track.fileSize;
  if (size == null) return null;
  return _LocalFileFingerprint(size, track.modifiedAt.toUtc());
}

_LocalFileFingerprint? _audioFileFingerprint(LocalAudioFile file) {
  final size = file.fileSize;
  if (size == null) return null;
  return _LocalFileFingerprint(size, file.modifiedAt.toUtc());
}

class _LocalFileFingerprint {
  const _LocalFileFingerprint(this.size, this.modifiedAt);

  final int size;
  final DateTime modifiedAt;

  @override
  bool operator ==(Object other) {
    return other is _LocalFileFingerprint &&
        other.size == size &&
        other.modifiedAt == modifiedAt;
  }

  @override
  int get hashCode => Object.hash(size, modifiedAt);
}

String stableTrackId(String sourceId, String relativePath) =>
    'track:${Uri.encodeComponent(sourceId)}:${Uri.encodeComponent(relativePath)}';

String stableArtistId(String sourceId, String artistName) =>
    'artist:${Uri.encodeComponent(sourceId)}:'
    '${Uri.encodeComponent(normalizedLibraryText(artistName))}';

String stableAlbumId(
  String sourceId,
  String albumTitle, {
  String? albumArtist,
  bool isCompilation = false,
  String? relativePath,
  int discNumber = 0,
}) => stableGroupedAlbumId(
  sourceId: sourceId,
  albumTitle: albumTitle,
  albumArtist: albumArtist,
  isCompilation: isCompilation,
  relativePath: relativePath,
  discNumber: discNumber,
);

String normalizedLibraryText(String value) => value.trim().toLowerCase();

String _valueOrFallback(String? value, String fallback) =>
    _nullableValue(value) ?? fallback;

String? _nullableValue(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

LibrarySourceStatus _failureStatus(Object error) {
  if (error is FileSystemException) return LibrarySourceStatus.unavailable;
  if (error is PlatformException &&
      (error.code.toLowerCase().contains('permission') ||
          error.code.toLowerCase().contains('access'))) {
    return LibrarySourceStatus.permissionRequired;
  }
  return LibrarySourceStatus.error;
}

DateTime _utcNow() => DateTime.now().toUtc();
