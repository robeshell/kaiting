import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/library/persistence/drift_library_repository.dart';
import 'package:kaiting/library/persistence/library_database.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/playback_engine.dart';
import 'package:kaiting/presentation/controllers/library_catalog_controller.dart';
import 'package:kaiting/presentation/screens/library_screen.dart';
import 'package:kaiting/presentation/widgets/album_cover_flow.dart';
import 'package:kaiting/presentation/widgets/ipod_album_flip_card.dart';

void main() {
  group('coverFlowPlacement', () {
    test('keeps the focused album facing the listener', () {
      final placement = coverFlowPlacement(offset: 0, coverSize: 200);
      expect(placement.translateX, 0);
      expect(placement.rotateY, 0);
      expect(placement.translateZ, 0);
      expect(placement.opacity, 1);
    });

    test('turns right-hand albums inward toward the center', () {
      final first = coverFlowPlacement(offset: 1, coverSize: 200);
      final second = coverFlowPlacement(offset: 2, coverSize: 200);
      expect(first.translateX, greaterThan(0));
      expect(first.rotateY, closeTo(kCoverFlowMaxAngle, 0.001));
      expect(second.translateX, greaterThan(first.translateX));
      // iCarousel clamps rotation: every side cover uses the same angle.
      expect(second.rotateY, closeTo(first.rotateY, 0.001));
      expect(
        second.translateX - first.translateX,
        closeTo(200 * kCoverFlowSpacing, 0.001),
      );
    });

    test('mirrors left-hand albums the other way', () {
      final left = coverFlowPlacement(offset: -1, coverSize: 200);
      final right = coverFlowPlacement(offset: 1, coverSize: 200);
      expect(left.translateX, closeTo(-right.translateX, 0.001));
      expect(left.rotateY, closeTo(-right.rotateY, 0.001));
    });

    test('drops the 3D turn when motion is reduced', () {
      final placement = coverFlowPlacement(
        offset: 2,
        coverSize: 200,
        reduceMotion: true,
      );
      expect(placement.rotateY, 0);
      expect(placement.translateZ, 0);
      expect(placement.translateX, greaterThan(0));
    });

    test('matches the CoverFlow first-slot x/z formula', () {
      final placement = coverFlowPlacement(offset: 1, coverSize: 200);
      expect(placement.translateX, closeTo(116, 0.001));
      expect(placement.translateZ, closeTo(56, 0.001));
      expect(placement.rotateY, closeTo(kCoverFlowMaxAngle, 0.001));
      expect(placement.translateZ, greaterThan(0));
    });

    test('tilts the front cover while dragging', () {
      final settled = coverFlowPlacement(offset: 0, coverSize: 200);
      final dragging = coverFlowPlacement(
        offset: 0,
        coverSize: 200,
        toggle: 0.4,
      );
      expect(settled.rotateY, 0);
      expect(dragging.rotateY, closeTo(-0.4 * kCoverFlowMaxAngle, 0.001));
    });

    test('flipped track list is larger than the cover it sits over', () {
      const coverSize = 200.0;
      final list = coverFlowFlipListSize(
        coverSize: coverSize,
        stageSize: const Size(800, 600),
      );
      expect(list.width, greaterThan(coverSize));
      expect(list.height, greaterThan(coverSize));
      expect(list.width, lessThanOrEqualTo(800));
      expect(list.height, lessThanOrEqualTo(600));
    });

    test(
      'maps a stage tap to the nearest cover, not just a one-step nudge',
      () {
        const coverSize = 200.0;
        const stageWidth = 800.0;
        expect(
          coverFlowIndexAtX(
            localX: 400,
            stageWidth: stageWidth,
            page: 0,
            albumCount: 6,
            coverSize: coverSize,
          ),
          0,
        );
        final first =
            400 +
            coverFlowPlacement(offset: 1, coverSize: coverSize).translateX;
        final third =
            400 +
            coverFlowPlacement(offset: 3, coverSize: coverSize).translateX;
        expect(
          coverFlowIndexAtX(
            localX: first,
            stageWidth: stageWidth,
            page: 0,
            albumCount: 6,
            coverSize: coverSize,
          ),
          1,
        );
        expect(
          coverFlowIndexAtX(
            localX: third,
            stageWidth: stageWidth,
            page: 0,
            albumCount: 6,
            coverSize: coverSize,
          ),
          3,
        );
      },
    );
  });

  group('AlbumCoverFlowPage', () {
    testWidgets('shows the focused album and plays it on tap', (tester) async {
      final albums = [_album('a', 'Night Drive'), _album('b', 'Dawn Chorus')];
      Track? played;
      await tester.pumpWidget(
        _coverFlowApp(
          albums: albums,
          onPlayTrack: (track, _) => played = track,
        ),
      );
      await _openCoverFlow(tester);

      expect(find.byKey(const ValueKey('album-cover-flow')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cover-flow-caption-a')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('album-cover-flow-play')), findsNothing);
      expect(
        find.byKey(const ValueKey('cover-flow-mini-player')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('album-cover-flow-info')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('album-cover-flow-info')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ipod-track-track:a')));
      await tester.pumpAndSettle();
      expect(played?.id, 'track:a');
      expect(find.byKey(const ValueKey('album-cover-flow')), findsNothing);
    });

    testWidgets('tapping the center cover flips to the track list', (
      tester,
    ) async {
      Track? played;
      await tester.pumpWidget(
        _coverFlowApp(
          albums: [_album('a', 'Night Drive'), _album('b', 'Dawn Chorus')],
          onPlayTrack: (track, _) => played = track,
        ),
      );
      await _openCoverFlow(tester);

      await tester.tap(find.byKey(const ValueKey('album-cover-flow-stage')));
      await tester.pumpAndSettle();
      expect(played, isNull);
      expect(find.byKey(const ValueKey('album-cover-flow')), findsOneWidget);
      expect(find.byKey(const ValueKey('ipod-flip-back-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('ipod-track-track:a')), findsOneWidget);
      expect(find.text('Song Night Drive'), findsOneWidget);

      final stage = tester.getRect(
        find.byKey(const ValueKey('album-cover-flow-stage')),
      );
      final coverSize = coverFlowCoverSize(
        stageSize: stage.size,
        landscape: stage.size.aspectRatio > 1.15,
      );
      final list = tester.getSize(
        find.byKey(const ValueKey('ipod-flip-back-a')),
      );
      expect(list.width, greaterThan(coverSize));
      expect(list.height, greaterThan(coverSize));
    });

    testWidgets('info button flips to the track list', (tester) async {
      await tester.pumpWidget(
        _coverFlowApp(
          albums: [_album('a', 'Night Drive'), _album('b', 'Dawn Chorus')],
        ),
      );
      await _openCoverFlow(tester);

      await tester.tap(find.byKey(const ValueKey('album-cover-flow-info')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ipod-flip-back-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('album-cover-flow')), findsOneWidget);
    });

    testWidgets('flip back returns to Cover Flow', (tester) async {
      await tester.pumpWidget(
        _coverFlowApp(albums: [_album('a', 'Night Drive')]),
      );
      await _openCoverFlow(tester);

      await tester.tap(find.byKey(const ValueKey('album-cover-flow-info')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ipod-flip-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ipod-flip-back-a')), findsNothing);
      expect(
        find.byKey(const ValueKey('cover-flow-caption-a')),
        findsOneWidget,
      );
    });

    testWidgets('tapping a flipped track opens iPod now playing', (
      tester,
    ) async {
      final engine = _FakePlaybackEngine();
      final playback = SoundPlaybackController(engine: engine);
      addTearDown(playback.dispose);
      addTearDown(engine.dispose);

      Track? played;
      await tester.pumpWidget(
        _coverFlowApp(
          albums: [
            _album(
              'a',
              'Night Drive',
              extraTracks: [
                Track(
                  id: 'track:a2',
                  title: 'Second Gear',
                  artist: 'Test Artist',
                  albumTitle: 'Night Drive',
                  duration: const Duration(minutes: 4),
                  source: SourceKind.local,
                  mediaUri: 'file:///test/a2.flac',
                ),
              ],
            ),
          ],
          playback: playback,
          onPlayTrack: (track, queue) {
            played = track;
            unawaited(playback.playTrack(track, queue: queue));
          },
        ),
      );
      await _openCoverFlow(tester);

      await tester.tap(find.byKey(const ValueKey('album-cover-flow-stage')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ipod-track-track:a2')));
      await tester.pumpAndSettle();

      expect(played?.id, 'track:a2');
      expect(find.byKey(const ValueKey('ipod-now-playing')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ipod-now-playing-art-a')),
        findsOneWidget,
      );
      expect(find.text('正在播放'), findsOneWidget);
      expect(find.text('Second Gear'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('ipod-now-playing-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ipod-now-playing')), findsNothing);
      expect(find.byKey(const ValueKey('ipod-flip-back-a')), findsOneWidget);
    });

    testWidgets('mini player appears after leaving now playing', (
      tester,
    ) async {
      final engine = _FakePlaybackEngine();
      final playback = SoundPlaybackController(engine: engine);
      addTearDown(playback.dispose);
      addTearDown(engine.dispose);

      await tester.pumpWidget(
        _coverFlowApp(
          albums: [_album('a', 'Night Drive')],
          playback: playback,
          onPlayTrack: (track, queue) {
            unawaited(playback.playTrack(track, queue: queue));
          },
        ),
      );
      await _openCoverFlow(tester);

      expect(
        find.byKey(const ValueKey('cover-flow-mini-player')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('album-cover-flow-info')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ipod-track-track:a')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ipod-now-playing')), findsOneWidget);
      expect(find.byKey(const ValueKey('album-cover-flow')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cover-flow-mini-player')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('ipod-now-playing-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ipod-flip-back-a')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cover-flow-mini-player')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('album-cover-flow-play')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('cover-flow-mini-art')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ipod-now-playing')), findsOneWidget);
    });

    testWidgets('now playing cover follows the current album', (tester) async {
      final engine = _FakePlaybackEngine();
      final playback = SoundPlaybackController(engine: engine);
      addTearDown(playback.dispose);
      addTearDown(engine.dispose);

      await tester.pumpWidget(
        _coverFlowApp(
          albums: [_album('a', 'Night Drive'), _album('b', 'Dawn Chorus')],
          playback: playback,
          onPlayTrack: (track, queue) {
            unawaited(playback.playTrack(track, queue: queue));
          },
        ),
      );
      await _openCoverFlow(tester);

      await tester.tap(find.byKey(const ValueKey('album-cover-flow-info')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ipod-track-track:a')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ipod-now-playing-art-a')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('ipod-now-playing-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ipod-flip-back')));
      await tester.pumpAndSettle();

      final stage = tester.getRect(
        find.byKey(const ValueKey('album-cover-flow-stage')),
      );
      final coverSize = coverFlowCoverSize(
        stageSize: stage.size,
        landscape: stage.size.aspectRatio > 1.15,
      );
      final targetX =
          stage.left +
          stage.width / 2 +
          coverFlowPlacement(offset: 1, coverSize: coverSize).translateX;
      await tester.tapAt(Offset(targetX, stage.center.dy));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('album-cover-flow-info')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ipod-track-track:b')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ipod-now-playing-art-b')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ipod-now-playing-art-a')),
        findsNothing,
      );
      expect(find.text('Song Dawn Chorus'), findsWidgets);
    });

    testWidgets('tapping a side cover scrolls to that album', (tester) async {
      await tester.pumpWidget(
        _coverFlowApp(
          albums: [
            _album('a', 'Night Drive'),
            _album('b', 'Dawn Chorus'),
            _album('c', 'Evening Walk'),
            _album('d', 'Winter Light'),
          ],
        ),
      );
      await _openCoverFlow(tester);

      final stage = tester.getRect(
        find.byKey(const ValueKey('album-cover-flow-stage')),
      );
      final coverSize = coverFlowCoverSize(
        stageSize: stage.size,
        landscape: stage.size.aspectRatio > 1.15,
      );
      final targetX =
          stage.left +
          stage.width / 2 +
          coverFlowPlacement(offset: 2, coverSize: coverSize).translateX;
      await tester.tapAt(Offset(targetX, stage.center.dy));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cover-flow-caption-a')), findsNothing);
      expect(
        find.byKey(const ValueKey('cover-flow-caption-c')),
        findsOneWidget,
      );
    });

    testWidgets('swipes to the next album', (tester) async {
      await tester.pumpWidget(
        _coverFlowApp(
          albums: [
            _album('a', 'Night Drive'),
            _album('b', 'Dawn Chorus'),
            _album('c', 'Evening Walk'),
          ],
        ),
      );
      await _openCoverFlow(tester);
      expect(
        find.byKey(const ValueKey('cover-flow-caption-a')),
        findsOneWidget,
      );

      final stage = tester.getRect(
        find.byKey(const ValueKey('album-cover-flow-stage')),
      );
      final coverSize = coverFlowCoverSize(
        stageSize: stage.size,
        landscape: stage.size.aspectRatio > 1.15,
      );
      final dragUnit = coverFlowPlacement(
        offset: 1,
        coverSize: coverSize,
      ).translateX;
      await tester.drag(
        find.byKey(const ValueKey('album-cover-flow-stage')),
        Offset(-dragUnit, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('cover-flow-caption-b')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('cover-flow-caption-a')), findsNothing);
    });

    testWidgets('arrow keys move between albums and escape closes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _coverFlowApp(
          albums: [_album('a', 'Night Drive'), _album('b', 'Dawn Chorus')],
        ),
      );
      await _openCoverFlow(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cover-flow-caption-b')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('album-cover-flow')), findsNothing);
    });

    testWidgets('close button pops the route', (tester) async {
      await tester.pumpWidget(
        _coverFlowApp(albums: [_album('a', 'Night Drive')]),
      );
      await _openCoverFlow(tester);

      await tester.tap(find.byKey(const ValueKey('album-cover-flow-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('album-cover-flow')), findsNothing);
    });

    testWidgets('keeps chrome and caption clear of system insets', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(
        top: 59,
        bottom: 34,
        left: 0,
        right: 0,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        _coverFlowApp(albums: [_album('a', 'Night Drive')]),
      );
      await _openCoverFlow(tester);

      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('album-cover-flow-close')))
            .dy,
        greaterThanOrEqualTo(59),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('album-cover-flow-stage')))
            .dx,
        greaterThanOrEqualTo(12),
      );
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('album-cover-flow-info')))
            .dy,
        lessThanOrEqualTo(844 - 34),
      );
    });

    testWidgets('fits the cover stack into a short landscape window', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(
        left: 59,
        right: 59,
        top: 0,
        bottom: 21,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        _coverFlowApp(
          albums: [_album('a', 'Night Drive'), _album('b', 'Dawn Chorus')],
        ),
      );
      await _openCoverFlow(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('album-cover-flow')), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('album-cover-flow-close')))
            .dx,
        greaterThanOrEqualTo(59),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('album-cover-flow-stage')))
            .dx,
        greaterThanOrEqualTo(59),
      );
    });

    testWidgets('long-pressing the center cover opens the focused album', (
      tester,
    ) async {
      Album? opened;
      await tester.pumpWidget(
        _coverFlowApp(
          albums: [_album('a', 'Night Drive'), _album('b', 'Dawn Chorus')],
          onOpenAlbum: (album) => opened = album,
        ),
      );
      await _openCoverFlow(tester);

      await tester.longPress(
        find.byKey(const ValueKey('album-cover-flow-stage')),
      );
      await tester.pumpAndSettle();

      expect(opened?.id, 'a');
      expect(find.byKey(const ValueKey('album-cover-flow')), findsNothing);
    });
  });

  test('formatIpodDuration pads seconds', () {
    expect(formatIpodDuration(Duration.zero), '0:00');
    expect(formatIpodDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
  });

  testWidgets('showAlbumCoverFlow does nothing when the library is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showAlbumCoverFlow(
                context,
                albums: const [],
                onPlayTrack: (_, _) {},
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.byKey(const ValueKey('album-cover-flow')), findsNothing);
  });

  testWidgets('long-pressing a library album card opens Cover Flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 0.85;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final repository = await _repositoryWithAlbums();
    addTearDown(repository.close);
    final snapshot = await loadLibraryCatalogSnapshot(repository);
    final catalog = LibraryCatalogController(
      repository: repository,
      initialSnapshot: snapshot,
    );
    addTearDown(catalog.dispose);

    Album? played;
    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.dark,
        home: Scaffold(
          body: LibraryScreen(
            catalog: catalog,
            mode: LibraryBrowseMode.albums,
            onModeChanged: (_) {},
            onOpenAlbum: (_) {},
            onOpenCollection: (_) {},
            onPlayTrack: (track, queue) {
              played = catalog.albums.firstWhere(
                (album) => album.tracks.any((item) => item.id == track.id),
              );
            },
            onManageSources: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('library-album-card-album:night')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('album-cover-flow')), findsOneWidget);
    expect(find.text('Night Drive'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('album-cover-flow-info')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ipod-track-track:night')));
    await tester.pumpAndSettle();
    expect(played?.id, 'album:night');
  });
}

