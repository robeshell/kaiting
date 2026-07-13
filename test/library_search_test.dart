import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/library/library_records.dart';
import 'package:sound_player/library/persistence/drift_library_repository.dart';
import 'package:sound_player/library/persistence/library_database.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/simulated_playback_engine.dart';
import 'package:sound_player/presentation/controllers/library_catalog_controller.dart';
import 'package:sound_player/presentation/controllers/library_search_controller.dart';
import 'package:sound_player/presentation/screens/search_screen.dart';

void main() {
  group('searchLibraryDocuments', () {
    test('matches title, album, artists, genre, and cross-field terms', () {
      final documents = [
        LibrarySearchDocument(
          trackId: 'neon',
          title: 'Neon Sky',
          trackArtist: 'Guest Singer',
          albumTitle: 'Night Drive',
          albumArtist: 'Main Artist',
          genre: 'Ambient Pop',
        ),
        LibrarySearchDocument(
          trackId: 'alpha',
          title: 'Alpha Song',
          trackArtist: 'Another Voice',
          albumTitle: 'Morning Light',
          albumArtist: 'Another Voice',
          genre: 'Rock',
        ),
      ];

      List<String> search(String query, LibrarySearchField field) {
        return searchLibraryDocuments(
          LibrarySearchRequest(
            documents: documents,
            query: query,
            field: field,
            sort: LibrarySearchSort.relevance,
          ),
        );
      }

      expect(search('neon', LibrarySearchField.title), ['neon']);
      expect(search('night', LibrarySearchField.album), ['neon']);
      expect(search('guest', LibrarySearchField.trackArtist), ['neon']);
      expect(search('main', LibrarySearchField.albumArtist), ['neon']);
      expect(search('ambient', LibrarySearchField.genre), ['neon']);
      expect(search('guest night', LibrarySearchField.all), ['neon']);
      expect(search('guest', LibrarySearchField.albumArtist), isEmpty);
    });

    test('applies deterministic sorting and result limits', () {
      final documents = [
        LibrarySearchDocument(
          trackId: 'zulu',
          title: 'Zulu',
          trackArtist: 'Beta',
          albumTitle: 'First Album',
          albumArtist: 'Beta',
          genre: 'Pop',
        ),
        LibrarySearchDocument(
          trackId: 'alpha',
          title: 'Alpha',
          trackArtist: 'Zulu',
          albumTitle: 'Second Album',
          albumArtist: 'Zulu',
          genre: 'Pop',
        ),
      ];

      final byTitle = searchLibraryDocuments(
        LibrarySearchRequest(
          documents: documents,
          query: 'pop',
          field: LibrarySearchField.genre,
          sort: LibrarySearchSort.title,
          limit: 1,
        ),
      );
      final byArtist = searchLibraryDocuments(
        LibrarySearchRequest(
          documents: documents,
          query: 'pop',
          field: LibrarySearchField.genre,
          sort: LibrarySearchSort.artist,
        ),
      );

      expect(byTitle, ['alpha']);
      expect(byArtist, ['zulu', 'alpha']);
    });

    test('searches 10,000 documents through the background worker', () async {
      final documents = List.generate(
        10000,
        (index) => LibrarySearchDocument(
          trackId: 'track-$index',
          title: 'Song $index',
          trackArtist: 'Artist ${index % 50}',
          albumTitle: 'Album ${index % 100}',
          albumArtist: 'Album Artist ${index % 20}',
          genre: index.isEven ? 'Ambient' : 'Rock',
        ),
      );

      final ids = await compute(
        searchLibraryDocuments,
        LibrarySearchRequest(
          documents: documents,
          query: 'ambient',
          field: LibrarySearchField.genre,
          sort: LibrarySearchSort.title,
        ),
      );

      expect(ids, hasLength(200));
      expect(ids.toSet(), hasLength(200));
    });
  });

  group('LibrarySearchController', () {
    late DriftLibraryRepository repository;
    late LibraryCatalogController catalog;

    setUp(() async {
      repository = await _repositoryWithSearchFixture();
      catalog = LibraryCatalogController(repository: repository);
      await catalog.refresh();
    });

    tearDown(() async {
      catalog.dispose();
      await repository.close();
    });

    test('debounces work and ignores a stale result', () async {
      final requests = <LibrarySearchRequest>[];
      final pending = <Completer<List<String>>>[];
      final search = LibrarySearchController(
        catalog: catalog,
        debounce: Duration.zero,
        runner: (request) {
          requests.add(request);
          final completer = Completer<List<String>>();
          pending.add(completer);
          return completer.future;
        },
      );
      addTearDown(search.dispose);

      search.setQuery('neon');
      expect(requests, isEmpty);
      expect(search.status, LibrarySearchStatus.searching);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(requests, hasLength(1));

      search.setQuery('alpha');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(requests, hasLength(2));

      pending[0].complete(['track-neon']);
      await Future<void>.delayed(Duration.zero);
      expect(search.status, LibrarySearchStatus.searching);
      expect(search.hits, isEmpty);

      pending[1].complete(['track-alpha']);
      await Future<void>.delayed(Duration.zero);
      expect(search.status, LibrarySearchStatus.ready);
      expect(search.hits.single.track.id, 'track-alpha');
    });
  });

  testWidgets('search screen filters, plays a result, and opens its album', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithSearchFixture();
    addTearDown(repository.close);
    final catalog = LibraryCatalogController(repository: repository);
    await catalog.refresh();
    final search = LibrarySearchController(
      catalog: catalog,
      debounce: Duration.zero,
      runner: (request) async => searchLibraryDocuments(request),
    );
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    String? openedAlbumId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchScreen(
            catalog: catalog,
            search: search,
            playback: playback,
            onOpenAlbum: (album) => openedAlbumId = album.id,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('library-search-field')),
      'Main Artist',
    );
    await tester.pump();
    await _waitForSearch(tester, search);

    expect(find.text('Neon Sky'), findsOneWidget);
    expect(find.text('Alpha Song'), findsNothing);

    await tester.tap(
      find.widgetWithText(ChoiceChip, LibrarySearchField.albumArtist.label),
    );
    await tester.pump();
    await _waitForSearch(tester, search);
    expect(search.field, LibrarySearchField.albumArtist);
    expect(find.text('Neon Sky'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-result-track-neon')));
    await tester.pump();
    expect(playback.currentTrack?.id, 'track-neon');

    await tester.tap(find.byTooltip('打开专辑 Night Drive'));
    expect(openedAlbumId, 'album-night');

    await playback.clearQueue();
    await tester.pumpWidget(const SizedBox.shrink());
    search.dispose();
    catalog.dispose();
    playback.dispose();
    engine.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> _waitForSearch(
  WidgetTester tester,
  LibrarySearchController search,
) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 1));
    if (search.status != LibrarySearchStatus.searching) return;
  }
  throw TimeoutException('Search did not finish.');
}

