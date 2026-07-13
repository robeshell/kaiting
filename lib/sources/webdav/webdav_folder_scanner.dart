import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../library/library_records.dart';
import '../../library/library_repository.dart';
import '../../library/scanning/album_artist_resolver.dart';
import '../../library/scanning/album_grouping.dart';
import '../../library/scanning/artwork_store.dart';
import '../../library/scanning/audio_metadata_extractor.dart';
import 'webdav_connection_service.dart';
import 'webdav_credentials.dart';
import 'webdav_discovery.dart';

class WebDavFolderScanResult {
  const WebDavFolderScanResult({
    required this.indexedTracks,
    this.skippedFiles = 0,
  });

  final int indexedTracks;
  final int skippedFiles;
}

class WebDavFolderScanner {
  WebDavFolderScanner({
    required this.repository,
    this.artworkStore,
    AudioMetadataExtractor? metadataExtractor,
    WebDavDiscoveryService? discovery,
  }) : metadataExtractor =
           metadataExtractor ?? const PackageAudioMetadataExtractor(),
       discovery = discovery ?? WebDavDiscoveryService();

  final LibraryRepository repository;
  final ArtworkStore? artworkStore;
  final AudioMetadataExtractor metadataExtractor;
  final WebDavDiscoveryService discovery;

  /// Scans one or more [folderUrls] on the same WebDAV server. Each folder is
  /// persisted as a separate [LibrarySourceRecord] so the library screen can
  /// show its tracks alongside local content.
  Future<WebDavFolderScanResult> scan({
    required String connectionId,
    required List<String> folderUrls,
    required String baseUrl,
    required WebDavCredentials credentials,
    bool allowBadCertificate = false,
    String? existingSourceId,
  }) async {
    if (existingSourceId != null && folderUrls.length != 1) {
      throw ArgumentError.value(
        folderUrls,
        'folderUrls',
        'An existing source ID can only rescan one folder.',
      );
    }
    final effectiveDiscovery = allowBadCertificate
        ? WebDavDiscoveryService(allowBadCertificate: true)
        : discovery;
    var totalIndexed = 0;
    var totalSkipped = 0;

    for (final folderUrl in folderUrls) {
      final folderPath = _folderPath(folderUrl);
      final sourceId =
          existingSourceId ??
          WebDavConnectionService.stableWebDavFolderSourceId(
            connectionId,
            folderPath,
          );
      final now = DateTime.now().toUtc();
      final existing = await repository.getSource(sourceId);

      try {
        await repository.upsertSource(
          LibrarySourceRecord(
            id: sourceId,
            type: LibrarySourceType.webDav,
            displayName: _displayNameForFolder(folderPath, baseUrl),
            rootUri: folderPath,
            status: LibrarySourceStatus.scanning,
            scanRevision: existing?.scanRevision ?? 0,
            lastScanStartedAt: now,
            lastScanCompletedAt: existing?.lastScanCompletedAt,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );

        final fullFolderUrl = _resolveFolderUrl(baseUrl, folderPath);

        final files = await _collectAudioFiles(
          fullFolderUrl,
          baseUrl,
          credentials: credentials,
          discovery: effectiveDiscovery,
        );

        final batch = await _buildBatch(
          sourceId,
          fullFolderUrl,
          files,
          credentials: credentials,
          completedAt: DateTime.now().toUtc(),
          allowBadCertificate: allowBadCertificate,
        );

        await repository.replaceSourceScan(batch);
        totalIndexed += batch.tracks.length;
        totalSkipped += files.length - batch.tracks.length;
      } catch (error) {
        if (await repository.getSource(sourceId) != null) {
          await repository.markSourceFailure(
            sourceId,
            status: LibrarySourceStatus.error,
            message: error.toString(),
            occurredAt: DateTime.now().toUtc(),
          );
        } else {
          rethrow;
        }
        totalSkipped++;
      }
    }

    return WebDavFolderScanResult(
      indexedTracks: totalIndexed,
      skippedFiles: totalSkipped,
    );
  }

  Future<List<String>> _collectAudioFiles(
    String fullUrl,
    String connectionBaseUrl, {
    required WebDavCredentials credentials,
    required WebDavDiscoveryService discovery,
  }) async {
    final files = <String>{};
    final pending = <String>[fullUrl];
    final visited = <String>{};

    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) continue;

      final result = await discovery.probe(current, credentials: credentials);
      if (result.error != null) {
        throw StateError(result.errorMessage ?? '无法读取 WebDAV 目录：$current');
      }

      for (final entry in result.files) {
        // Use the server-returned href as the canonical path.
        final childUrl = _resolveChildUrl(
          connectionBaseUrl,
          current,
          entry.href,
        );
        if (childUrl == null) continue;
        // Skip self-referencing entry (the directory's own href).
        if (_sameResource(childUrl, current)) continue;

        if (entry.isCollection) {
          pending.add(childUrl);
        } else if (_isAudioFile(entry.displayName)) {
          files.add(childUrl);
        }
      }
    }