Future<void> _openCoverFlow(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Widget _coverFlowApp({
  required List<Album> albums,
  void Function(Track track, List<Track> queue)? onPlayTrack,
  ValueChanged<Album>? onOpenAlbum,
  SoundPlaybackController? playback,
  int initialIndex = 0,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: TextButton(
            onPressed: () {
              showAlbumCoverFlow(
                context,
                albums: albums,
                initialIndex: initialIndex,
                onPlayTrack: onPlayTrack ?? (_, _) {},
                playback: playback,
                onOpenAlbum: onOpenAlbum,
              );
            },
            child: const Text('open'),
          ),
        );
      },
    ),
  );
}

Album _album(String id, String title, {List<Track> extraTracks = const []}) {
  return Album(
    id: id,
    title: title,
    artist: 'Test Artist',
    source: SourceKind.local,
    palette: const [Color(0xFF334155), Color(0xFF0F172A)],
    tracks: [
      Track(
        id: 'track:$id',
        title: 'Song $title',
        artist: 'Test Artist',
        albumTitle: title,
        duration: const Duration(minutes: 3),
        source: SourceKind.local,
        mediaUri: 'file:///test/$id.flac',
      ),
      ...extraTracks,
    ],
  );
}

class _FakePlaybackEngine implements PlaybackEngine {
  final _controller = StreamController<PlaybackSnapshot>.broadcast(sync: true);
  PlaybackSnapshot _current = const PlaybackSnapshot.idle();

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _controller.stream;

