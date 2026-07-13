import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/library_models.dart';
import 'library_catalog_controller.dart';

enum LibrarySearchStatus { idle, searching, ready, error }

enum LibrarySearchField { all, title, album, trackArtist, albumArtist, genre }

extension LibrarySearchFieldLabel on LibrarySearchField {
  String get label => switch (this) {
    LibrarySearchField.all => '全部',
    LibrarySearchField.title => '歌曲',
    LibrarySearchField.album => '专辑',
    LibrarySearchField.trackArtist => '歌曲艺人',
    LibrarySearchField.albumArtist => '专辑艺人',
    LibrarySearchField.genre => '流派',
  };
}

enum LibrarySearchSort { relevance, title, artist, album }

extension LibrarySearchSortLabel on LibrarySearchSort {
  String get label => switch (this) {
    LibrarySearchSort.relevance => '相关度',
    LibrarySearchSort.title => '歌曲名',
    LibrarySearchSort.artist => '艺人',
    LibrarySearchSort.album => '专辑名',
  };
}

class LibrarySearchDocument {
  LibrarySearchDocument({
    required this.trackId,
    required String title,
    required String trackArtist,
    required String albumTitle,
    required String albumArtist,
    required String genre,
  }) : normalizedTitle = _normalized(title),
       normalizedTrackArtist = _normalized(trackArtist),
       normalizedAlbumTitle = _normalized(albumTitle),
       normalizedAlbumArtist = _normalized(albumArtist),
       normalizedGenre = _normalized(genre);

  final String trackId;
  final String normalizedTitle;
  final String normalizedTrackArtist;
  final String normalizedAlbumTitle;
  final String normalizedAlbumArtist;
  final String normalizedGenre;
}

class LibrarySearchRequest {
  const LibrarySearchRequest({
    required this.documents,
    required this.query,
    required this.field,
    required this.sort,
    this.limit = 200,
  });

  final List<LibrarySearchDocument> documents;
  final String query;
  final LibrarySearchField field;
  final LibrarySearchSort sort;
  final int limit;
}

class LibrarySearchHit {
  const LibrarySearchHit({required this.track, required this.album});

  final Track track;
  final Album album;
}

typedef LibrarySearchRunner =
    Future<List<String>> Function(LibrarySearchRequest request);

class LibrarySearchController extends ChangeNotifier {
  LibrarySearchController({
    required this.catalog,
    this.debounce = const Duration(milliseconds: 180),
    LibrarySearchRunner? runner,
  }) : _runner = runner ?? _runSearchOffMainIsolate {
    _refreshDocuments();
    catalog.addListener(_handleCatalogChanged);
  }

  final LibraryCatalogController catalog;
  final Duration debounce;
  final LibrarySearchRunner _runner;

  LibrarySearchStatus _status = LibrarySearchStatus.idle;
  String _query = '';
  LibrarySearchField _field = LibrarySearchField.all;
  LibrarySearchSort _sort = LibrarySearchSort.relevance;
  List<LibrarySearchHit> _hits = const [];
  List<LibrarySearchDocument> _documents = const [];
  Map<String, LibrarySearchHit> _hitsByTrackId = const {};
  List<Album>? _catalogAlbums;
  Timer? _timer;
  int _generation = 0;
  String? _errorMessage;
  bool _disposed = false;

