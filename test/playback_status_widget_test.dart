import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/core/sound_theme.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/playback_engine.dart';
import 'package:sound_player/presentation/screens/now_playing_screen.dart';
import 'package:sound_player/presentation/widgets/mini_player.dart';
import 'package:sound_player/presentation/widgets/playback_status_badge.dart';
import 'package:sound_player/presentation/widgets/sound_components.dart';

void main() {
  test('maps every engine phase to a distinct visual state', () {
    const expected = {
      PlaybackPhase.idle: '等待播放',
      PlaybackPhase.loading: '正在载入',
      PlaybackPhase.ready: '已就绪',
      PlaybackPhase.playing: '正在播放',
      PlaybackPhase.paused: '已暂停',
      PlaybackPhase.buffering: '正在缓冲',
      PlaybackPhase.completed: '播放完成',
      PlaybackPhase.error: '播放错误',
    };

    for (final entry in expected.entries) {
      final state = PlaybackVisualState.fromSnapshot(
        _snapshot(entry.key),
        hasDisplayTrack: true,
      );
      expect(state.label, entry.value);
    }
  });

  test('buffering preserves the requested pause action', () {
    final state = PlaybackVisualState.fromSnapshot(
      _snapshot(PlaybackPhase.buffering, playWhenReady: true),
      hasDisplayTrack: true,
    );

    expect(state.busy, isTrue);
    expect(state.primaryVisual, PlaybackPrimaryVisual.pause);
  });

  testWidgets('compact mini player keeps metadata within a narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 90);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = StaticPlaybackEngine(
      _snapshot(PlaybackPhase.paused, track: _longTrack),
    );
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.dark,
        home: Scaffold(
          body: MiniPlayer(playback: playback, compact: true, onOpen: () {}),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('now-playing-artwork-warmup')),
      findsOneWidget,
    );
    final miniPlayerSurface = tester.widget<SoundGlassSurface>(
      find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.byType(SoundGlassSurface),
      ),
    );
    expect(miniPlayerSurface.color?.a, closeTo(0.80, 0.01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('mini player progress is interactive and seeks playback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = StaticPlaybackEngine(
      _snapshot(PlaybackPhase.paused, track: _track),
    );
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.dark,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: MiniPlayer(
              playback: playback,
              compact: false,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final progress = find.byKey(const ValueKey('mini-player-progress'));
    expect(progress, findsOneWidget);
    final slider = tester.widget<Slider>(
      find.descendant(of: progress, matching: find.byType(Slider)),
    );
    expect(slider.onChanged, isNotNull);
    expect(slider.onChangeEnd, isNotNull);
    slider.onChanged!(slider.max * 0.75);
    slider.onChangeEnd!(slider.max * 0.75);
    await tester.pump();

    expect(engine.seekPositions, hasLength(1));
    expect(engine.seekPositions.single.inSeconds, 135);

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('wide now-playing fits a short desktop window', (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = StaticPlaybackEngine(
      _snapshot(PlaybackPhase.paused, track: _longTrack),
    );
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: NowPlayingScreen(playback: playback),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_longTrack.title), findsOneWidget);
    expect(find.text('封面'), findsNothing);
    final playerTop = tester
        .getRect(find.byKey(const ValueKey('wide-now-playing-player')))
        .top;
    final lyricsTop = tester
        .getRect(find.byKey(const ValueKey('wide-now-playing-lyrics')))
        .top;
    expect((playerTop - lyricsTop).abs(), lessThan(12));
    expect(
      tester.getTopLeft(find.text(_longTrack.title)).dy,
      lessThan(430),
      reason: 'Desktop content should not be vertically centered downward.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  for (final testCase in const [
    (PlaybackPhase.loading, '正在载入'),
    (PlaybackPhase.buffering, '正在缓冲'),
    (PlaybackPhase.paused, '已暂停'),
    (PlaybackPhase.completed, '播放完成'),
    (PlaybackPhase.error, '播放错误'),
  ]) {
    testWidgets('only mini player labels ${testCase.$1.name} status', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = StaticPlaybackEngine(
        _snapshot(
          testCase.$1,
          playWhenReady: testCase.$1 == PlaybackPhase.buffering,
        ),
      );
      final playback = SoundPlaybackController(engine: engine);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 90,
                  child: MiniPlayer(
                    playback: playback,
                    compact: false,
                    onOpen: () {},
                  ),
                ),
                Expanded(child: NowPlayingScreen(playback: playback)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(MiniPlayer),
          matching: find.text(testCase.$2),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(NowPlayingScreen),
          matching: find.text(testCase.$2),
        ),
        findsNothing,
      );
      if (testCase.$1 == PlaybackPhase.error) {
        expect(find.text('操作没有完成'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      playback.dispose();
      engine.dispose();
    });
  }
}

PlaybackSnapshot _snapshot(
  PlaybackPhase phase, {
  bool playWhenReady = false,
  Track track = _track,
}) {
  return PlaybackSnapshot(
    sessionId: 0,
    phase: phase,
    position: phase == PlaybackPhase.completed
        ? track.duration
        : const Duration(seconds: 24),
    duration: track.duration,
    track: track,
    errorMessage: phase == PlaybackPhase.error ? 'network failed' : null,
    playWhenReady: playWhenReady,
  );
}

const _track = Track(
  id: 'status-track',
  title: 'Status Track',
  artist: 'Status Artist',
  albumTitle: 'Status Album',
  duration: Duration(minutes: 3),
  source: SourceKind.local,
  mediaUri: 'file:///status.mp3',
);

const _longTrack = Track(
  id: 'long-status-track',
  title: 'A very long restored track title that must remain compact',
  artist: 'Several collaborating artists with long names',
  albumTitle: 'An unusually long album title for a narrow mini player',
  duration: Duration(minutes: 4),
  source: SourceKind.webDav,
  mediaUri: 'https://example.test/music/long-status.mp3',
);

class StaticPlaybackEngine implements PlaybackEngine {
  StaticPlaybackEngine(this._current);

  final PlaybackSnapshot _current;
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final List<Duration> seekPositions = [];

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> load(Track track, {required int sessionId}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {
    _snapshots.close();
  }
}