Future<DriftLibraryRepository> _repositoryWithSearchFixture() async {
  final repository = DriftLibraryRepository(
    LibraryDatabase(NativeDatabase.memory()),
  );
  final now = DateTime.utc(2026, 7, 13);
  const sourceId = 'local:search';
  await repository.upsertSource(
    LibrarySourceRecord(
      id: sourceId,
      type: LibrarySourceType.local,
      displayName: 'Search Music',
      rootUri: 'file:///search/',
      status: LibrarySourceStatus.available,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.replaceSourceScan(
    LibraryScanBatch(
      sourceId: sourceId,
      completedAt: now,
      artists: const [
        LibraryArtistRecord(
          id: 'artist-main',
          sourceId: sourceId,
          name: 'Main Artist',
          sortName: 'main artist',
        ),
        LibraryArtistRecord(
          id: 'artist-another',
          sourceId: sourceId,
          name: 'Another Voice',
          sortName: 'another voice',
        ),
      ],
      albums: const [
        LibraryAlbumRecord(
          id: 'album-night',
          sourceId: sourceId,
          artistId: 'artist-main',
          title: 'Night Drive',
          sortTitle: 'night drive',
          albumArtist: 'Main Artist',
          genre: 'Ambient Pop',
        ),
        LibraryAlbumRecord(
          id: 'album-morning',
          sourceId: sourceId,
          artistId: 'artist-another',
          title: 'Morning Light',
          sortTitle: 'morning light',
          albumArtist: 'Another Voice',
          genre: 'Rock',
        ),
      ],
      tracks: [
        LibraryTrackRecord(
          id: 'track-neon',
          sourceId: sourceId,
          albumId: 'album-night',
          artistId: 'artist-main',
          relativePath: 'neon.flac',
          mediaUri: 'file:///search/neon.flac',
          title: 'Neon Sky',
          artistName: 'Guest Singer',
          albumTitle: 'Night Drive',
          durationMs: 180000,
          genre: 'Ambient Pop',
          modifiedAt: now,
        ),
        LibraryTrackRecord(
          id: 'track-alpha',
          sourceId: sourceId,
          albumId: 'album-morning',
          artistId: 'artist-another',
          relativePath: 'alpha.flac',
          mediaUri: 'file:///search/alpha.flac',
          title: 'Alpha Song',
          artistName: 'Another Voice',
          albumTitle: 'Morning Light',
          durationMs: 200000,
          genre: 'Rock',
          modifiedAt: now,
        ),
      ],
    ),
  );
  return repository;
}
