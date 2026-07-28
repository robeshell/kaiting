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
    expect(lead.featuredTracks, isEmpty);
    expect(guest.albums, [album]);
    expect(guest.tracks, [duetTrack]);
    expect(guest.featuredTracks, isEmpty);
  });

  test('artist browsing splits multi-credit strings into people', () {
    const solo = Track(
      id: 'solo',
      title: 'Solo',
      artist: '周杰伦',
      albumTitle: '叶惠美',
      duration: Duration(minutes: 4),
      source: SourceKind.local,
    );
    const feat = Track(
      id: 'feat',
      title: 'Coral Sea',
      artist: '周杰伦 feat. Lara',
      albumTitle: '叶惠美',
      duration: Duration(minutes: 4),
      source: SourceKind.local,
    );
    const duet = Track(
      id: 'duet',
      title: '千里之外',
      artist: '周杰伦 / 费玉清',
      albumTitle: '依然范特西',
      duration: Duration(minutes: 4),
      source: SourceKind.local,
    );
    const albumA = Album(
      id: 'a',
      title: '叶惠美',
      artist: '周杰伦',
      source: SourceKind.local,
      palette: [Colors.indigo, Colors.black],
      tracks: [solo, feat],
    );
    const albumB = Album(
      id: 'b',
      title: '依然范特西',
      artist: '周杰伦',
      source: SourceKind.local,
      palette: [Colors.teal, Colors.black],
      tracks: [duet],
    );

    final artists = buildArtistCollections(const [albumA, albumB]);
    final titles = artists.map((item) => item.title).toSet();
    expect(titles, containsAll(['周杰伦', 'Lara', '费玉清']));
    expect(titles, isNot(contains('周杰伦 feat. Lara')));
    expect(titles, isNot(contains('周杰伦 / 费玉清')));

    final jay = artists.singleWhere((item) => item.title == '周杰伦');
    final lara = artists.singleWhere((item) => item.title == 'Lara');
    final fei = artists.singleWhere((item) => item.title == '费玉清');

    expect(jay.tracks.map((t) => t.id), containsAll(['solo', 'feat', 'duet']));
    expect(jay.featuredTracks, isEmpty);
    expect(lara.tracks.map((t) => t.id), ['feat']);
    expect(lara.featuredTracks.map((t) => t.id), ['feat']);
    expect(fei.tracks.map((t) => t.id), ['duet']);
    expect(fei.featuredTracks.map((t) => t.id), ['duet']);

    expect(
      findArtistCollection(const [albumA, albumB], '周杰伦 feat. Lara')?.title,
      '周杰伦',
    );
  });

  test('splitArtistCredit handles common delimiters', () {
    expect(splitArtistCredit('A feat. B'), ['A', 'B']);
    expect(splitArtistCredit('A & B / C'), ['A', 'B', 'C']);
    expect(splitArtistCredit('甲、乙'), ['甲', '乙']);
    expect(splitArtistCredit('  solo  '), ['solo']);
  });

  test('artist avatar prefers monogram for featured-only people', () {
    const track = Track(
      id: 'feat',
      title: 'Duet',
      artist: '主唱 feat. 嘉宾',
      albumTitle: '主唱专辑',
      duration: Duration(minutes: 3),
      source: SourceKind.local,
    );
    const album = Album(
      id: 'album',
      title: '主唱专辑',
      artist: '主唱',
      source: SourceKind.local,
      palette: [Colors.blue, Colors.black],
      tracks: [track],
      artworkUri: 'file:///cover.jpg',
    );

    final artists = buildArtistCollections(const [album]);
    final lead = artists.singleWhere((item) => item.title == '主唱');
    final guest = artists.singleWhere((item) => item.title == '嘉宾');

    expect(lead.prefersMonogramAvatar, isFalse);
    expect(lead.representativeAlbum?.id, 'album');
    expect(guest.prefersMonogramAvatar, isTrue);
    expect(guest.representativeAlbum, isNull);
    expect(guest.monogram, '嘉');
    expect(artistMonogram('Jay'), 'J');
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
      inInclusiveRange(200, 280),
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
      inInclusiveRange(148, 176),
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
