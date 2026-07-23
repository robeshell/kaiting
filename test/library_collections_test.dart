import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/playback_mode.dart';
import 'package:kaiting/playback/simulated_playback_engine.dart';
import 'package:kaiting/presentation/screens/library_collection_screen.dart';

void main() {
  test('artist browsing keeps an album together and exposes collaborators', () {
    const leadTrack = Track(
      id: 'lead',
      title: 'Lead Song',
      artist: 'Lead Artist',
      albumTitle: 'Shared Album',
      duration: Duration(minutes: 3),
      source: SourceKind.local,
    );
    const duetTrack = Track(
      id: 'duet',
      title: 'Duet Song',
      artist: 'Guest Artist',
      albumTitle: 'Shared Album',
      duration: Duration(minutes: 4),
      source: SourceKind.local,
    );
    const album = Album(
      id: 'album',
      title: 'Shared Album',
      artist: 'Lead Artist',
      source: SourceKind.local,
      palette: [Colors.indigo, Colors.black],
      tracks: [leadTrack, duetTrack],
    );

    final artists = buildArtistCollections(const [album]);
    final lead = artists.singleWhere(
      (collection) => collection.title == 'Lead Artist',
    );
    final guest = artists.singleWhere(
      (collection) => collection.title == 'Guest Artist',
    );

    expect(lead.albums, [album]);
    expect(lead.tracks, [leadTrack, duetTrack]);
    expect(guest.albums, [album]);
    expect(guest.tracks, [duetTrack]);
  });

  test('genre browsing falls back to album genre and keeps uncategorized', () {
    const inherited = Track(
      id: 'inherited',
      title: 'Inherited Genre',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 3),
      source: SourceKind.local,
    );
    const explicit = Track(
      id: 'explicit',
      title: 'Explicit Genre',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 3),
      source: SourceKind.local,
      genre: 'Jazz',
    );
    const album = Album(
      id: 'album',
      title: 'Album',
      artist: 'Artist',
      genre: 'Rock',
      source: SourceKind.local,
      palette: [Colors.teal, Colors.black],
      tracks: [inherited, explicit],
    );
    const uncategorizedAlbum = Album(
      id: 'unknown',
      title: 'Unknown',
      artist: 'Artist',
      source: SourceKind.webDav,
      palette: [Colors.blueGrey, Colors.black],
      tracks: [
        Track(
          id: 'unknown-track',
          title: 'Unknown',
          artist: 'Artist',
          albumTitle: 'Unknown',
          duration: Duration(minutes: 2),
          source: SourceKind.webDav,
        ),
      ],
    );

    final genres = buildGenreCollections(const [album, uncategorizedAlbum]);
    expect(genres.singleWhere((item) => item.title == 'Rock').tracks, [
      inherited,
    ]);
    expect(genres.singleWhere((item) => item.title == 'Jazz').tracks, [
      explicit,
    ]);
    expect(
      genres.singleWhere((item) => item.title == '未分类').tracks.single.id,
      'unknown-track',
    );
  });

  testWidgets('collection play all follows the visible track sorting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const zulu = Track(
      id: 'zulu',
      title: 'Zulu',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 3),
      source: SourceKind.local,
    );
    const alpha = Track(
      id: 'alpha',
      title: 'Alpha',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 3),
      source: SourceKind.local,
    );
    const album = Album(
      id: 'album',
      title: 'Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: [Colors.indigo, Colors.black],
      tracks: [zulu, alpha],
    );
    const collection = LibraryCollection(
      id: 'artist:artist',
      kind: LibraryCollectionKind.artist,
      title: 'Artist',
      albums: [album],
      tracks: [zulu, alpha],
    );
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        home: LibraryCollectionScreen(
          collection: collection,
          playback: playback,
          onBack: () {},
          onOpenAlbum: (_) {},
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('library-collection-track-sort-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('标题 A–Z'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放全部'));
    await tester.pump();

    expect(playback.queue.map((track) => track.id), ['alpha', 'zulu']);

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('desktop artist hero matches album layout at narrow widths', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(584, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const tracks = [
      Track(
        id: 'first',
        title: 'First',
        artist: 'Artist',
        albumTitle: 'Album',
        duration: Duration(minutes: 3),
        source: SourceKind.local,
      ),
      Track(
        id: 'second',
        title: 'Second',
        artist: 'Artist',
        albumTitle: 'Album',
        duration: Duration(minutes: 4),
        source: SourceKind.local,
      ),
    ];
    const album = Album(
      id: 'album',
      title: 'Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: [Colors.indigo, Colors.black],
      tracks: tracks,
    );
    const collection = LibraryCollection(
      id: 'artist:artist',
      kind: LibraryCollectionKind.artist,
      title: 'Artist',
      albums: [album],
      tracks: tracks,
    );
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        home: LibraryCollectionScreen(
          collection: collection,
          playback: playback,
          onBack: () {},
          onOpenAlbum: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('desktop-artist-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-artist-play')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-artist-shuffle')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('collection-detail-artwork')))
          .width,
      280,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('desktop-artist-play'))).height,
      inInclusiveRange(36, 44),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('desktop-artist-shuffle')));
    await tester.pump();
    expect(playback.playbackMode, PlaybackMode.shuffle);
    expect(
      playback.queue.map((track) => track.id),
      containsAll(['first', 'second']),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    playback.dispose();
    engine.dispose();
  });

  testWidgets('mobile artist is immersive while desktop genre stays compact', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const track = Track(
      id: 'track',
      title: 'Track',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 3),
      source: SourceKind.local,
    );
    const album = Album(
      id: 'album',
      title: 'Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: [Colors.teal, Colors.black],
      tracks: [track],
    );
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    Future<void> pumpCollection(LibraryCollection collection) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryCollectionScreen(
            collection: collection,
            playback: playback,
            onBack: () {},
            onOpenAlbum: (_) {},
          ),
        ),
      );
      await tester.pump();
    }

    await pumpCollection(
      const LibraryCollection(
        id: 'artist:artist',
        kind: LibraryCollectionKind.artist,
        title: 'Artist',
        albums: [album],
        tracks: [track],
      ),
    );
    expect(find.byKey(const ValueKey('desktop-artist-play')), findsNothing);
    expect(
      find.byKey(const ValueKey('artist-detail-background')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mobile-artist-play')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('collection-detail-artwork')))
          .width,
      inInclusiveRange(204, 244),
    );

    tester.view.physicalSize = const Size(1000, 800);
    await pumpCollection(
      const LibraryCollection(
        id: 'genre:rock',
        kind: LibraryCollectionKind.genre,
        title: 'Rock',
        albums: [album],
        tracks: [track],
      ),
    );
    expect(find.byKey(const ValueKey('desktop-artist-play')), findsNothing);
    expect(
      find.byKey(const ValueKey('artist-detail-background')),
      findsNothing,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('collection-detail-artwork')))
          .width,
      220,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    playback.dispose();
    engine.dispose();
  });
}
