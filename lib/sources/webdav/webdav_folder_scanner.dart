import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../library/library_records.dart';
import '../../library/scanning/embedded_lyrics_parser.dart';
import '../../library/scanning/scan_cancellation.dart';
import '../../library/library_repository.dart';
import '../../library/scanning/album_artist_resolver.dart';
import '../../library/scanning/album_grouping.dart';
import '../../library/scanning/artwork_store.dart';
import '../../library/scanning/audio_format_registry.dart';
import '../../library/scanning/audio_metadata_extractor.dart';
import '../../library/scanning/image_bytes.dart';
import '../../library/scanning/scan_task_pool.dart';
import 'webdav_connection_service.dart';
import 'webdav_credentials.dart';
import 'webdav_discovery.dart';

class WebDavFolderScanResult {
  const WebDavFolderScanResult({
    required this.indexedTracks,
    this.skippedFiles = 0,
    this.addedTracks = 0,
    this.modifiedTracks = 0,
    this.movedTracks = 0,
    this.removedTracks = 0,
    this.unchangedTracks = 0,
    this.warnings = const <String>[],
  });

  final int indexedTracks;
  final int skippedFiles;
  final int addedTracks;
  final int modifiedTracks;
  final int movedTracks;
  final int removedTracks;
  final int unchangedTracks;
  final List<String> warnings;
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
  final Map<String, ScanCancellationToken> _activeScans = {};

  bool isScanning(String sourceId) => _activeScans.containsKey(sourceId);

  bool cancel(String sourceId) {
    final token = _activeScans[sourceId];
    if (token == null) return false;
    token.cancel();
    return true;
  }

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
    var totalAdded = 0;
    var totalModified = 0;
    var totalMoved = 0;
    var totalRemoved = 0;
    var totalUnchanged = 0;
    final warnings = <String>[];

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
      if (_activeScans.containsKey(sourceId)) {
        throw StateError('A scan is already active for $folderPath.');
      }
      final cancellationToken = ScanCancellationToken();
      _activeScans[sourceId] = cancellationToken;

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
        cancellationToken.throwIfCancelled();

        final fullFolderUrl = _resolveFolderUrl(baseUrl, folderPath);

        final files = await _collectAudioFiles(
          fullFolderUrl,
          baseUrl,
          credentials: credentials,
          discovery: effectiveDiscovery,
          cancellationToken: cancellationToken,
        );

        final build = await _buildBatch(
          sourceId,
          files,
          credentials: credentials,
          completedAt: DateTime.now().toUtc(),
          allowBadCertificate: allowBadCertificate,
          cancellationToken: cancellationToken,
        );

