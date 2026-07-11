import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/library_models.dart';
import '../../library/library_records.dart';
import '../../library/library_repository.dart';

enum LibraryCatalogStatus { loading, ready, error }

class LibraryCatalogController extends ChangeNotifier {
  LibraryCatalogController({required this.repository}) {
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
  late final StreamSubscription<List<LibraryTrackRecord>> _subscription;
  LibraryCatalogStatus _status = LibraryCatalogStatus.loading;
  String? _errorMessage;
  List<Album> _albums = const [];
  int _refreshGeneration = 0;
  bool _disposed = false;

  LibraryCatalogStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<Album> get albums => _albums;
  List<Track> get tracks => [for (final album in _albums) ...album.tracks];

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    try {
      final sources = await repository.getSources();
      final albumRecords = await repository.getAlbums();
      final trackRecords = await repository.getTracks();
      final lyricEntries = await Future.wait([
        for (final track in trackRecords)
          repository.getLyrics(track.id).then((lyrics) => (track.id, lyrics)),
      ]);
      if (_disposed || generation != _refreshGeneration) return;
      _albums = mapLibraryAlbums(
        sources: sources,
        albums: albumRecords,
        tracks: trackRecords,
        lyricsByTrackId: {for (final entry in lyricEntries) entry.$1: entry.$2},
      );
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
                lyrics: [
                  for (final lyric in lyricsByTrackId[track.id] ?? const [])
                    LyricLine(
                      Duration(milliseconds: lyric.timestampMs),
                      lyric.text,
                    ),
                ],
                mediaUri: track.mediaUri,
                artworkUri: track.artworkKey ?? album.artworkKey,
                year: track.year ?? album.year,
                genre: track.genre ?? album.genre,
              ),
          ],
        ),
  ];
}

SourceKind _sourceKind(LibrarySourceType? type) {
  return type == LibrarySourceType.webDav
      ? SourceKind.webDav
      : SourceKind.local;
}
