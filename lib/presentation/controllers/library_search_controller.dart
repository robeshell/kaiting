import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pinyin/pinyin.dart';

import '../../domain/library_models.dart';
import 'library_catalog_controller.dart';

enum LibrarySearchStatus { idle, searching, ready, error }

/// Match scope for the track query — not result entity types.
enum LibrarySearchField { all, title, album, trackArtist, albumArtist, genre }

extension LibrarySearchFieldLabel on LibrarySearchField {
  String get label => switch (this) {
    LibrarySearchField.all => '全部',
    LibrarySearchField.title => '歌名',
    LibrarySearchField.album => '专辑名',
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
    required this.albumId,
    required String title,
    required String trackArtist,
    required String albumTitle,
    required String albumArtist,
    required String genre,
  }) : normalizedTitle = _normalized(title),
       normalizedTrackArtist = _normalized(trackArtist),
       normalizedAlbumTitle = _normalized(albumTitle),
       normalizedAlbumArtist = _normalized(albumArtist),
       normalizedGenre = _normalized(genre),
       titlePinyin = _pinyinKey(title),
       titleInitials = _initialsKey(title),
       trackArtistPinyin = _pinyinKey(trackArtist),
       trackArtistInitials = _initialsKey(trackArtist),
       albumTitlePinyin = _pinyinKey(albumTitle),
       albumTitleInitials = _initialsKey(albumTitle),
       albumArtistPinyin = _pinyinKey(albumArtist),
       albumArtistInitials = _initialsKey(albumArtist),
       genrePinyin = _pinyinKey(genre),
       genreInitials = _initialsKey(genre);

  final String trackId;
  final String albumId;
  final String normalizedTitle;
  final String normalizedTrackArtist;
  final String normalizedAlbumTitle;
  final String normalizedAlbumArtist;
  final String normalizedGenre;
  final String titlePinyin;
  final String titleInitials;
  final String trackArtistPinyin;
  final String trackArtistInitials;
  final String albumTitlePinyin;
  final String albumTitleInitials;
  final String albumArtistPinyin;
  final String albumArtistInitials;
  final String genrePinyin;
  final String genreInitials;
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

class LibrarySearchArtistHit {
  const LibrarySearchArtistHit({
    required this.name,
    required this.collection,
    required this.trackCount,
  });

  final String name;
  final LibraryCollection collection;
  final int trackCount;
}

class LibrarySearchAlbumHit {
  const LibrarySearchAlbumHit({required this.album, required this.trackCount});

  final Album album;
  final int trackCount;
}

class LibrarySearchMatchSet {
  const LibrarySearchMatchSet({
    required this.trackIds,
    required this.truncated,
  });

  final List<String> trackIds;
  final bool truncated;
}

