import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/playback_engine.dart';
import 'package:sound_player/presentation/screens/now_playing_screen.dart';
import 'package:sound_player/presentation/widgets/mini_player.dart';
import 'package:sound_player/presentation/widgets/playback_status_badge.dart';

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
    final engine = StaticPlaybackEngine(_snapshot(PlaybackPhase.paused));
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: MiniPlayer(playback: playback, compact: true, onOpen: () {}),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
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
    testWidgets('mini player and now-playing agree for ${testCase.$1.name}', (
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

      expect(find.text(testCase.$2), findsNWidgets(2));
      if (testCase.$1 == PlaybackPhase.error) {
        expect(find.text('network failed'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      playback.dispose();
      engine.dispose();
    });
  }
}

PlaybackSnapshot _snapshot(PlaybackPhase phase, {bool playWhenReady = false}) {
  return PlaybackSnapshot(
    sessionId: 0,
    phase: phase,
    position: phase == PlaybackPhase.completed
        ? _track.duration
        : const Duration(seconds: 24),
    duration: _track.duration,
    track: _track,
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

class StaticPlaybackEngine implements PlaybackEngine {
  StaticPlaybackEngine(this._current);

  final PlaybackSnapshot _current;
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);

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
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {
    _snapshots.close();
  }
}
