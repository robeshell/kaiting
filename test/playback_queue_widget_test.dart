import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/core/now_playing_style.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/playback_mode.dart';
import 'package:kaiting/playback/simulated_playback_engine.dart';
import 'package:kaiting/presentation/screens/album_detail_screen.dart';
import 'package:kaiting/presentation/screens/now_playing_screen.dart';
import 'package:kaiting/presentation/controllers/offline_download_controller.dart';
import 'package:kaiting/presentation/widgets/playback_queue_sheet.dart';
import 'package:kaiting/presentation/widgets/album_art.dart';
import 'package:kaiting/presentation/widgets/sound_components.dart';

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

    expect(
      tester
          .getSize(find.byKey(const ValueKey('queue-track-row-third')))
          .height,
      64,
    );
    await tester.tap(find.byKey(const ValueKey('queue-track-actions-third')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从队列移除'));
    await tester.pumpAndSettle();
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
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
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
    expect(find.byKey(const ValueKey('now-playing-view-switch')), findsNothing);
    expect(find.byKey(const ValueKey('compact-player')), findsOneWidget);
    expect(
      tester
          .widget<AlbumArt>(
            find.descendant(
              of: find.byKey(const ValueKey('compact-now-playing-artwork')),
              matching: find.byType(AlbumArt),
            ),
          )
          .gaplessPlayback,
      isTrue,
    );

    await playback.next();
    await tester.pump();
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('show-now-playing-lyrics')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('compact-lyrics')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('compact-lyrics-artwork')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('compact-lyrics-playback-controls')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('compact-lyrics-secondary-actions')),
      findsOneWidget,
    );
    expect(find.text('同步歌词'), findsNothing);
    expect(find.byKey(const ValueKey('compact-lyrics-more')), findsOneWidget);
    expect(find.text('Second lyric'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('compact-lyrics-region')))
          .height,
      lessThanOrEqualTo(392),
    );
    await tester.tap(find.byKey(const ValueKey('compact-lyrics-more')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('歌词设置'), findsOneWidget);
    expect(find.text('歌词延后 0.5 秒'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const ValueKey('return-now-playing-cover')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('compact-player')), findsOneWidget);
    await tester.tap(find.byTooltip('随机播放').last);
    await tester.pump();
    expect(playback.playbackMode, PlaybackMode.shuffle);

    await tester.tap(find.byTooltip('播放队列'));
    // The artwork background intentionally animates continuously while music
    // is playing, so waiting for the whole tree to settle would never finish.
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('播放队列'), findsOneWidget);
    expect(find.textContaining('随机播放'), findsWidgets);

    await playback.clearQueue();
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    playback.dispose();
    engine.dispose();
  });

  testWidgets('player styles adapt wide and compact now playing layouts', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_second, queue: const [_second]);

    Future<(double, double)> paneWidths(NowPlayingStyle style) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NowPlayingScreen(playback: playback, style: style),
        ),
      );
      await tester.pump();
      return (
        tester
            .getSize(find.byKey(const ValueKey('wide-now-playing-player')))
            .width,
        tester
            .getSize(find.byKey(const ValueKey('wide-now-playing-lyrics')))
            .width,
      );
    }

    final classic = await paneWidths(NowPlayingStyle.classic);
    expect(classic.$1, closeTo(classic.$2, 1));
    final vinyl = await paneWidths(NowPlayingStyle.vinyl);
    expect(vinyl.$1, closeTo(vinyl.$2, 1));

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingScreen(
          playback: playback,
          style: NowPlayingStyle.classic,
          openLyricsByDefault: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('compact-lyrics')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    playback.dispose();
    engine.dispose();
  });

  testWidgets('desktop now playing integrates lyrics and queue in one pane', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_second, queue: const [_first, _second, _third]);

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(playback: playback)),
    );
    await tester.pump();

    expect(find.byTooltip('播放队列'), findsNothing);
    expect(
      find.byKey(const ValueKey('now-playing-view-switch')),
      findsOneWidget,
    );
    expect(find.text('歌词'), findsNothing);
    expect(find.text('播放清单'), findsNothing);
    expect(find.text('同步\n歌词'), findsOneWidget);
    final lyricPane = tester.getRect(
      find.byKey(const ValueKey('wide-now-playing-lyrics')),
    );
    final lyricTop = tester.getTopLeft(find.text('Second lyric')).dy;
    expect(
      lyricTop - lyricPane.top,
      inInclusiveRange(lyricPane.height * 0.30, lyricPane.height * 0.45),
    );

    await tester.tap(find.byKey(const ValueKey('show-wide-queue')));
    await tester.pump();
    expect(find.byKey(const ValueKey('wide-playback-queue')), findsOneWidget);
    expect(find.text('播放清单'), findsWidgets);
    expect(find.text('3 首歌 · 列表循环'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    final activeRow = find.byKey(const ValueKey('queue-track-row-second'));
    final activation = tester.widget<SoundTrackActivation>(
      find.ancestor(of: activeRow, matching: find.byType(SoundTrackActivation)),
    );
    expect(activation.borderRadius, BorderRadius.zero);
    expect(activation.showFocusOutline, isFalse);
    expect(activation.focusColor, isNotNull);

    await tester.tap(find.byKey(const ValueKey('show-wide-lyrics')));
    await tester.pump();
    expect(find.text('Second lyric'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    playback.dispose();
    engine.dispose();
  });

  testWidgets(
    'foldable and tablet share the integrated lyrics and queue pane',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(720, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = SimulatedPlaybackEngine();
      final playback = SoundPlaybackController(engine: engine);
      await playback.playTrack(_second, queue: const [_first, _second, _third]);

      await tester.pumpWidget(
        MaterialApp(home: NowPlayingScreen(playback: playback)),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('wide-now-playing-player')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('now-playing-view-switch')),
        findsOneWidget,
      );
      expect(find.byTooltip('播放队列'), findsNothing);
      expect(find.text('同步\n歌词'), findsOneWidget);
      final foldablePlayerTop = tester
          .getTopLeft(find.byKey(const ValueKey('wide-now-playing-player')))
          .dy;
      final foldableLyricsTop = tester
          .getTopLeft(find.byKey(const ValueKey('wide-now-playing-lyrics')))
          .dy;
      expect(foldablePlayerTop, greaterThan(foldableLyricsTop + 8));

      await tester.tap(find.byKey(const ValueKey('show-wide-queue')));
      await tester.pump();
      expect(find.byKey(const ValueKey('wide-playback-queue')), findsOneWidget);

      tester.view.physicalSize = const Size(834, 1194);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('now-playing-view-switch')),
        findsOneWidget,
      );
      expect(find.byTooltip('播放队列'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      playback.dispose();
      engine.dispose();
    },
  );

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

    final artworkSize = tester.getSize(
      find.byKey(const ValueKey('album-detail-artwork')),
    );
    expect(artworkSize.width, inInclusiveRange(280, 420));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('album-track-row-first')))
          .height,
      68,
    );
    expect(find.byKey(const ValueKey('desktop-album-shuffle')), findsOneWidget);
    final hero = tester.widget<Container>(
      find.byKey(const ValueKey('album-detail-hero')),
    );
    expect((hero.decoration! as BoxDecoration).gradient, isNull);

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

  testWidgets(
    'compact album detail keeps the first track in the first screen',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = SimulatedPlaybackEngine();
      final playback = SoundPlaybackController(engine: engine);
      await playback.playTrack(_first, queue: const [_first, _second]);
      final album = Album(
        id: 'compact-album',
        title: 'A Long Mobile Album Title',
        artist: 'Artist',
        source: SourceKind.local,
        palette: albumPaletteForId('compact-album'),
        tracks: const [_first, _second],
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

      expect(
        tester
            .getSize(find.byKey(const ValueKey('album-detail-artwork')))
            .width,
        inInclusiveRange(204, 244),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('album-detail-hero'))).height,
        lessThan(560),
      );
      expect(
        find.byKey(const ValueKey('album-detail-background')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('album-detail-play')), findsOneWidget);
      expect(find.text('本地'), findsNothing);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('album-track-row-first')))
            .height,
        64,
      );
      final activeRow = tester.widget<Container>(
        find.byKey(const ValueKey('album-track-row-first')),
      );
      expect(
        (activeRow.decoration! as BoxDecoration).color,
        isNot(SoundColors.accent.withValues(alpha: 0.075)),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('album-track-row-first')))
            .dy,
        lessThan(844),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      playback.dispose();
      engine.dispose();
    },
  );

  testWidgets('narrow desktop album actions fit the remaining content width', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(584, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    final album = Album(
      id: 'narrow-desktop-album',
      title: 'A Long Desktop Album Title',
      artist: 'Artist',
      source: SourceKind.local,
      palette: albumPaletteForId('narrow-desktop-album'),
      tracks: const [_first, _second],
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

    expect(find.byKey(const ValueKey('desktop-album-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-album-shuffle')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    playback.dispose();
    engine.dispose();
  });

  testWidgets('album detail separates discs and preserves playback order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    final album = Album(
      id: 'multi-disc-album',
      title: 'Complete Album',
      artist: 'Main Artist',
      source: SourceKind.local,
      palette: albumPaletteForId('multi-disc-album'),
      tracks: const [_discOne, _discTwo],
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

    expect(find.text('2 张碟 · 2 首歌'), findsOneWidget);
    expect(find.text('第 1 碟'), findsOneWidget);
    expect(find.text('第 2 碟'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '播放'));
    await tester.pump();
    expect(playback.queue.map((track) => track.id), ['disc-one', 'disc-two']);

    await playback.clearQueue();
    await tester.pumpWidget(const SizedBox.shrink());
    playback.dispose();
    engine.dispose();
  });

  testWidgets('WebDAV album can be saved for offline playback', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final offline = _FakeOfflineController();
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    final track = Track(
      id: 'remote',
      title: 'Remote Song',
      artist: 'Artist',
      albumTitle: 'Remote Album',
      duration: const Duration(minutes: 3),
      source: SourceKind.webDav,
      mediaUri: 'https://dav.example.com/remote.flac',
    );
    final album = Album(
      id: 'remote-album',
      title: 'Remote Album',
      artist: 'Artist',
      source: SourceKind.webDav,
      palette: albumPaletteForId('remote-album'),
      tracks: [track],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlbumDetailScreen(
            album: album,
            playback: playback,
            offline: offline,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('离线保存'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('album-offline-action')));
    await tester.pumpAndSettle();

    expect(offline.isPinned(track), isTrue);
    expect(find.byTooltip('已离线'), findsOneWidget);

    offline.startDownloadForTest();
    await tester.pump();
    expect(find.byTooltip('取消下载 35%'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('album-offline-action')));
    await tester.pump();
    expect(offline.cancelled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    offline.dispose();
    playback.dispose();
    engine.dispose();
  });
}

class _FakeOfflineController extends OfflineDownloadController {
  _FakeOfflineController() : super(providers: const []);

  bool pinned = false;
  bool downloading = false;
  bool cancelled = false;

  @override
  bool supports(Track track) => track.source == SourceKind.webDav;

  @override
  bool isPinned(Track track) => pinned;

  @override
  bool areAllPinned(Iterable<Track> tracks) => pinned;

  @override
  bool isDownloadingAny(Iterable<Track> tracks) => downloading;

  @override
  bool isDownloading(Track track) => downloading;

  @override
  int pinnedCount(Iterable<Track> tracks) => pinned ? tracks.length : 0;

  @override
  double? progressFor(Iterable<Track> tracks) => downloading
      ? 0.35
      : pinned
      ? 1
      : 0;

  @override
  OfflineDownloadTask? taskFor(Track track) => downloading
      ? const OfflineDownloadTask(
          state: OfflineDownloadTaskState.downloading,
          progress: 0.35,
        )
      : null;

  @override
  Future<OfflineDownloadBatchResult> pinTracks(Iterable<Track> tracks) async {
    pinned = true;
    notifyListeners();
    return OfflineDownloadBatchResult(completed: tracks.length, failed: 0);
  }

  void startDownloadForTest() {
    pinned = false;
    downloading = true;
    notifyListeners();
  }

  @override
  bool cancelTracks(Iterable<Track> tracks) {
    downloading = false;
    cancelled = true;
    notifyListeners();
    return true;
  }
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
  lyrics: [LyricLine(Duration(seconds: 1), 'Second lyric')],
);

const _third = Track(
  id: 'third',
  title: 'Third',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 5),
  source: SourceKind.webDav,
);

const _discOne = Track(
  id: 'disc-one',
  title: 'Disc One',
  artist: 'Main Artist',
  albumTitle: 'Complete Album',
  duration: Duration(minutes: 3),
  source: SourceKind.local,
  trackNumber: 1,
  discNumber: 1,
);

const _discTwo = Track(
  id: 'disc-two',
  title: 'Disc Two',
  artist: 'Main Artist & Guest',
  albumTitle: 'Complete Album',
  duration: Duration(minutes: 4),
  source: SourceKind.local,
  trackNumber: 1,
  discNumber: 2,
);
