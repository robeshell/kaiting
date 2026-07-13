import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/library_models.dart';
import '../../library/library_records.dart';
import '../../library/library_repository.dart';
import 'library_catalog_controller.dart';

class LibraryHistoryItem {
  const LibraryHistoryItem({required this.record, required this.track});

  final LibraryPlayHistoryRecord record;
  final Track track;
}

class LibraryUserStateController extends ChangeNotifier {
  LibraryUserStateController({
    required this.repository,
    required this.catalog,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    catalog.addListener(_catalogChanged);
    _favoriteSubscription = repository.watchFavoriteTracks().listen((records) {
      _favorites = records;
      _favoritesLoaded = true;
      _errorMessage = null;
      notifyListeners();
    }, onError: _handleStreamError);
    _historySubscription = repository.watchPlayHistory().listen((records) {
      _history = records;
      _historyLoaded = true;
      _errorMessage = null;
      notifyListeners();
    }, onError: _handleStreamError);
    _playlistSubscription = repository.watchPlaylists().listen((records) {
      _playlists = records;
      _playlistsLoaded = true;
      _errorMessage = null;
      notifyListeners();
    }, onError: _handleStreamError);
    _playlistTrackSubscription = repository.watchPlaylistTracks().listen((
      records,
    ) {
      _playlistTracks = records;
      _playlistTracksLoaded = true;
      _errorMessage = null;
      notifyListeners();
    }, onError: _handleStreamError);
  }

  final LibraryRepository repository;
  final LibraryCatalogController catalog;
  final DateTime Function() _now;
  late final StreamSubscription<List<LibraryFavoriteTrackRecord>>
  _favoriteSubscription;
  late final StreamSubscription<List<LibraryPlayHistoryRecord>>
  _historySubscription;
  late final StreamSubscription<List<LibraryPlaylistRecord>>
  _playlistSubscription;
  late final StreamSubscription<List<LibraryPlaylistTrackRecord>>
  _playlistTrackSubscription;
  List<LibraryFavoriteTrackRecord> _favorites = const [];
  List<LibraryPlayHistoryRecord> _history = const [];
  List<LibraryPlaylistRecord> _playlists = const [];
  List<LibraryPlaylistTrackRecord> _playlistTracks = const [];
  bool _favoritesLoaded = false;
  bool _historyLoaded = false;
  bool _playlistsLoaded = false;
  bool _playlistTracksLoaded = false;
  String? _errorMessage;
  bool _disposed = false;

  bool get isLoading =>
      !_favoritesLoaded ||
      !_historyLoaded ||
      !_playlistsLoaded ||
      !_playlistTracksLoaded;
  String? get errorMessage => _errorMessage;
  List<LibraryPlaylistRecord> get playlists => List.unmodifiable(_playlists);
  Set<String> get favoriteTrackIds => {
    for (final record in _favorites) record.trackId,
  };

  List<Track> get favoriteTracks {
    final tracksById = _tracksById;
    return List.unmodifiable([
      for (final record in _favorites) ?tracksById[record.trackId],
    ]);
  }

  List<Track> get recentTracks {
    final tracksById = _tracksById;
    final seen = <String>{};
    final recent = <Track>[];
    for (final record in _history) {
      if (!seen.add(record.trackId)) continue;
      final track = tracksById[record.trackId];
      if (track != null) recent.add(track);
    }
    return List.unmodifiable(recent);
  }

  List<LibraryHistoryItem> get historyItems {
    final tracksById = _tracksById;
    final items = <LibraryHistoryItem>[];
    for (final record in _history) {
      final track = tracksById[record.trackId];
      if (track != null) {
        items.add(LibraryHistoryItem(record: record, track: track));
      }
    }
    return List.unmodifiable(items);
  }

  LibraryPlaylistRecord? playlistById(int playlistId) =>
      _playlists.where((playlist) => playlist.id == playlistId).firstOrNull;

  List<Track> tracksForPlaylist(int playlistId) {
    final tracksById = _tracksById;
    return List.unmodifiable([
      for (final entry in _playlistTracks)
        if (entry.playlistId == playlistId) ?tracksById[entry.trackId],
    ]);
  }

  int playlistTrackCount(int playlistId) =>
      _playlistTracks.where((entry) => entry.playlistId == playlistId).length;

  int missingPlaylistTrackCount(int playlistId) {
    final tracksById = _tracksById;
    return _playlistTracks
        .where(
          (entry) =>
              entry.playlistId == playlistId &&
              !tracksById.containsKey(entry.trackId),
        )
        .length;
  }

  bool playlistContainsTrack(int playlistId, String trackId) =>
      _playlistTracks.any(
        (entry) => entry.playlistId == playlistId && entry.trackId == trackId,
      );

  Map<String, Track> get _tracksById => {
    for (final track in catalog.tracks) track.id: track,
  };

  bool isFavorite(String trackId) =>
      _favorites.any((record) => record.trackId == trackId);

  Future<void> toggleFavorite(Track track) async {
    final favorite = !isFavorite(track.id);
    try {
      await repository.setTrackFavorite(
        track.id,
        favorite: favorite,
        changedAt: _now().toUtc(),
      );
    } catch (error, stackTrace) {
      _handleWriteError('更新收藏失败', error, stackTrace);
    }
  }

  Future<void> recordTrackStarted(Track track) async {
    try {
      await repository.addPlayHistory(track.id, playedAt: _now().toUtc());
    } catch (error, stackTrace) {
      _handleWriteError('记录播放历史失败', error, stackTrace);
    }
  }

  Future<void> clearHistory() async {
    try {
      await repository.clearPlayHistory();
    } catch (error, stackTrace) {
      _handleWriteError('清除播放历史失败', error, stackTrace);
    }
  }

  Future<int?> createPlaylist(String name) async {
    try {
      return await repository.createPlaylist(
        name: name,
        createdAt: _now().toUtc(),
      );
    } catch (error, stackTrace) {
      _handleWriteError('新建播放列表失败', error, stackTrace);
      return null;
    }
  }

  Future<bool> renamePlaylist(int playlistId, String name) async {
    try {
      await repository.renamePlaylist(
        playlistId,
        name: name,
        changedAt: _now().toUtc(),
      );
      return true;
    } catch (error, stackTrace) {
      _handleWriteError('重命名播放列表失败', error, stackTrace);
      return false;
    }
  }

  Future<bool> deletePlaylist(int playlistId) async {
    try {
      await repository.deletePlaylist(playlistId);
      return true;
    } catch (error, stackTrace) {
      _handleWriteError('删除播放列表失败', error, stackTrace);
      return false;
    }
  }

  Future<bool> setTrackInPlaylist(
    int playlistId,
    Track track, {
    required bool included,
  }) async {
    try {
      if (included) {
        await repository.addTrackToPlaylist(
          playlistId,
          track.id,
          addedAt: _now().toUtc(),
        );
      } else {
        await repository.removeTrackFromPlaylist(
          playlistId,
          track.id,
          changedAt: _now().toUtc(),
        );
      }
      return true;
    } catch (error, stackTrace) {
      _handleWriteError('更新播放列表失败', error, stackTrace);
      return false;
    }
  }

  Future<bool> reorderPlaylist(
    int playlistId,
    List<Track> orderedAvailableTracks,
  ) async {
    try {
      final visibleIds = orderedAvailableTracks
          .map((track) => track.id)
          .toList();
      final visibleIdSet = visibleIds.toSet();
      final missingIds = [
        for (final entry in _playlistTracks)
          if (entry.playlistId == playlistId &&
              !visibleIdSet.contains(entry.trackId))
            entry.trackId,
      ];
      await repository.reorderPlaylistTracks(playlistId, [
        ...visibleIds,
        ...missingIds,
      ], changedAt: _now().toUtc());
      return true;
    } catch (error, stackTrace) {
      _handleWriteError('调整播放列表顺序失败', error, stackTrace);
      return false;
    }
  }

  void _catalogChanged() {
    if (!_disposed) notifyListeners();
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    _errorMessage = error.toString();
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'library user state',
        context: ErrorDescription(
          'while watching favorites, play history, or playlists',
        ),
      ),
    );
    if (!_disposed) notifyListeners();
  }

  void _handleWriteError(String label, Object error, StackTrace stackTrace) {
    _errorMessage = '$label：$error';
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'library user state',
        context: ErrorDescription(label),
      ),
    );
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    catalog.removeListener(_catalogChanged);
    unawaited(_favoriteSubscription.cancel());
    unawaited(_historySubscription.cancel());
    unawaited(_playlistSubscription.cancel());
    unawaited(_playlistTrackSubscription.cancel());
    super.dispose();
  }
}