  LibrarySearchStatus get status => _status;
  String get query => _query;
  LibrarySearchField get field => _field;
  LibrarySearchSort get sort => _sort;
  List<LibrarySearchHit> get hits => _hits;
  String? get errorMessage => _errorMessage;

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    _scheduleSearch();
  }

  void clear() => setQuery('');

  void setField(LibrarySearchField value) {
    if (_field == value) return;
    _field = value;
    _scheduleSearch();
  }

  void setSort(LibrarySearchSort value) {
    if (_sort == value) return;
    _sort = value;
    _scheduleSearch();
  }

  void _handleCatalogChanged() {
    if (identical(_catalogAlbums, catalog.albums)) return;
    _refreshDocuments();
    if (_query.trim().isNotEmpty) _scheduleSearch();
  }

  void _refreshDocuments() {
    final albums = catalog.albums;
    _catalogAlbums = albums;
    final documents = <LibrarySearchDocument>[];
    final hits = <String, LibrarySearchHit>{};
    for (final album in albums) {
      for (final track in album.tracks) {
        documents.add(
          LibrarySearchDocument(
            trackId: track.id,
            title: track.title,
            trackArtist: track.artist,
            albumTitle: album.title,
            albumArtist: album.artist,
            genre: track.genre ?? album.genre ?? '',
          ),
        );
        hits[track.id] = LibrarySearchHit(track: track, album: album);
      }
    }
    _documents = List.unmodifiable(documents);
    _hitsByTrackId = Map.unmodifiable(hits);
  }

  void _scheduleSearch() {
    _timer?.cancel();
    final generation = ++_generation;
    if (_query.trim().isEmpty) {
      _status = LibrarySearchStatus.idle;
      _hits = const [];
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _status = LibrarySearchStatus.searching;
    _errorMessage = null;
    notifyListeners();
    _timer = Timer(debounce, () => unawaited(_search(generation)));
  }

  Future<void> _search(int generation) async {
    try {
      final ids = await _runner(
        LibrarySearchRequest(
          documents: _documents,
          query: _query,
          field: _field,
          sort: _sort,
        ),
      );
      if (_disposed || generation != _generation) return;
      _hits = List.unmodifiable([for (final id in ids) ?_hitsByTrackId[id]]);
      _status = LibrarySearchStatus.ready;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _hits = const [];
      _status = LibrarySearchStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    catalog.removeListener(_handleCatalogChanged);
    super.dispose();
  }
}

Future<List<String>> _runSearchOffMainIsolate(LibrarySearchRequest request) {
  return compute(
    searchLibraryDocuments,
    request,
    debugLabel: 'sound-library-search',
  );
}

List<String> searchLibraryDocuments(LibrarySearchRequest request) {
  final normalizedQuery = _normalized(request.query);
  if (normalizedQuery.isEmpty || request.limit <= 0) return const [];
  final terms = normalizedQuery.split(' ');
  final matches = <({LibrarySearchDocument document, int relevance})>[];

  for (final document in request.documents) {
    final matchesEveryTerm = terms.every(
      (term) => _documentContains(document, request.field, term),
    );
    if (!matchesEveryTerm) continue;
    matches.add((document: document, relevance: _relevance(document, terms)));
  }

  matches.sort((left, right) {
    final byPrimary = switch (request.sort) {
      LibrarySearchSort.relevance => left.relevance.compareTo(right.relevance),
      LibrarySearchSort.title => _compareText(
        left.document.normalizedTitle,
        right.document.normalizedTitle,
      ),
      LibrarySearchSort.artist => _compareText(
        left.document.normalizedTrackArtist,
        right.document.normalizedTrackArtist,
      ),
      LibrarySearchSort.album => _compareText(
        left.document.normalizedAlbumTitle,
        right.document.normalizedAlbumTitle,
      ),
    };
    if (byPrimary != 0) return byPrimary;
    final byTitle = _compareText(
      left.document.normalizedTitle,
      right.document.normalizedTitle,
    );
    if (byTitle != 0) return byTitle;
    return left.document.trackId.compareTo(right.document.trackId);
  });

  return [
    for (final match in matches.take(request.limit)) match.document.trackId,
  ];
}

bool _documentContains(
  LibrarySearchDocument document,
  LibrarySearchField field,
  String term,
) {
  return switch (field) {
    LibrarySearchField.all =>
      document.normalizedTitle.contains(term) ||
          document.normalizedAlbumTitle.contains(term) ||
          document.normalizedTrackArtist.contains(term) ||
          document.normalizedAlbumArtist.contains(term) ||
          document.normalizedGenre.contains(term),
    LibrarySearchField.title => document.normalizedTitle.contains(term),
    LibrarySearchField.album => document.normalizedAlbumTitle.contains(term),
    LibrarySearchField.trackArtist => document.normalizedTrackArtist.contains(
      term,
    ),
    LibrarySearchField.albumArtist => document.normalizedAlbumArtist.contains(
      term,
    ),
    LibrarySearchField.genre => document.normalizedGenre.contains(term),
  };
}

int _relevance(LibrarySearchDocument document, List<String> terms) {
  final query = terms.join(' ');
  final rankedValues = [
    (value: document.normalizedTitle, weight: 0),
    (value: document.normalizedTrackArtist, weight: 10),
    (value: document.normalizedAlbumTitle, weight: 20),
    (value: document.normalizedAlbumArtist, weight: 30),
    (value: document.normalizedGenre, weight: 40),
  ];
  var score = 100;
  for (final ranked in rankedValues) {
    final value = ranked.value;
    final candidate = value == query
        ? ranked.weight
        : value.startsWith(query)
        ? ranked.weight + 1
        : value.contains(query)
        ? ranked.weight + 2
        : 100;
    if (candidate < score) score = candidate;
  }
  return score;
}

int _compareText(String left, String right) {
  return left.compareTo(right);
}

String _normalized(String value) {
  return value.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
}
