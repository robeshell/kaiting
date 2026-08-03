import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/brand_tokens.g.dart';
import 'package:kaiting/core/now_playing_style.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/library/persistence/drift_library_repository.dart';
import 'package:kaiting/library/persistence/library_database.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/playback_engine.dart';
import 'package:kaiting/presentation/controllers/library_catalog_controller.dart';
import 'package:kaiting/presentation/controllers/library_user_state_controller.dart';
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
    expect(
      miniPlayerSurface.color,
      KaiBrandDeepNightSkin.glassChromeSurface,
    );
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
      expect(toggleIcon.size, compact ? 24 : (docked ? 32 : 28));
      expect(toggleIcon.color, SoundColors.accent.withValues(alpha: 0.96));
      expect(
        toggleButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      final nextIconFinder = find.byIcon(KaitingIcons.nextMini);
      expect(nextIconFinder, findsOneWidget);
      expect(
        tester.widget<Icon>(nextIconFinder).size,
        compact ? 20 : (docked ? 20 : 23),
      );
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
    expect(
      find.byKey(const ValueKey('mini-player-mode-cycle')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mini-player-queue')), findsOneWidget);
    expect(find.byTooltip('打开播放队列'), findsNothing);
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

  testWidgets('docked mini player keeps favorite right beside track identity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = StaticPlaybackEngine(
      _snapshot(PlaybackPhase.paused, track: _track),
    );
    final playback = SoundPlaybackController(engine: engine);
    final repository = DriftLibraryRepository(
      LibraryDatabase(NativeDatabase.memory()),
    );
    addTearDown(repository.close);
    final catalog = LibraryCatalogController(repository: repository);
    final userState = LibraryUserStateController(
      repository: repository,
      catalog: catalog,
    );
    addTearDown(() {
      userState.dispose();
      catalog.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MiniPlayer(
              playback: playback,
              userState: userState,
              compact: false,
              docked: true,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final title = find.text(_track.title);
    final metadata = find.text('${_track.artist} — ${_track.albumTitle}');
    final favorite = find.byTooltip('收藏歌曲');
    expect(title, findsOneWidget);
    expect(metadata, findsOneWidget);
    expect(favorite, findsOneWidget);
    // The identity block shrink-wraps to its widest line (title or artist).
    final blockRight = [
      tester.getRect(title).right,
      tester.getRect(metadata).right,
    ].reduce((a, b) => a > b ? a : b);
    // The icon button has zero padding, so only the small SizedBox gap plus
    // the track-identity side padding may separate text from icon.
    expect(tester.getRect(favorite).left - blockRight, inInclusiveRange(0, 24));

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets(
    'docked mini player scrubber reveals on hover and seeks on drag',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = StaticPlaybackEngine(
        _snapshot(PlaybackPhase.paused, track: _track),
      );
      final playback = SoundPlaybackController(engine: engine);
      final interactions = <bool>[];
      var openCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: SoundTheme.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: NotificationListener<ProgressScrubInteractionNotification>(
                onNotification: (notification) {
                  interactions.add(notification.active);
                  return false;
                },
                child: MiniPlayer(
                  playback: playback,
                  compact: false,
                  docked: true,
                  onOpen: () => openCount++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final scrubber = tester.widget<ProgressScrubber>(
        find.byKey(const ValueKey('mini-player-progress')),
      );
      expect(scrubber.interactive, isTrue);
      expect(scrubber.hoverReveal, isTrue);
      final surface = tester.widget<SoundGlassSurface>(
        find.descendant(
          of: find.byType(MiniPlayer),
          matching: find.byType(SoundGlassSurface),
        ),
      );
      expect(surface.clip, isTrue);

      final band = find.byKey(const ValueKey('progress-scrubber-hit-target'));
      final thumb = find.byKey(const ValueKey('mini-player-scrubber-thumb'));
      bool thumbVisible() => thumb.evaluate().isNotEmpty;
      double visibleTrackHeight() =>
          (tester.widget<CustomPaint>(band).painter as dynamic).trackHeight
              as double;
      double trackTop() =>
          (tester.widget<CustomPaint>(band).painter as dynamic).trackTopForSize(
                tester.getSize(band),
              )
              as double;
      // The dock has no permanent time labels; time appears only as a drag
      // bubble above the top-edge track.
      expect(find.text('0:24'), findsNothing);
      expect(find.text('3:00'), findsNothing);
      expect(thumbVisible(), isFalse);
      expect(visibleTrackHeight(), 3);
      expect(trackTop(), 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await tester.pump();

      // Hovering reveals the thumb, but the time bubble is reserved for an
      // active drag.
      final center = tester.getCenter(band);
      await mouse.moveTo(center);
      await tester.pump();
      expect(find.text('1:30'), findsNothing);
      expect(thumbVisible(), isTrue);
      expect(visibleTrackHeight(), 6);
      expect(trackTop(), 0);
      final bandRect = tester.getRect(band);
      final expectedPlaybackX = bandRect.left + bandRect.width * (24 / 180);
      // Hover only exposes the affordance. It stays on the actual playback
      // position instead of chasing the mouse.
      expect(tester.getCenter(thumb).dx, closeTo(expectedPlaybackX, 0.5));
      expect(tester.getCenter(thumb).dy, closeTo(bandRect.top + 3, 0.5));
      expect(tester.getSize(thumb), const Size.square(14));
      final thumbDecoration =
          tester.widget<Container>(thumb).decoration! as BoxDecoration;
      expect(thumbDecoration.color, Colors.white);
      expect(thumbDecoration.border, isNull);

      // A scrubber tap seeks but must not bubble into the dock's open action.
      await mouse.down(center);
      await tester.pump();
      expect(tester.getCenter(thumb).dx, closeTo(center.dx, 0.5));
      expect(find.text('1:30'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
      final bubble = find.byKey(const ValueKey('mini-player-time-bubble'));
      final bubbleRect = tester.getRect(bubble);
      expect(bubbleRect.width, lessThan(180));
      expect(bubbleRect.height, lessThan(40));
      final bubbleDecoration =
          tester.widget<Container>(bubble).decoration! as BoxDecoration;
      expect(bubbleDecoration.color, SoundGlassTheme.light.strongSurface);
      expect(bubbleDecoration.gradient, isNull);
      expect(bubbleRect.bottom, lessThan(tester.getRect(band).top));
      await mouse.up();
      await tester.pump();
      expect(openCount, 0);
      expect(find.text('1:30'), findsNothing);
      expect(find.text('3:00'), findsNothing);
      // Releasing hides only the drag bubble. Since the pointer is still over
      // the bar, the thicker track and thumb continue to advertise scrubbing.
      expect(thumbVisible(), isTrue);
      expect(visibleTrackHeight(), 6);
      expect(trackTop(), 0);

      // Dragging to 75% updates the floating preview and commits a seek on
      // release.
      await mouse.down(center);
      await tester.pump();
      await mouse.moveTo(Offset(center.dx + 300, center.dy));
      await tester.pump();
      expect(interactions, contains(true));
      expect(find.text('2:15'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
      await mouse.up();
      await tester.pump();
      expect(engine.seekPositions, isNotEmpty);
      expect(engine.seekPositions.last, const Duration(seconds: 135));
      // Releasing the drag hides the preview, but the controller must keep
      // the committed target visible even though this paused test engine does
      // not publish a follow-up position snapshot.
      expect(playback.displayPosition, const Duration(seconds: 135));
      expect(find.text('2:15'), findsNothing);
      expect(find.text('3:00'), findsNothing);
      expect(thumbVisible(), isTrue);

      await mouse.moveTo(const Offset(10, 80));
      await tester.pump();
      expect(thumbVisible(), isFalse);
      expect(visibleTrackHeight(), 3);
      expect(trackTop(), 0);

      await tester.pumpWidget(const SizedBox.shrink());
      playback.dispose();
      engine.dispose();
    },
  );

  testWidgets('mini player progress follows position-only engine ticks', (
    tester,
  ) async {
    final initial = _snapshot(PlaybackPhase.playing, track: _track);
    final engine = StaticPlaybackEngine(initial);
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Scaffold(
          body: MiniPlayer(
            playback: playback,
            compact: false,
            docked: true,
            onOpen: () {},
          ),
        ),
      ),
    );

    ProgressScrubber progress() => tester.widget<ProgressScrubber>(
      find.byKey(const ValueKey('mini-player-progress')),
    );
    expect(progress().position, const Duration(seconds: 24));

    // A normal playback tick is intentionally not a structural controller
    // notification. The mini-player timeline must listen to positionListenable
    // directly or it remains frozen while the song is playing.
    engine.emit(initial.copyWith(position: const Duration(seconds: 45)));
    await tester.pump();

    expect(progress().position, const Duration(seconds: 45));

    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('docked scrub bubble follows the dark theme', (tester) async {
    tester.view.physicalSize = const Size(1200, 160);
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
            alignment: Alignment.bottomCenter,
            child: MiniPlayer(
              playback: playback,
              compact: false,
              docked: true,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final band = find.byKey(const ValueKey('progress-scrubber-hit-target'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(band));
    await mouse.down(tester.getCenter(band));
    await tester.pump();

    final bubble = find.byKey(const ValueKey('mini-player-time-bubble'));
    final decoration =
        tester.widget<Container>(bubble).decoration! as BoxDecoration;
    expect(decoration.color, SoundGlassTheme.dark.strongSurface);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('mini-player-bubble-current-time')),
          )
          .style
          ?.color,
      SoundGlassTheme.dark.primaryText,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('mini-player-bubble-total-time')),
          )
          .style
          ?.color,
      SoundGlassTheme.dark.secondaryText,
    );
    expect(find.text('1:30'), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);

    await mouse.up();
    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('landscape tablet uses wide margins across player styles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = StaticPlaybackEngine(
      _snapshot(PlaybackPhase.paused, track: _track),
    );
    final playback = SoundPlaybackController(engine: engine);

    Future<void> pumpStyle(NowPlayingStyle style) async {
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
      expect(content.padding, const EdgeInsets.fromLTRB(44, 0, 44, 24));
      final lyrics = tester.widget<Padding>(
        find.byKey(const ValueKey('wide-now-playing-lyrics')),
      );
      expect(lyrics.padding, const EdgeInsets.fromLTRB(8, 6, 0, 32));
      final player = tester.widget<Padding>(
        find.byKey(const ValueKey('wide-now-playing-player-padding')),
      );
      expect(player.padding, EdgeInsets.zero);
      expect(find.byKey(const ValueKey('now-playing-track-title')), findsOne);
    }

    await pumpStyle(NowPlayingStyle.classic);
    await pumpStyle(NowPlayingStyle.vinyl);
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

    await tester.tap(find.byKey(const ValueKey('mini-player-queue')));
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
    final failureStatus = tester.widget<SoundInlineStatus>(
      find.byKey(const ValueKey('playback-error-banner')),
    );
    expect(failureStatus.tone, SoundStatusTone.error);
    expect(failureStatus.actionLabel, '重试');
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

  PlaybackSnapshot _current;
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final List<Duration> seekPositions = [];
  double _volume = 1.0;

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  void emit(PlaybackSnapshot snapshot) {
    _current = snapshot;
    _snapshots.add(snapshot);
  }

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
