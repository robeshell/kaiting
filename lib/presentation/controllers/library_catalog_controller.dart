import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/library_models.dart';
import '../../library/library_records.dart';
import '../../library/library_repository.dart';
import '../../library/scanning/embedded_lyrics_parser.dart';

enum LibraryCatalogStatus { loading, ready, error }

@immutable
class LibraryCatalogSnapshot {
  const LibraryCatalogSnapshot({
    required this.sources,
    required this.albums,
    required this.tracks,
    required this.lyricsByTrackId,
  });

  final List<LibrarySourceRecord> sources;
  final List<LibraryAlbumRecord> albums;
  final List<LibraryTrackRecord> tracks;
  final Map<String, List<LibraryLyricRecord>> lyricsByTrackId;
}

Future<LibraryCatalogSnapshot> loadLibraryCatalogSnapshot(
  LibraryRepository repository, {
  List<LibraryTrackRecord>? trackRecords,
}) async {
  // Start every independent read before awaiting any of them. Drift may still
  // serialize SQLite work internally, but this removes four Dart/isolate
  // round-trips from the critical path and avoids rereading watched tracks.
  final sourcesFuture = repository.getSources();
  final albumsFuture = repository.getAlbums();
  final tracksFuture = trackRecords == null
      ? repository.getTracks()
      : Future.value(trackRecords);
  final lyricsFuture = repository.getAllLyrics();
  return LibraryCatalogSnapshot(
    sources: await sourcesFuture,
    albums: await albumsFuture,
    tracks: await tracksFuture,
    lyricsByTrackId: await lyricsFuture,
  );
}

class LibraryCatalogController extends ChangeNotifier {
  LibraryCatalogController({
    required this.repository,
    LibraryCatalogSnapshot? initialSnapshot,
  }) {
    if (initialSnapshot != null) {
      _applySnapshot(initialSnapshot, notify: false);
      _initialTrackSignature = _trackSignature(initialSnapshot.tracks);
    }
    _subscription = repository.watchTracks().listen(
      _handleTrackRecords,
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
  List<Track> _tracks = const [];
  int _refreshGeneration = 0;
  bool _disposed = false;
  String? _initialTrackSignature;

  LibraryCatalogStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<Album> get albums => _albums;
  List<Track> get tracks => _tracks;

  void _handleTrackRecords(List<LibraryTrackRecord> records) {
    final initialSignature = _initialTrackSignature;
    if (initialSignature != null) {
      _initialTrackSignature = null;
      if (initialSignature == _trackSignature(records)) return;
    }
    unawaited(refresh(trackRecords: records));
  }

  Future<void> refresh({List<LibraryTrackRecord>? trackRecords}) async {
    final generation = ++_refreshGeneration;
    try {
      final snapshot = await loadLibraryCatalogSnapshot(
        repository,
        trackRecords: trackRecords,
      );
      if (_disposed || generation != _refreshGeneration) return;
      _applySnapshot(snapshot);
    } catch (error) {
      if (_disposed || generation != _refreshGeneration) return;
      _status = LibraryCatalogStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  void _applySnapshot(LibraryCatalogSnapshot snapshot, {bool notify = true}) {
    _albums = mapLibraryAlbums(
      sources: snapshot.sources,
      albums: snapshot.albums,
      tracks: snapshot.tracks,
      lyricsByTrackId: snapshot.lyricsByTrackId,
    );
    _tracks = List.unmodifiable([for (final album in _albums) ...album.tracks]);
    _status = LibraryCatalogStatus.ready;
    _errorMessage = null;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

String _trackSignature(List<LibraryTrackRecord> tracks) => [
  for (final track in tracks)
    '${track.id}\u0000${track.modifiedAt.microsecondsSinceEpoch}\u0000${track.artworkKey ?? ''}',
].join('\u0001');

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
                discNumber: track.discNumber,
                lyrics: _mapLyrics(
                  track.id,
                  lyricsByTrackId[track.id] ?? const [],
                ),
                mediaUri: track.mediaUri,
                artworkUri: track.artworkKey ?? album.artworkKey,
                year: track.year ?? album.year,
                genre: track.genre ?? album.genre,
              ),
          ],
        ),
  ];
}

List<LyricLine> _mapLyrics(String trackId, List<LibraryLyricRecord> records) =>
    [
      for (final lyric in normalizePersistedLyrics(trackId, records))
        LyricLine(
          lyric.timestampMs == unsynchronizedLyricTimestampMs
              ? null
              : Duration(milliseconds: lyric.timestampMs),
          lyric.text,
        ),
    ];

SourceKind _sourceKind(LibrarySourceType? type) {
  return SourceKind.fromName(type?.name ?? LibrarySourceType.local.name);
}