        cancellationToken.throwIfCancelled();
        await repository.replaceSourceScan(build.batch);
        totalIndexed += build.batch.tracks.length;
        totalSkipped += files.length - build.batch.tracks.length;
        totalAdded += build.addedTracks;
        totalModified += build.modifiedTracks;
        totalMoved += build.movedTracks;
        totalRemoved += build.removedTracks;
        totalUnchanged += build.unchangedTracks;
        warnings.addAll(build.warnings);
      } on ScanCancelledException {
        if (existing == null) {
          await repository.deleteSource(sourceId);
        } else {
          await repository.upsertSource(
            _sourceAfterCancelledScan(
              existing,
              occurredAt: DateTime.now().toUtc(),
            ),
          );
        }
        rethrow;
      } catch (error) {
        await repository.markSourceFailure(
          sourceId,
          status: LibrarySourceStatus.error,
          message: error.toString(),
          occurredAt: DateTime.now().toUtc(),
        );
        rethrow;
      } finally {
        _activeScans.remove(sourceId);
      }
    }

    return WebDavFolderScanResult(
      indexedTracks: totalIndexed,
      skippedFiles: totalSkipped,
      addedTracks: totalAdded,
      modifiedTracks: totalModified,
      movedTracks: totalMoved,
      removedTracks: totalRemoved,
      unchangedTracks: totalUnchanged,
      warnings: List.unmodifiable(warnings),
    );
  }

  Future<List<_RemoteAudioFile>> _collectAudioFiles(
    String fullUrl,
    String connectionBaseUrl, {
    required WebDavCredentials credentials,
    required WebDavDiscoveryService discovery,
    required ScanCancellationToken cancellationToken,
  }) async {
    final files = <String, _RemoteAudioFile>{};
    final pending = <String>[fullUrl];
    final visited = <String>{};

    while (pending.isNotEmpty) {
      cancellationToken.throwIfCancelled();
      final current = pending.removeLast();
      if (!visited.add(current)) continue;

      final result = await discovery.probe(current, credentials: credentials);
      cancellationToken.throwIfCancelled();
      if (result.error != null) {
        throw StateError(result.errorMessage ?? '无法读取 WebDAV 目录：$current');
      }

      for (final entry in result.files) {
        cancellationToken.throwIfCancelled();
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
        } else {
          // A server may use an opaque or rewritten download URL whose path
          // looks like a normal audio file while `displayname` reveals that
          // the resource is actually a macOS AppleDouble sidecar. Check both
          // identities before considering the extension.
          if (isSystemMetadataPath(childUrl) ||
              isSystemMetadataPath(entry.displayName)) {
            continue;
          }
          // Some WebDAV servers expose a friendly `displayname` without the
          // original extension. Prefer the canonical href for format
          // detection, while retaining displayName as a compatibility
          // fallback for servers that use opaque download URLs.
          final format =
              audioFormatForPath(childUrl) ??
              audioFormatForPath(entry.displayName);
          if (format == null) continue;
          files[childUrl] = _RemoteAudioFile(
            url: childUrl,
            displayName: entry.displayName,
            contentType: format.contentType,
            extension: format.extension,
            contentLength: entry.contentLength,
            modifiedAt: entry.modifiedAt?.toUtc(),
          );
        }
      }
    }

    final result = files.values.toList(growable: false)
      ..sort((left, right) => left.url.compareTo(right.url));
    return result;
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

  Future<_WebDavBatchBuild> _buildBatch(
    String sourceId,
    List<_RemoteAudioFile> files, {
    required WebDavCredentials credentials,
    required DateTime completedAt,
    required ScanCancellationToken cancellationToken,
    bool allowBadCertificate = false,
  }) async {
    final existingTracks = await repository.getTracks(sourceId: sourceId);
    final existingAlbums = await repository.getAlbums(sourceId: sourceId);
    final existingArtists = await repository.getArtists(sourceId: sourceId);
    final allLyrics = await repository.getAllLyrics();
    cancellationToken.throwIfCancelled();

    final existingTracksByUrl = {
      for (final track in existingTracks) track.relativePath: track,
    };
    final currentUrls = files.map((file) => file.url).toSet();
    final missingTracks = existingTracks
        .where((track) => !currentUrls.contains(track.relativePath))
        .toList(growable: false);
    final newFiles = files
        .where((file) => !existingTracksByUrl.containsKey(file.url))
        .toList(growable: false);
    final movedTracksByNewUrl = _matchMovedTracks(missingTracks, newFiles);

    final tracks = <LibraryTrackRecord>[];
    final albums = <String, LibraryAlbumRecord>{
      for (final album in existingAlbums) album.id: album,
    };
    final albumArtists = <String, AlbumArtistResolver>{};
    final artists = <String, LibraryArtistRecord>{
      for (final artist in existingArtists) artist.id: artist,
    };
    final lyrics = <LibraryLyricRecord>[];
    var addedTracks = 0;
    var modifiedTracks = 0;
    var movedTracks = 0;
    var unchangedTracks = 0;
    final warnings = <String>[];

    final filesNeedingMetadata = files
        .where((file) {
          final existing = existingTracksByUrl[file.url];
          return existing == null || !_shouldReuseRemoteTrack(existing, file);
        })
        .toList(growable: false);
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 4;
    if (allowBadCertificate) {
      httpClient.badCertificateCallback = (_, _, _) => true;
    }

    try {
      final metadataReads =
          await mapScanTasks<_RemoteAudioFile, _RemoteMetadataReadResult>(
            filesNeedingMetadata,
            maxConcurrency: 4,
            task: (file) async {
              cancellationToken.throwIfCancelled();
              try {
                final metadata = await _readRemoteMetadata(
                  file,
                  credentials: credentials,
                  httpClient: httpClient,
                );
                cancellationToken.throwIfCancelled();
                return _RemoteMetadataReadResult.success(metadata);
              } on _RejectedRemoteAudioException {
                return const _RemoteMetadataReadResult.rejected();
              } catch (error, stackTrace) {
                if (error is ScanCancelledException) rethrow;
                return _RemoteMetadataReadResult.failure(error, stackTrace);
              }
            },
          );
      final metadataByUrl = <String, _RemoteMetadataReadResult>{
        for (var index = 0; index < filesNeedingMetadata.length; index++)
          filesNeedingMetadata[index].url: metadataReads[index],
      };

      for (final file in files) {
        cancellationToken.throwIfCancelled();
        final existing = existingTracksByUrl[file.url];
        if (existing != null && _shouldReuseRemoteTrack(existing, file)) {
          final reused = _reuseRemoteTrack(existing, file);
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

        final movedFrom = movedTracksByNewUrl[file.url];
        try {
          final metadataRead = metadataByUrl[file.url]!;
          if (metadataRead.rejected) continue;
          if (metadataRead.error != null) {
            Error.throwWithStackTrace(
              metadataRead.error!,
              metadataRead.stackTrace!,
            );
          }
          final metadata = metadataRead.metadata!;
          cancellationToken.throwIfCancelled();

          final title = metadata.title.isNotEmpty
              ? metadata.title
              : _fallbackTitle(file);
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
            relativePath: file.url,
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
          if (artworkKey != null && !artworkFileLooksValid(artworkKey)) {
            artworkKey = null;
          }
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

          final trackId =
              movedFrom?.id ??
              existing?.id ??
              _stableId('track:$sourceId:${file.url}');
          tracks.add(
            LibraryTrackRecord(
              id: trackId,
              sourceId: sourceId,
              albumId: albumId,
              artistId: artistId,
              relativePath: file.url,
              mediaUri: file.url,
              title: title,
              artistName: artistName,
              albumTitle: albumTitle,
              durationMs: metadata.duration.inMilliseconds,
              trackNumber: metadata.trackNumber,
              discNumber: metadata.discNumber,
              year: metadata.year,
              genre: metadata.genre.isNotEmpty ? metadata.genre : null,
              contentType: file.contentType,
              fileSize: file.contentLength >= 0 ? file.contentLength : null,
              modifiedAt: file.modifiedAt?.toUtc() ?? completedAt,
              artworkKey: artworkKey,
            ),
          );

          if (metadata.lyrics.isNotEmpty) {
            lyrics.addAll(parseEmbeddedLyrics(trackId, metadata.lyrics));
          }
          if (movedFrom != null) {
            movedTracks++;
          } else if (existing != null) {
            modifiedTracks++;
          } else {
            addedTracks++;
          }
        } catch (error) {
          if (error is ScanCancelledException) rethrow;
          warnings.add('${_fallbackTitle(file)}：${_conciseScanError(error)}');
        }
      }
    } finally {
      httpClient.close(force: true);
    }

    cancellationToken.throwIfCancelled();
    if (files.isNotEmpty && tracks.isEmpty && warnings.isNotEmpty) {
      throw StateError(
        '发现 ${files.length} 个受支持的音频文件，但全部无法建立索引。'
        '首个错误：${warnings.first}',
      );
    }
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

    final referencedArtistIds = <String>{
      ...tracks.map((track) => track.artistId).whereType<String>(),
      ...resolvedAlbums.map((album) => album.artistId).whereType<String>(),
    };
    final resolvedArtists = artists.values
        .where((artist) => referencedArtistIds.contains(artist.id))
        .toList(growable: false);
    cancellationToken.throwIfCancelled();
    return _WebDavBatchBuild(
      batch: LibraryScanBatch(
        sourceId: sourceId,
        completedAt: completedAt,
        artists: resolvedArtists,
        albums: resolvedAlbums,
        tracks: tracks,
        lyrics: lyrics,
      ),
      addedTracks: addedTracks,
      modifiedTracks: modifiedTracks,
      movedTracks: movedTracks,
      removedTracks: missingTracks.length - movedTracks,
      unchangedTracks: unchangedTracks,
      warnings: List.unmodifiable(warnings),
    );
  }

  Future<_RemoteMetadata> _readRemoteMetadata(
    _RemoteAudioFile file, {
    required WebDavCredentials credentials,
    required HttpClient httpClient,
  }) async {
    final uri = Uri.parse(file.url);
    final tempFile = File(
      '${Directory.systemTemp.path}/sound_webdav_scan_'
      '${DateTime.now().microsecondsSinceEpoch}_${file.url.hashCode}.tmp',
    );
    try {
      // Progressive header sizes. Tags often fit in 256 KiB, but FLAC covers
      // around 1–2 MB (e.g. 1280² PNG) sit in a trailing PICTURE block and
      // need a larger prefix. Keep expanding while tags are usable but art is
      // still missing so we do not stop at the first successful tag-only pass.
      final headerSizes = file.extension == '.flac'
          ? const <int>[256 * 1024, 512 * 1024, 1536 * 1024, 3 * 1024 * 1024]
          : const <int>[256 * 1024, 512 * 1024, 1536 * 1024];
      _RemoteMetadata? parsed;
      for (final headerSize in headerSizes) {
        final attempt = await _tryParseHeader(
          httpClient,
          uri,
          credentials,
          headerSize,
          tempFile,
        );
        if (attempt == null) continue;
        parsed = attempt;
        final hasTags = _hasUsableRemoteTags(attempt);
        // Extractor already drops zero-padded/truncated art; treat null as
        // "need a larger prefix" rather than "file has no cover".
        final hasArt = attempt.artworkBytes != null &&
            attempt.artworkBytes!.isNotEmpty;
        if (hasTags && hasArt) break;
        if (hasTags && headerSize == headerSizes.last) break;
        if (hasTags && !hasArt) continue;
      }
      // Discovery already established that this is a supported audio path.
      // Metadata is optional: truncated range reads, large embedded artwork,
      // or tail-positioned MP4 atoms must not make an otherwise playable
      // track disappear from the library.
      //
      // Tag/artwork separation lives in [AudioMetadataExtractor] /
      // [extractAudioFileMetadata]: a partial Range that still holds Vorbis
      // (or ID3) comments should yield title/artist/album even when a large
      // PICTURE block cannot be loaded. Filename-only is the last resort.
      return parsed ?? _filenameOnlyRemoteMetadata;
    } finally {
      try {
        await tempFile.delete();
      } catch (_) {}
    }
  }

  Future<_RemoteMetadata?> _tryParseHeader(
    HttpClient client,
    Uri uri,
    WebDavCredentials credentials,
    int headerSize,
    File tempFile,
  ) async {
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
      if (bytes.isEmpty) return null;
      if (hasAppleMetadataHeader(bytes)) {
        throw const _RejectedRemoteAudioException();
      }

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
    } on _RejectedRemoteAudioException {
      rethrow;
    } catch (_) {
      return null;
    }
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

  String _fallbackTitle(_RemoteAudioFile file) {
    final displayName = file.displayName.trim();
    if (displayName.isNotEmpty) {
      final title = p.basenameWithoutExtension(displayName).trim();
      if (title.isNotEmpty) return title;
    }

    final uri = Uri.parse(file.url);
    final fileName = uri.pathSegments.isEmpty
        ? uri.path
        : uri.pathSegments.last;
    return p.basenameWithoutExtension(fileName);
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

Map<String, LibraryTrackRecord> _matchMovedTracks(
  List<LibraryTrackRecord> missingTracks,
  List<_RemoteAudioFile> newFiles,
) {
  final oldByFingerprint = <_RemoteFileFingerprint, List<LibraryTrackRecord>>{};
  for (final track in missingTracks) {
    final fingerprint = _trackFingerprint(track);
    if (fingerprint == null) continue;
    oldByFingerprint.putIfAbsent(fingerprint, () => []).add(track);
  }
  final newByFingerprint = <_RemoteFileFingerprint, List<_RemoteAudioFile>>{};
  for (final file in newFiles) {
    final fingerprint = _remoteFingerprint(file);
    if (fingerprint == null) continue;
    newByFingerprint.putIfAbsent(fingerprint, () => []).add(file);
  }

  final matches = <String, LibraryTrackRecord>{};
  for (final entry in newByFingerprint.entries) {
    final oldCandidates = oldByFingerprint[entry.key];
    if (entry.value.length != 1 || oldCandidates?.length != 1) continue;
    matches[entry.value.single.url] = oldCandidates!.single;
  }
  return matches;
}

bool _sameRemoteFingerprint(LibraryTrackRecord track, _RemoteAudioFile file) {
  final oldFingerprint = _trackFingerprint(track);
  final currentFingerprint = _remoteFingerprint(file);
  return oldFingerprint != null && oldFingerprint == currentFingerprint;
}

/// Same recovery rule as local scans: re-read 未知 identity rows, missing art,
/// and cached art files that fail a lightweight completeness check.
bool _shouldReuseRemoteTrack(
  LibraryTrackRecord track,
  _RemoteAudioFile file,
) {
  if (!_sameRemoteFingerprint(track, file)) return false;
  if (track.artistName == '未知艺人' && track.albumTitle == '未知专辑') {
    return false;
  }
  if (track.artworkKey == null) return false;
  if (!artworkFileLooksValid(track.artworkKey)) return false;
  return true;
}

LibraryTrackRecord _reuseRemoteTrack(
  LibraryTrackRecord track,
  _RemoteAudioFile file,
) {
  return LibraryTrackRecord(
    id: track.id,
    sourceId: track.sourceId,
    albumId: track.albumId,
    artistId: track.artistId,
    relativePath: file.url,
    mediaUri: file.url,
    title: track.title,
    artistName: track.artistName,
    albumTitle: track.albumTitle,
    durationMs: track.durationMs,
    trackNumber: track.trackNumber,
    discNumber: track.discNumber,
    year: track.year,
    genre: track.genre,
    contentType: track.contentType,
    fileSize: file.contentLength,
    modifiedAt: file.modifiedAt!.toUtc(),
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
  LibrarySourceRecord existing, {
  required DateTime occurredAt,
}) {
  final restoredStatus = existing.status == LibrarySourceStatus.scanning
      ? (existing.scanRevision > 0
            ? LibrarySourceStatus.available
            : LibrarySourceStatus.idle)
      : existing.status;
  return LibrarySourceRecord(
    id: existing.id,
    type: LibrarySourceType.webDav,
    displayName: existing.displayName,
    rootUri: existing.rootUri,
    status: restoredStatus,
    scanRevision: existing.scanRevision,
    permissionBookmark: existing.permissionBookmark,
    lastScanStartedAt: existing.lastScanStartedAt,
    lastScanCompletedAt: existing.lastScanCompletedAt,
    lastError: existing.lastError,
    createdAt: existing.createdAt,
    updatedAt: occurredAt.toUtc(),
  );
}

_RemoteFileFingerprint? _trackFingerprint(LibraryTrackRecord track) {
  final size = track.fileSize;
  if (size == null) return null;
  return _RemoteFileFingerprint(size, track.modifiedAt.toUtc());
}

_RemoteFileFingerprint? _remoteFingerprint(_RemoteAudioFile file) {
  final modifiedAt = file.modifiedAt;
  if (file.contentLength < 0 || modifiedAt == null) return null;
  return _RemoteFileFingerprint(file.contentLength, modifiedAt.toUtc());
}

class _RemoteAudioFile {
  const _RemoteAudioFile({
    required this.url,
    required this.displayName,
    required this.contentType,
    required this.extension,
    required this.contentLength,
    required this.modifiedAt,
  });

  final String url;
  final String displayName;
  final String contentType;
  final String extension;
  final int contentLength;
  final DateTime? modifiedAt;
}

class _RemoteMetadataReadResult {
  const _RemoteMetadataReadResult.success(this.metadata)
    : error = null,
      stackTrace = null,
      rejected = false;

  const _RemoteMetadataReadResult.failure(this.error, this.stackTrace)
    : metadata = null,
      rejected = false;

  const _RemoteMetadataReadResult.rejected()
    : metadata = null,
      error = null,
      stackTrace = null,
      rejected = true;

  final _RemoteMetadata? metadata;
  final Object? error;
  final StackTrace? stackTrace;
  final bool rejected;
}

class _RejectedRemoteAudioException implements Exception {
  const _RejectedRemoteAudioException();
}

class _RemoteFileFingerprint {
  const _RemoteFileFingerprint(this.size, this.modifiedAt);

  final int size;
  final DateTime modifiedAt;

  @override
  bool operator ==(Object other) {
    return other is _RemoteFileFingerprint &&
        other.size == size &&
        other.modifiedAt == modifiedAt;
  }

  @override
  int get hashCode => Object.hash(size, modifiedAt);
}

class _WebDavBatchBuild {
  const _WebDavBatchBuild({
    required this.batch,
    required this.addedTracks,
    required this.modifiedTracks,
    required this.movedTracks,
    required this.removedTracks,
    required this.unchangedTracks,
    required this.warnings,
  });

  final LibraryScanBatch batch;
  final int addedTracks;
  final int modifiedTracks;
  final int movedTracks;
  final int removedTracks;
  final int unchangedTracks;
  final List<String> warnings;
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

const _filenameOnlyRemoteMetadata = _RemoteMetadata(
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

bool _hasUsableRemoteTags(_RemoteMetadata metadata) {
  return metadata.title.isNotEmpty ||
      metadata.artist.isNotEmpty ||
      metadata.album.isNotEmpty;
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

String _conciseScanError(Object error) {
  final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= 240) return text;
  return '${text.substring(0, 237)}...';
}