    return files.toList(growable: false);
  }

  /// Resolves a child URL from a parent [baseUrl] and a PROPFIND [href].
  /// The href may be absolute (starting with `/`) or relative.
  String? _resolveChildUrl(
    String connectionBaseUrl,
    String currentUrl,
    String href,
  ) {
    if (href.isEmpty) return null;
    final trusted = Uri.parse(connectionBaseUrl);
    final current = Uri.parse(currentUrl);
    final hrefUri = Uri.tryParse(href);
    if (hrefUri == null) return null;
    final resolved = hrefUri.hasScheme ? hrefUri : current.resolveUri(hrefUri);
    if (resolved.scheme.toLowerCase() != trusted.scheme.toLowerCase() ||
        resolved.host.toLowerCase() != trusted.host.toLowerCase() ||
        resolved.port != trusted.port) {
      return null;
    }
    return resolved.replace(fragment: null).toString();
  }

  String _resolveFolderUrl(String baseUrl, String folderPath) {
    final base = Uri.parse(baseUrl);
    return base.resolve(folderPath).replace(fragment: null).toString();
  }

  String _folderPath(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      return Uri(
        path: uri.path,
        query: uri.hasQuery ? uri.query : null,
      ).toString();
    }
    return value.startsWith('/') ? value : '/$value';
  }

  bool _sameResource(String left, String right) {
    String normalize(String value) {
      final uri = Uri.parse(value);
      final path = uri.path.length > 1 && uri.path.endsWith('/')
          ? uri.path.substring(0, uri.path.length - 1)
          : uri.path;
      return uri.replace(path: path, fragment: null).toString();
    }

    return normalize(left) == normalize(right);
  }

  Future<LibraryScanBatch> _buildBatch(
    String sourceId,
    String baseFolderUrl,
    List<String> fileUrls, {
    required WebDavCredentials credentials,
    required DateTime completedAt,
    bool allowBadCertificate = false,
  }) async {
    final tracks = <LibraryTrackRecord>[];
    final albums = <String, LibraryAlbumRecord>{};
    final albumArtists = <String, AlbumArtistResolver>{};
    final artists = <String, LibraryArtistRecord>{};
    final lyrics = <LibraryLyricRecord>[];

    try {
      for (final fileUrl in fileUrls) {
        try {
          final metadata = await _readRemoteMetadata(
            fileUrl,
            credentials: credentials,
            allowBadCertificate: allowBadCertificate,
          );
          if (metadata == null) continue;

          final title = metadata.title.isNotEmpty
              ? metadata.title
              : p.basenameWithoutExtension(fileUrl);
          final artistName = metadata.artist.isNotEmpty
              ? metadata.artist
              : '未知艺人';
          final albumTitle = metadata.album.isNotEmpty
              ? metadata.album
              : '未知专辑';
          final albumId = stableGroupedAlbumId(
            sourceId: sourceId,
            albumTitle: albumTitle,
            albumArtist: metadata.albumArtist,
            isCompilation: metadata.isCompilation,
            relativePath: fileUrl,
            discNumber: metadata.discNumber,
          );
          final artistId = _stableId('artist:$sourceId:$artistName');
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
              sourceId: sourceId,
              name: artistName,
              sortName: _sortName(artistName),
            ),
          );

          final existingAlbum = albums[albumId];
          var artworkKey = existingAlbum?.artworkKey;
          if (artworkKey == null && metadata.artworkBytes != null) {
            artworkKey = await _storeArtwork(
              albumId,
              metadata.artworkBytes,
              metadata.artworkMimeType,
            );
          }
          albums[albumId] = LibraryAlbumRecord(
            id: albumId,
            sourceId: sourceId,
            title: albumTitle,
            sortTitle: _sortName(albumTitle),
            albumArtist: metadata.albumArtist ?? artistName,
            artistId: artistId,
            year: metadata.year ?? existingAlbum?.year,
            genre: metadata.genre.isNotEmpty
                ? metadata.genre
                : existingAlbum?.genre,
            artworkKey: artworkKey,
          );

          final trackId = _stableId('track:$sourceId:$fileUrl');
          tracks.add(
            LibraryTrackRecord(
              id: trackId,
              sourceId: sourceId,
              albumId: albumId,
              artistId: artistId,
              relativePath: fileUrl,
              mediaUri: fileUrl,
              title: title,
              artistName: artistName,
              albumTitle: albumTitle,
              durationMs: metadata.duration.inMilliseconds,
              trackNumber: metadata.trackNumber,
              discNumber: metadata.discNumber,
              year: metadata.year,
              genre: metadata.genre.isNotEmpty ? metadata.genre : null,
              contentType: _contentTypeFor(fileUrl),
              modifiedAt: completedAt,
            ),
          );

          if (metadata.lyrics.isNotEmpty) {
            lyrics.add(
              LibraryLyricRecord(
                trackId: trackId,
                sequence: 0,
                timestampMs: 0,
                text: metadata.lyrics,
              ),
            );
          }
        } catch (_) {
          // Skip damaged files.
        }
      }
    } finally {
      // Client closed per-file.
    }

    final resolvedAlbums = <LibraryAlbumRecord>[];
    for (final entry in albums.entries) {
      final album = entry.value;
      final albumArtist =
          albumArtists[entry.key]?.resolve() ?? album.albumArtist;
      final albumArtistId = albumArtist == '群星'
          ? null
          : _stableId('artist:$sourceId:$albumArtist');
      if (albumArtistId != null) {
        artists.putIfAbsent(
          albumArtistId,
          () => LibraryArtistRecord(
            id: albumArtistId,
            sourceId: sourceId,
            name: albumArtist,
            sortName: _sortName(albumArtist),
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

    return LibraryScanBatch(
      sourceId: sourceId,
      completedAt: completedAt,
      artists: artists.values.toList(growable: false),
      albums: resolvedAlbums,
      tracks: tracks,
      lyrics: lyrics,
    );
  }

  Future<_RemoteMetadata?> _readRemoteMetadata(
    String fileUrl, {
    required WebDavCredentials credentials,
    bool allowBadCertificate = false,
  }) async {
    final uri = Uri.parse(fileUrl);

    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    if (allowBadCertificate) {
      httpClient.badCertificateCallback = (_, _, _) => true;
    }

    try {
      final tempFile = File(
        '${Directory.systemTemp.path}/sound_webdav_scan_${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      try {
        // Try 256 KiB first; retry with 512 KiB if FLAC blocks extend further.
        var parsed = await _tryParseHeader(
          httpClient,
          uri,
          credentials,
          256 * 1024,
          tempFile,
        );
        if (parsed == null && fileUrl.toLowerCase().endsWith('.flac')) {
          parsed = await _tryParseHeader(
            httpClient,
            uri,
            credentials,
            512 * 1024,
            tempFile,
          );
        }
        return parsed;
      } finally {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<_RemoteMetadata?> _tryParseHeader(
    HttpClient client,
    Uri uri,
    WebDavCredentials credentials,
    int headerSize,
    File tempFile,
  ) async {
    Uint8List? downloadedBytes;
    try {
      final request = await client.getUrl(uri);
      request.headers
        ..set('Range', 'bytes=0-${headerSize - 1}')
        ..set(HttpHeaders.acceptHeader, '*/*');
      if (!credentials.isEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          credentials.basicHeaderValue,
        );
      }

      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200 && response.statusCode != 206) {
        await response.drain<void>();
        return null;
      }

      final bytesBuilder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        final remaining = headerSize - bytesBuilder.length;
        if (remaining <= 0) break;
        bytesBuilder.add(
          chunk.length <= remaining ? chunk : chunk.sublist(0, remaining),
        );
        if (bytesBuilder.length >= headerSize) break;
      }
      final bytes = bytesBuilder.takeBytes();
      downloadedBytes = bytes;

      if (bytes.isEmpty) return null;

      await tempFile.writeAsBytes(bytes);
      final metadata = await metadataExtractor.extract(tempFile);
      return _RemoteMetadata(
        title: metadata.title ?? '',
        artist: metadata.artist ?? '',
        album: metadata.album ?? '',
        albumArtist: metadata.albumArtist,
        isCompilation: metadata.isCompilation,
        genre: metadata.genre ?? '',
        year: metadata.year,
        trackNumber: metadata.trackNumber,
        discNumber: metadata.discNumber,
        duration: metadata.duration,
        lyrics: metadata.lyrics ?? '',
        artworkBytes: metadata.artwork?.bytes,
        artworkMimeType: metadata.artwork?.mimeType,
      );
    } catch (_) {
      // Some valid MP3 files have no Xing/VBR index or keep useful tags at the
      // end of the file. A header-only metadata read can fail for those even
      // though the native player can stream them. Keep a conservative MP3
      // fallback so they remain discoverable by filename.
      if (uri.path.toLowerCase().endsWith('.mp3') &&
          downloadedBytes != null &&
          _looksLikeMp3(downloadedBytes)) {
        return const _RemoteMetadata(
          title: '',
          artist: '',
          album: '',
          albumArtist: null,
          isCompilation: false,
          genre: '',
          year: null,
          trackNumber: 0,
          discNumber: 0,
          duration: Duration.zero,
          lyrics: '',
          artworkBytes: null,
          artworkMimeType: null,
        );
      }
      return null;
    }
  }

  bool _looksLikeMp3(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      return true;
    }
    final searchLength = min(bytes.length - 1, 4096);
    for (var i = 0; i < searchLength; i++) {
      if (bytes[i] != 0xff || (bytes[i + 1] & 0xe0) != 0xe0) continue;
      final version = (bytes[i + 1] >> 3) & 0x03;
      final layer = (bytes[i + 1] >> 1) & 0x03;
      if (version != 0x01 && layer != 0) return true;
    }
    return false;
  }

  String? _contentTypeFor(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.opus')) return 'audio/ogg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.aac')) return 'audio/aac';
    return 'application/octet-stream';
  }

  Future<String?> _storeArtwork(
    String albumId,
    List<int>? bytes,
    String? mimeType,
  ) async {
    final store = artworkStore;
    if (store == null || bytes == null || bytes.isEmpty) return null;
    try {
      return await store.store(
        albumId: albumId,
        bytes: bytes,
        mimeType: mimeType ?? 'image/jpeg',
      );
    } catch (_) {
      return null;
    }
  }

  bool _isAudioFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.mp3') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.opus');
  }

  String _displayNameForFolder(String folderUrl, String baseUrl) {
    final relative = folderUrl.startsWith(baseUrl)
        ? folderUrl.substring(baseUrl.length)
        : folderUrl;
    final segments = relative
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.decodeComponent)
        .toList();
    return segments.isNotEmpty ? segments.join(' / ') : folderUrl;
  }
}

class _RemoteMetadata {
  const _RemoteMetadata({
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.isCompilation,
    required this.genre,
    required this.year,
    required this.trackNumber,
    required this.discNumber,
    required this.duration,
    required this.lyrics,
    this.artworkBytes,
    this.artworkMimeType,
  });

  final String title;
  final String artist;
  final String album;
  final String? albumArtist;
  final bool isCompilation;
  final String genre;
  final int? year;
  final int trackNumber;
  final int discNumber;
  final Duration duration;
  final String lyrics;
  final List<int>? artworkBytes;
  final String? artworkMimeType;
}

String _stableId(String seed) {
  return sha256.convert(seed.codeUnits).toString();
}

String _sortName(String name) {
  final stripped = name.trim().toLowerCase();
  if (stripped.startsWith('the ')) return stripped.substring(4);
  if (stripped.startsWith('a ')) return stripped.substring(2);
  if (stripped.startsWith('an ')) return stripped.substring(3);
  return stripped;
}
