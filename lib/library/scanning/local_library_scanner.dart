import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../library_records.dart';
import '../library_repository.dart';
import 'album_artist_resolver.dart';
import 'artwork_store.dart';
import 'audio_metadata_extractor.dart';
import 'embedded_lyrics_parser.dart';
import 'local_media_catalog.dart';

typedef ScannerUtcClock = DateTime Function();

class LocalScanReport {
  const LocalScanReport({
    required this.discoveredFiles,
    required this.indexedTracks,
    required this.skippedFiles,
    required this.warnings,
  });

  final int discoveredFiles;
  final int indexedTracks;
  final int skippedFiles;
  final List<String> warnings;
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
  final Set<String> _activeSourceIds = {};

  Future<LocalScanReport> scan(LibrarySourceRecord source) async {
    if (source.type != LibrarySourceType.local) {
      throw ArgumentError.value(source.type, 'source.type', 'Expected local.');
    }
    if (!_activeSourceIds.add(source.id)) {
      throw StateError('A scan is already active for ${source.displayName}.');
    }

    final startedAt = _clock().toUtc();
    await repository.markSourceScanning(source.id, startedAt: startedAt);
    try {
      final files = await catalog.listAudioFiles(source.rootUri);
      final artists = <String, LibraryArtistRecord>{};
      final albums = <String, LibraryAlbumRecord>{};
      final albumArtists = <String, AlbumArtistResolver>{};
      final tracks = <LibraryTrackRecord>[];
      final lyrics = <LibraryLyricRecord>[];
      final warnings = <String>[];

      for (final audioFile in files) {
        PreparedLocalAudioFile? prepared;
        try {
          prepared = await catalog.prepareForMetadata(audioFile);
          final metadata = await metadataExtractor.extract(prepared.file);
          final title = _valueOrFallback(
            metadata.title,
            path.basenameWithoutExtension(audioFile.relativePath),
          );
          final artistName = _valueOrFallback(metadata.artist, '未知艺人');
          final albumTitle = _valueOrFallback(metadata.album, '未知专辑');
          final artistId = stableArtistId(source.id, artistName);
          final albumId = stableAlbumId(source.id, albumTitle);
          final trackId = stableTrackId(source.id, audioFile.relativePath);
          albumArtists
              .putIfAbsent(albumId, AlbumArtistResolver.new)
              .add(artistName);

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
            albumArtist: artistName,
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
        } catch (error) {
          warnings.add('${audioFile.relativePath}: $error');
        } finally {
          try {
            await prepared?.release();
          } catch (error) {
            warnings.add('${audioFile.relativePath} 临时文件：$error');
          }
        }
      }

      final completedAt = _clock().toUtc();
      final resolvedAlbums = <LibraryAlbumRecord>[];
      for (final entry in albums.entries) {
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
      await repository.replaceSourceScan(
        LibraryScanBatch(
          sourceId: source.id,
          completedAt: completedAt,
          artists: artists.values.toList(growable: false),
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
      );
    } catch (error) {
      await repository.markSourceFailure(
        source.id,
        status: _failureStatus(error),
        message: error.toString(),
        occurredAt: _clock().toUtc(),
      );
      rethrow;
    } finally {
      _activeSourceIds.remove(source.id);
    }
  }
}

String stableTrackId(String sourceId, String relativePath) =>
    'track:${Uri.encodeComponent(sourceId)}:${Uri.encodeComponent(relativePath)}';

String stableArtistId(String sourceId, String artistName) =>
    'artist:${Uri.encodeComponent(sourceId)}:'
    '${Uri.encodeComponent(normalizedLibraryText(artistName))}';

String stableAlbumId(String sourceId, String albumTitle) =>
    'album:${Uri.encodeComponent(sourceId)}:'
    '${Uri.encodeComponent(normalizedLibraryText(albumTitle))}';

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
