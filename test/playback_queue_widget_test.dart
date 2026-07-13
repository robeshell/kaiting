import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/playback_mode.dart';
import 'package:sound_player/playback/simulated_playback_engine.dart';
import 'package:sound_player/presentation/screens/album_detail_screen.dart';
import 'package:sound_player/presentation/screens/now_playing_screen.dart';
import 'package:sound_player/presentation/widgets/playback_queue_sheet.dart';

void main() {
  testWidgets('queue sheet changes mode, removes tracks, and clears queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_first, queue: const [_first, _second, _third]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaybackQueueSheet(playback: playback)),
      ),
    );
    await tester.pump();

    expect(find.text('播放队列'), findsOneWidget);
    expect(find.text('3 首歌 · 列表循环'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);

    await tester.tap(find.text('随机播放'));
    await tester.pump();
    expect(playback.playbackMode, PlaybackMode.shuffle);
    expect(find.text('3 首歌 · 随机播放'), findsOneWidget);

    await tester.tap(find.byTooltip('从队列移除 Third'));
    await tester.pump();
    expect(playback.queue.map((track) => track.id), isNot(contains('third')));
    expect(find.text('Third'), findsNothing);

    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(playback.queue, isEmpty);
    expect(find.text('播放队列是空的'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('now playing exposes real mode controls and queue sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_first, queue: const [_first, _second]);

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(playback: playback)),
    );
    await tester.pump();

    expect(find.byTooltip('播放队列'), findsOneWidget);
    expect(find.byTooltip('列表循环'), findsOneWidget);
    await tester.tap(find.byTooltip('随机播放'));
    await tester.pump();
    expect(playback.playbackMode, PlaybackMode.shuffle);

    await tester.tap(find.byTooltip('播放队列'));
    await tester.pumpAndSettle();
    expect(find.text('播放队列'), findsOneWidget);
    expect(find.textContaining('随机播放'), findsWidgets);

    await playback.clearQueue();
    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('album track menu inserts a song as next', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_first, queue: const [_first, _second]);
    final album = Album(
      id: 'album',
      title: 'Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: albumPaletteForId('album'),
      tracks: const [_first, _second, _third],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlbumDetailScreen(
          album: album,
          playback: playback,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('track-actions-third')),
    );
    await tester.tap(find.byKey(const ValueKey('track-actions-third')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一首播放'));
    await tester.pump();

    expect(playback.queue, [_first, _third, _second]);

    await playback.clearQueue();
    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });
}

const _first = Track(
  id: 'first',
  title: 'First',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 3),
  source: SourceKind.local,
);

const _second = Track(
  id: 'second',
  title: 'Second',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 4),
  source: SourceKind.local,
);

const _third = Track(
  id: 'third',
  title: 'Third',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 5),
  source: SourceKind.webDav,
);
