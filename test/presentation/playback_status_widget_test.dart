import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/now_playing_style.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/playback_engine.dart';
import 'package:kaiting/presentation/screens/now_playing_screen.dart';
import 'package:kaiting/presentation/widgets/mini_player.dart';
import 'package:kaiting/presentation/widgets/playback_visual_state.dart';
import 'package:kaiting/presentation/widgets/progress_scrubber.dart';
import 'package:kaiting/presentation/widgets/sound_components.dart';

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

  testWidgets('mini player shares one transport style across form factors', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = StaticPlaybackEngine(
      _snapshot(PlaybackPhase.paused, track: _track),
    );
    final playback = SoundPlaybackController(engine: engine);

    Future<void> pumpMiniPlayer({
      required double width,
      required bool compact,
      required bool docked,
      required bool embedded,
    }) async {
      tester.view.physicalSize = Size(width, 160);
      await tester.pumpWidget(
        MaterialApp(
          theme: SoundTheme.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MiniPlayer(
                playback: playback,
                compact: compact,
                docked: docked,
                embedded: embedded,
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final toggle = find.byKey(const ValueKey('mini-player-playback-toggle'));
      final toggleButton = tester.widget<IconButton>(
        find.descendant(of: toggle, matching: find.byType(IconButton)),
      );
      final toggleIconFinder = find.descendant(
        of: toggle,
        matching: find.byType(Icon),
      );
      final toggleIcon = tester.widget<Icon>(toggleIconFinder);
      expect(toggleIcon.icon, KaitingIcons.playMini);
      expect(toggleIcon.size, compact ? 24 : 28);
      expect(toggleIcon.color, SoundColors.accent.withValues(alpha: 0.96));
      expect(
        toggleButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      final nextIconFinder = find.byIcon(KaitingIcons.nextMini);
      expect(nextIconFinder, findsOneWidget);
      expect(tester.widget<Icon>(nextIconFinder).size, compact ? 20 : 23);
      if (compact) {
        expect(
          tester.getCenter(nextIconFinder).dx -
              tester.getCenter(toggleIconFinder).dx,
          greaterThan(44),
        );
      }
    }

    // Desktop dock: full previous / play / next group.
    await pumpMiniPlayer(
      width: 1200,
      compact: false,
      docked: true,
      embedded: false,
    );
    expect(find.byIcon(KaitingIcons.previousMini), findsOneWidget);
    expect(tester.widget<Text>(find.text(_track.title)).style?.fontSize, 16);

    // Phone: preserve metadata space; play and next remain.
    await pumpMiniPlayer(
      width: 390,
      compact: true,
      docked: false,
      embedded: true,
    );
    expect(find.byIcon(KaitingIcons.previousMini), findsNothing);
    expect(tester.widget<Text>(find.text(_track.title)).style?.fontSize, 13);

    // Open foldable: restore previous and expose the queue action.
    await pumpMiniPlayer(
      width: 720,
      compact: false,
      docked: false,
      embedded: true,
    );
    expect(find.byIcon(KaitingIcons.previousMini), findsOneWidget);
    expect(find.byTooltip('打开播放队列'), findsOneWidget);
    expect(tester.getSize(find.byType(MiniPlayer)).height, 70);
    expect(tester.widget<Text>(find.text(_track.title)).style?.fontSize, 15);
    expect(
      tester
          .widget<Text>(find.text('${_track.artist} — ${_track.albumTitle}'))
          .style
          ?.fontSize,
      12,
    );
    expect(
      tester
          .widget<Padding>(
            find.byKey(const ValueKey('mini-player-condensed-content-padding')),
          )
          .padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('foldable now-playing shares margins across player styles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = StaticPlaybackEngine(
      _snapshot(PlaybackPhase.paused, track: _track),
    );
    final playback = SoundPlaybackController(engine: engine);

    Future<Rect> pumpStyle(NowPlayingStyle style) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SoundTheme.light,
          home: NowPlayingScreen(playback: playback, style: style),
        ),
      );
      await tester.pump();
      final content = tester.widget<Padding>(
        find.byKey(const ValueKey('wide-now-playing-content')),
      );
      expect(content.padding, const EdgeInsets.fromLTRB(24, 0, 24, 24));
      final lyrics = tester.widget<Padding>(
        find.byKey(const ValueKey('wide-now-playing-lyrics')),
      );
      expect(lyrics.padding, const EdgeInsets.fromLTRB(16, 6, 0, 24));
      final player = tester.widget<Padding>(
        find.byKey(const ValueKey('wide-now-playing-player-padding')),
      );
      expect(player.padding, const EdgeInsets.fromLTRB(12, 18, 12, 0));
      return tester.getRect(
        find.byKey(const ValueKey('now-playing-track-title')),
      );
    }

    final classicTitle = await pumpStyle(NowPlayingStyle.classic);
    final vinylTitle = await pumpStyle(NowPlayingStyle.vinyl);
    expect(vinylTitle.left, closeTo(classicTitle.left, 0.5));
    expect(vinylTitle.right, closeTo(classicTitle.right, 0.5));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('mini player progress is read-only', (tester) async {
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
    final scrubber = tester.widget<ProgressScrubber>(progress);
    expect(scrubber.interactive, isFalse);
    expect(scrubber.position, const Duration(seconds: 24));
    expect(scrubber.duration, const Duration(minutes: 3));
    expect(
      find.descendant(of: progress, matching: find.byType(Slider)),
      findsNothing,
    );
    expect(engine.seekPositions, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('volume popup stays bounded and does not block nearby actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = StaticPlaybackEngine(
      _snapshot(PlaybackPhase.paused, track: _track),
    );
    final playback = SoundPlaybackController(engine: engine);
    var queueOpenCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.dark,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MiniPlayer(
              playback: playback,
              compact: false,
              docked: true,
              onOpen: () {},
              onOpenQueue: () => queueOpenCount++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final volumeButton = find.byKey(
      const ValueKey('mini-player-volume-button'),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(volumeButton));
    addTearDown(mouse.removePointer);
    await tester.pump();

    final popup = find.byKey(const ValueKey('mini-player-volume-popup'));
    expect(popup, findsOneWidget);
    expect(tester.getSize(popup), const Size(44, 132));

    await tester.tap(find.byTooltip('打开播放队列'));
    await tester.pump();
    expect(queueOpenCount, 1);

    await tester.tap(volumeButton);
    await tester.pump();
    expect(engine.volume, 0);

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('mini-player-volume-slider')),
    );
    slider.onChanged!(0.65);
    await tester.pump();
    expect(engine.volume, closeTo(0.65, 0.001));

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
    expect(
      find.byKey(const ValueKey('now-playing-background-static')),
      findsOneWidget,
    );
    expect(find.text(_longTrack.title), findsNWidgets(2));
    expect(find.text('封面'), findsNothing);
    final playerTop = tester
        .getRect(find.byKey(const ValueKey('wide-now-playing-player')))
        .top;
    final lyricsTop = tester
        .getRect(find.byKey(const ValueKey('wide-now-playing-lyrics')))
        .top;
    expect((playerTop - lyricsTop).abs(), lessThan(12));
    final contentPadding = tester.widget<Padding>(
      find.byKey(const ValueKey('wide-now-playing-content')),
    );
    expect(contentPadding.padding, const EdgeInsets.fromLTRB(44, 0, 44, 24));
    final lyricsPadding = tester.widget<Padding>(
      find.byKey(const ValueKey('wide-now-playing-lyrics')),
    );
    expect(lyricsPadding.padding, const EdgeInsets.fromLTRB(8, 6, 0, 32));
    expect(
      tester.getTopLeft(find.text(_longTrack.title).first).dy,
      lessThan(430),
      reason: 'Desktop content should not be vertically centered downward.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('wide now-playing stays grouped on an ultra-wide display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2560, 1440);
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
        home: NowPlayingScreen(
          playback: playback,
          style: NowPlayingStyle.vinyl,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final stage = tester.getRect(
      find.byKey(const ValueKey('wide-now-playing-stage')),
    );
    final lyrics = tester.getRect(
      find.byKey(const ValueKey('wide-now-playing-lyrics')),
    );
    expect(stage.size, const Size(1600, 1080));
    expect(stage.center.dx, closeTo(1280, 0.1));
    expect(stage.top, greaterThan(0));
    expect(stage.bottom, lessThan(1440));
    expect(lyrics.right, lessThanOrEqualTo(stage.right - 44));

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('error phase surfaces a retry banner over now playing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = StaticPlaybackEngine(_snapshot(PlaybackPhase.error));
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

    expect(find.text('操作没有完成'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    final failureSurface = tester.widget<SoundGlassSurface>(
      find.byKey(const ValueKey('playback-error-banner')),
    );
    expect(failureSurface.borderColor, isNot(Colors.transparent));
    expect(failureSurface.blur, isTrue);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('playback-error-banner')))
          .height,
      lessThan(100),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    playback.dispose();
    engine.dispose();
  });
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
  double _volume = 1.0;

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
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
  }

  @override
  double get volume => _volume;

  @override
  void dispose() {
    _snapshots.close();
  }
}