typedef LibrarySearchRunner =
    Future<LibrarySearchMatchSet> Function(LibrarySearchRequest request);

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

  static const int resultLimit = 200;
  static const int maxRecentQueries = 8;
  static const int maxEntityHits = 6;

  LibrarySearchStatus _status = LibrarySearchStatus.idle;
  String _query = '';
  LibrarySearchField _field = LibrarySearchField.all;
  LibrarySearchSort _sort = LibrarySearchSort.relevance;
  List<LibrarySearchHit> _hits = const [];
  List<LibrarySearchArtistHit> _artistHits = const [];
  List<LibrarySearchAlbumHit> _albumHits = const [];
  List<LibrarySearchDocument> _documents = const [];
  Map<String, LibrarySearchHit> _hitsByTrackId = const {};
  Map<String, Album> _albumsById = const {};
  List<Album>? _catalogAlbums;
  final List<String> _recentQueries = [];
  bool _truncated = false;
  Timer? _timer;
  int _generation = 0;
  int _documentBuildGeneration = 0;
  String? _errorMessage;
  bool _disposed = false;

  /// Below this size the search index is built on the current isolate so unit
  /// tests and tiny libraries stay synchronous; larger catalogs use [compute].
  static const int _syncDocumentBuildThreshold = 500;

  LibrarySearchStatus get status => _status;
  String get query => _query;
  LibrarySearchField get field => _field;
  LibrarySearchSort get sort => _sort;
  List<LibrarySearchHit> get hits => _hits;
  List<LibrarySearchArtistHit> get artistHits => _artistHits;
  List<LibrarySearchAlbumHit> get albumHits => _albumHits;
  List<String> get recentQueries => List.unmodifiable(_recentQueries);
  bool get truncated => _truncated;
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

  void applyRecentQuery(String value) {
    setQuery(value);
  }

  void _handleCatalogChanged() {
    if (identical(_catalogAlbums, catalog.albums)) return;
    _refreshDocuments();
    if (_query.trim().isNotEmpty) _scheduleSearch();
  }

  void _refreshDocuments() {
    final albums = catalog.albums;
    _catalogAlbums = albums;
    final seeds = <LibrarySearchDocumentSeed>[];
    final hits = <String, LibrarySearchHit>{};
    final albumsById = <String, Album>{};
    for (final album in albums) {
      albumsById[album.id] = album;
      for (final track in album.tracks) {
        seeds.add(
          LibrarySearchDocumentSeed(
            trackId: track.id,
            albumId: album.id,
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
    _hitsByTrackId = Map.unmodifiable(hits);
    _albumsById = Map.unmodifiable(albumsById);

    // Small catalogs: build the pinyin index on the current isolate so search
    // is ready immediately (tests and cold start with empty/tiny libraries).
    // Large catalogs: offload PinyinHelper work so catalog refresh does not
    // freeze the UI for tens of milliseconds.
    final generation = ++_documentBuildGeneration;
    if (seeds.length < _syncDocumentBuildThreshold) {
      _documents = List.unmodifiable(buildLibrarySearchDocuments(seeds));
      return;
    }
    _documents = const [];
    unawaited(_buildDocumentsOffMainIsolate(seeds, generation));
  }

  Future<void> _buildDocumentsOffMainIsolate(
    List<LibrarySearchDocumentSeed> seeds,
    int generation,
  ) async {
    try {
      final documents = await compute(
        buildLibrarySearchDocuments,
        seeds,
        debugLabel: 'sound-library-search-index',
      );
      if (_disposed || generation != _documentBuildGeneration) return;
      _documents = List.unmodifiable(documents);
      if (_query.trim().isNotEmpty) _scheduleSearch();
    } catch (_) {
      if (_disposed || generation != _documentBuildGeneration) return;
      // Fall back to an in-process build so search remains usable if the
      // worker isolate fails to spawn.
      _documents = List.unmodifiable(buildLibrarySearchDocuments(seeds));
      if (_query.trim().isNotEmpty) _scheduleSearch();
    }
  }

  void _scheduleSearch() {
    _timer?.cancel();
    final generation = ++_generation;
    if (_query.trim().isEmpty) {
      _status = LibrarySearchStatus.idle;
      _hits = const [];
      _artistHits = const [];
      _albumHits = const [];
      _truncated = false;
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
      // Large catalogs build the pinyin index off-thread; hold the searching
      // state until documents are ready so we do not flash an empty result set.
      if (_documents.isEmpty &&
          catalog.tracks.isNotEmpty &&
          _query.trim().isNotEmpty) {
        return;
      }
      final matchSet = await _runner(
        LibrarySearchRequest(
          documents: _documents,
          query: _query,
          field: _field,
          sort: _sort,
          limit: resultLimit,
        ),
      );
      if (_disposed || generation != _generation) return;
      final trackHits = <LibrarySearchHit>[
        for (final id in matchSet.trackIds) ?_hitsByTrackId[id],
      ];
      _hits = List.unmodifiable(trackHits);
      _truncated = matchSet.truncated;
      _artistHits = List.unmodifiable(_buildArtistHits(trackHits, _query));
      _albumHits = List.unmodifiable(_buildAlbumHits(trackHits, _query));
      _status = LibrarySearchStatus.ready;
      _errorMessage = null;
      _rememberQuery(_query);
      notifyListeners();
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _hits = const [];
      _artistHits = const [];
      _albumHits = const [];
      _truncated = false;
      _status = LibrarySearchStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  void _rememberQuery(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    _recentQueries.removeWhere(
      (item) => item.toLowerCase() == value.toLowerCase(),
    );
    _recentQueries.insert(0, value);
    if (_recentQueries.length > maxRecentQueries) {
      _recentQueries.removeRange(maxRecentQueries, _recentQueries.length);
    }
  }

  List<LibrarySearchArtistHit> _buildArtistHits(
    List<LibrarySearchHit> trackHits,
    String query,
  ) {
    final albums = catalog.albums;
    final terms = _normalized(query).split(' ').where((t) => t.isNotEmpty);
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final hit in trackHits) {
      for (final name in {hit.track.artist, hit.album.artist}) {
        final cleaned = name.trim();
        if (cleaned.isEmpty) continue;
        if (!_textMatchesAny(cleaned, terms)) continue;
        final key = cleaned.toLowerCase();
        counts[key] = (counts[key] ?? 0) + 1;
        names.putIfAbsent(key, () => cleaned);
      }
    }
    // Also surface pure artist-name matches even if field filter is narrow —
    // when the filter is trackArtist/albumArtist/all and catalogs have them.
    if (_field == LibrarySearchField.all ||
        _field == LibrarySearchField.trackArtist ||
        _field == LibrarySearchField.albumArtist) {
      for (final collection in catalog.artistCollections) {
        if (!_textMatchesAny(collection.title, terms)) continue;
        final key = collection.title.toLowerCase();
        counts.putIfAbsent(key, () => collection.tracks.length);
        names.putIfAbsent(key, () => collection.title);
      }
    }

    final ranked = counts.entries.toList()
      ..sort((left, right) {
        final byCount = right.value.compareTo(left.value);
        if (byCount != 0) return byCount;
        return left.key.compareTo(right.key);
      });

    final results = <LibrarySearchArtistHit>[];
    final artistCollections = catalog.artistCollections;
    for (final entry in ranked) {
      if (results.length >= maxEntityHits) break;
      final name = names[entry.key]!;
      final collection = findArtistCollection(
        albums,
        name,
        collections: artistCollections,
      );
      if (collection == null) continue;
      results.add(
        LibrarySearchArtistHit(
          name: collection.title,
          collection: collection,
          trackCount: entry.value,
        ),
      );
    }
    return results;
  }

  List<LibrarySearchAlbumHit> _buildAlbumHits(
    List<LibrarySearchHit> trackHits,
    String query,
  ) {
    final terms = _normalized(query).split(' ').where((t) => t.isNotEmpty);
    final counts = <String, int>{};
    for (final hit in trackHits) {
      if (!_textMatchesAny(hit.album.title, terms) &&
          !_textMatchesAny(hit.album.artist, terms)) {
        // Still count albums that contributed matches via track title etc.
        // Only promote albums whose *name* matches for the entity strip.
        continue;
      }
      counts[hit.album.id] = (counts[hit.album.id] ?? 0) + 1;
    }
    if (_field == LibrarySearchField.all ||
        _field == LibrarySearchField.album) {
      for (final album in _albumsById.values) {
        if (!_textMatchesAny(album.title, terms)) continue;
        counts.putIfAbsent(album.id, () => album.tracks.length);
      }
    }
    final ranked = counts.entries.toList()
      ..sort((left, right) {
        final byCount = right.value.compareTo(left.value);
        if (byCount != 0) return byCount;
        final leftTitle = _albumsById[left.key]?.title ?? '';
        final rightTitle = _albumsById[right.key]?.title ?? '';
        return leftTitle.toLowerCase().compareTo(rightTitle.toLowerCase());
      });
    final results = <LibrarySearchAlbumHit>[];
    for (final entry in ranked) {
      if (results.length >= maxEntityHits) break;
      final album = _albumsById[entry.key];
      if (album == null) continue;
      results.add(LibrarySearchAlbumHit(album: album, trackCount: entry.value));
    }
    return results;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _documentBuildGeneration++;
    _timer?.cancel();
    catalog.removeListener(_handleCatalogChanged);
    super.dispose();
  }
}

/// Plain-string seed for building [LibrarySearchDocument] off the UI isolate.
class LibrarySearchDocumentSeed {
  const LibrarySearchDocumentSeed({
    required this.trackId,
    required this.albumId,
    required this.title,
    required this.trackArtist,
    required this.albumTitle,
    required this.albumArtist,
    required this.genre,
  });

  final String trackId;
  final String albumId;
  final String title;
  final String trackArtist;
  final String albumTitle;
  final String albumArtist;
  final String genre;
}

/// Top-level entry point for [compute]: runs pinyin normalization off the UI.
List<LibrarySearchDocument> buildLibrarySearchDocuments(
  List<LibrarySearchDocumentSeed> seeds,
) {
  return [
    for (final seed in seeds)
      LibrarySearchDocument(
        trackId: seed.trackId,
        albumId: seed.albumId,
        title: seed.title,
        trackArtist: seed.trackArtist,
        albumTitle: seed.albumTitle,
        albumArtist: seed.albumArtist,
        genre: seed.genre,
      ),
  ];
}

Future<LibrarySearchMatchSet> _runSearchOffMainIsolate(
  LibrarySearchRequest request,
) {
  return compute(
    searchLibraryDocuments,
    request,
    debugLabel: 'sound-library-search',
  );
}

/// Pure search worker (also used directly in tests).
LibrarySearchMatchSet searchLibraryDocuments(LibrarySearchRequest request) {
  final normalizedQuery = _normalized(request.query);
  if (normalizedQuery.isEmpty || request.limit <= 0) {
    return const LibrarySearchMatchSet(trackIds: [], truncated: false);
  }
  final terms = normalizedQuery
      .split(' ')
      .where((term) => term.isNotEmpty)
      .toList(growable: false);
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

  final truncated = matches.length > request.limit;
  return LibrarySearchMatchSet(
    trackIds: [
      for (final match in matches.take(request.limit)) match.document.trackId,
    ],
    truncated: truncated,
  );
}

bool _documentContains(
  LibrarySearchDocument document,
  LibrarySearchField field,
  String term,
) {
  return switch (field) {
    LibrarySearchField.all =>
      _fieldMatches(
            document.normalizedTitle,
            document.titlePinyin,
            document.titleInitials,
            term,
          ) ||
          _fieldMatches(
            document.normalizedAlbumTitle,
            document.albumTitlePinyin,
            document.albumTitleInitials,
            term,
          ) ||
          _fieldMatches(
            document.normalizedTrackArtist,
            document.trackArtistPinyin,
            document.trackArtistInitials,
            term,
          ) ||
          _fieldMatches(
            document.normalizedAlbumArtist,
            document.albumArtistPinyin,
            document.albumArtistInitials,
            term,
          ) ||
          _fieldMatches(
            document.normalizedGenre,
            document.genrePinyin,
            document.genreInitials,
            term,
          ),
    LibrarySearchField.title => _fieldMatches(
      document.normalizedTitle,
      document.titlePinyin,
      document.titleInitials,
      term,
    ),
    LibrarySearchField.album => _fieldMatches(
      document.normalizedAlbumTitle,
      document.albumTitlePinyin,
      document.albumTitleInitials,
      term,
    ),
    LibrarySearchField.trackArtist => _fieldMatches(
      document.normalizedTrackArtist,
      document.trackArtistPinyin,
      document.trackArtistInitials,
      term,
    ),
    LibrarySearchField.albumArtist => _fieldMatches(
      document.normalizedAlbumArtist,
      document.albumArtistPinyin,
      document.albumArtistInitials,
      term,
    ),
    LibrarySearchField.genre => _fieldMatches(
      document.normalizedGenre,
      document.genrePinyin,
      document.genreInitials,
      term,
    ),
  };
}

bool _fieldMatches(
  String normalized,
  String pinyin,
  String initials,
  String term,
) {
  if (normalized.contains(term)) return true;
  if (pinyin.isNotEmpty && pinyin.contains(term)) return true;
  if (initials.isNotEmpty && initials.contains(term)) return true;
  return false;
}

bool _textMatchesAny(String value, Iterable<String> terms) {
  final normalized = _normalized(value);
  final pinyin = _pinyinKey(value);
  final initials = _initialsKey(value);
  for (final term in terms) {
    if (_fieldMatches(normalized, pinyin, initials, term)) return true;
  }
  return false;
}

int _relevance(LibrarySearchDocument document, List<String> terms) {
  final query = terms.join(' ');
  final rankedValues = [
    (
      value: document.normalizedTitle,
      pinyin: document.titlePinyin,
      initials: document.titleInitials,
      weight: 0,
    ),
    (
      value: document.normalizedTrackArtist,
      pinyin: document.trackArtistPinyin,
      initials: document.trackArtistInitials,
      weight: 10,
    ),
    (
      value: document.normalizedAlbumTitle,
      pinyin: document.albumTitlePinyin,
      initials: document.albumTitleInitials,
      weight: 20,
    ),
    (
      value: document.normalizedAlbumArtist,
      pinyin: document.albumArtistPinyin,
      initials: document.albumArtistInitials,
      weight: 30,
    ),
    (
      value: document.normalizedGenre,
      pinyin: document.genrePinyin,
      initials: document.genreInitials,
      weight: 40,
    ),
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
        : ranked.pinyin == query || ranked.initials == query
        ? ranked.weight + 3
        : ranked.pinyin.startsWith(query) || ranked.initials.startsWith(query)
        ? ranked.weight + 4
        : ranked.pinyin.contains(query) || ranked.initials.contains(query)
        ? ranked.weight + 5
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

String _pinyinKey(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return PinyinHelper.getPinyinE(
    trimmed,
    separator: '',
    defPinyin: '',
  ).toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

String _initialsKey(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return PinyinHelper.getShortPinyin(trimmed).toLowerCase();
}