  void _emit(PlaybackSnapshot snapshot) {
    _current = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
  }

  @override
  Future<void> load(Track track, {required int sessionId}) async {
    _emit(
      PlaybackSnapshot(
        sessionId: sessionId,
        phase: PlaybackPhase.ready,
        position: Duration.zero,
        duration: track.duration,
        track: track,
      ),
    );
  }

  @override
  Future<void> play() async {
    _emit(_current.copyWith(phase: PlaybackPhase.playing, playWhenReady: true));
  }

  @override
  Future<void> pause() async {
    _emit(_current.copyWith(phase: PlaybackPhase.paused, playWhenReady: false));
  }

  @override
  Future<void> seek(Duration position) async {
    _emit(_current.copyWith(position: position));
  }

  @override
  Future<void> stop() async {
    _emit(const PlaybackSnapshot.idle());
  }

  @override
  Future<void> setVolume(double value) async {}

  @override
  double get volume => 1.0;

  @override
  void dispose() {
    _controller.close();
  }
}

Future<DriftLibraryRepository> _repositoryWithAlbums() async {
  final repository = DriftLibraryRepository(
    LibraryDatabase(NativeDatabase.memory()),
  );
  final now = DateTime.utc(2026, 8, 14);
  const sourceId = 'local:test';
  await repository.upsertSource(
    LibrarySourceRecord(
      id: sourceId,
      type: LibrarySourceType.local,
      displayName: 'Test Music',
      rootUri: 'file:///test/',
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
          id: 'artist:test',
          sourceId: sourceId,
          name: 'Test Artist',
          sortName: 'test artist',
        ),
      ],
      albums: const [
        LibraryAlbumRecord(
          id: 'album:night',
          sourceId: sourceId,
          title: 'Night Drive',
          sortTitle: 'night drive',
          albumArtist: 'Test Artist',
          artistId: 'artist:test',
          year: 2024,
        ),
        LibraryAlbumRecord(
          id: 'album:dawn',
          sourceId: sourceId,
          title: 'Dawn Chorus',
          sortTitle: 'dawn chorus',
          albumArtist: 'Test Artist',
          artistId: 'artist:test',
          year: 2025,
        ),
      ],
      tracks: [
        LibraryTrackRecord(
          id: 'track:night',
          sourceId: sourceId,
          albumId: 'album:night',
          artistId: 'artist:test',
          relativePath: 'night.flac',
          mediaUri: 'file:///test/night.flac',
          title: 'Midnight',
          artistName: 'Test Artist',
          albumTitle: 'Night Drive',
          durationMs: const Duration(minutes: 3).inMilliseconds,
          trackNumber: 1,
          modifiedAt: now,
        ),
        LibraryTrackRecord(
          id: 'track:dawn',
          sourceId: sourceId,
          albumId: 'album:dawn',
          artistId: 'artist:test',
          relativePath: 'dawn.flac',
          mediaUri: 'file:///test/dawn.flac',
          title: 'Sunrise',
          artistName: 'Test Artist',
          albumTitle: 'Dawn Chorus',
          durationMs: const Duration(minutes: 3).inMilliseconds,
          trackNumber: 1,
          modifiedAt: now,
        ),
      ],
    ),
  );
  return repository;
}
