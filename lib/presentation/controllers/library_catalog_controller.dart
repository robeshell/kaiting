import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/library_models.dart';
import '../../library/library_records.dart';
import '../../library/library_repository.dart';

enum LibraryCatalogStatus { loading, ready, error }

class LibraryCatalogController extends ChangeNotifier {
  LibraryCatalogController({
    required this.repository,
    this.webDavAuthHeaders = const {},
  }) {
    _subscription = repository.watchTracks().listen(
      (_) => unawaited(refresh()),
      onError: (Object error, StackTrace stackTrace) {
        _status = LibraryCatalogStatus.error;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  final LibraryRepository repository;

  /// Map of connection base URL → http auth headers for WebDAV tracks.
  /// Populated by [AppShell] from the credential store.
  Map<String, Map<String, String>> webDavAuthHeaders;
  late final StreamSubscription<List<LibraryTrackRecord>> _subscription;
  LibraryCatalogStatus _status = LibraryCatalogStatus.loading;
  String? _errorMessage;
  List<Album> _albums = const [];
  List<Track> _tracks = const [];
  int _refreshGeneration = 0;
  bool _disposed = false;

  LibraryCatalogStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<Album> get albums => _albums;
  List<Track> get tracks => _tracks;

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    try {
      final sources = await repository.getSources();
      final albumRecords = await repository.getAlbums();
      final trackRecords = await repository.getTracks();
      final lyricsByTrackId = await repository.getAllLyrics();
      if (_disposed || generation != _refreshGeneration) return;
      _albums = mapLibraryAlbums(
        sources: sources,
        albums: albumRecords,
        tracks: trackRecords,
        lyricsByTrackId: lyricsByTrackId,
        webDavAuthHeaders: webDavAuthHeaders,
      );
      _tracks = List.unmodifiable([
        for (final album in _albums) ...album.tracks,
      ]);
      _status = LibraryCatalogStatus.ready;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      if (_disposed || generation != _refreshGeneration) return;
      _status = LibraryCatalogStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

List<Album> mapLibraryAlbums({
  required List<LibrarySourceRecord> sources,
  required List<LibraryAlbumRecord> albums,
  required List<LibraryTrackRecord> tracks,
  required Map<String, List<LibraryLyricRecord>> lyricsByTrackId,
  Map<String, Map<String, String>> webDavAuthHeaders = const {},
}) {
  final sourcesById = {for (final source in sources) source.id: source};
  final tracksByAlbumId = <String, List<LibraryTrackRecord>>{};
  for (final track in tracks) {
    final albumId = track.albumId;
    if (albumId == null) continue;
    tracksByAlbumId.putIfAbsent(albumId, () => []).add(track);
  }

  return [
    for (final album in albums)
      if (tracksByAlbumId[album.id] case final albumTracks?
          when albumTracks.isNotEmpty)
        Album(
          id: album.id,
          title: album.title,
          artist: album.albumArtist,
          source: _sourceKind(sourcesById[album.sourceId]?.type),
          palette: albumPaletteForId(album.id),
          year: album.year,
          genre: album.genre,
          artworkUri: album.artworkKey,
          tracks: [
            for (final track in albumTracks)
              Track(
                id: track.id,
                title: track.title,
                artist: track.artistName,
                albumTitle: track.albumTitle,
                duration: Duration(milliseconds: track.durationMs),
                source: _sourceKind(sourcesById[track.sourceId]?.type),
                trackNumber: track.trackNumber,
                discNumber: track.discNumber,
                lyrics: [
                  for (final lyric in lyricsByTrackId[track.id] ?? const [])
                    LyricLine(
                      Duration(milliseconds: lyric.timestampMs),
                      lyric.text,
                    ),
                ],
                mediaUri: track.mediaUri,
                httpHeaders: _resolveWebDavHeaders(
                  track.mediaUri,
                  webDavAuthHeaders,
                ),
                artworkUri: track.artworkKey ?? album.artworkKey,
                year: track.year ?? album.year,
                genre: track.genre ?? album.genre,
              ),
          ],
        ),
  ];
}

Map<String, String> _resolveWebDavHeaders(
  String mediaUri,
  Map<String, Map<String, String>> authHeaders,
) {
  if (authHeaders.isEmpty) return const {};
  // Match the longest connection base URL that is a prefix of the media URI.
  String? bestKey;
  for (final key in authHeaders.keys) {
    if (mediaUri.startsWith(key)) {
      if (bestKey == null || key.length > bestKey.length) {
        bestKey = key;
      }
    }
  }
  return bestKey != null ? authHeaders[bestKey]! : const {};
}

SourceKind _sourceKind(LibrarySourceType? type) {
  return type == LibrarySourceType.webDav
      ? SourceKind.webDav
      : SourceKind.local;
}
