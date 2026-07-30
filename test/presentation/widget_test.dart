import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kaiting/app/sound_app.dart';
import 'package:kaiting/app/kaiting_launch_screen.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/core/now_playing_style.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/library/persistence/drift_library_repository.dart';
import 'package:kaiting/library/persistence/library_database.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/playback_session.dart';
import 'package:kaiting/playback/simulated_playback_engine.dart';
import 'package:kaiting/presentation/app_shell.dart';
import 'package:kaiting/presentation/controllers/library_catalog_controller.dart';
import 'package:kaiting/presentation/screens/now_playing_screen.dart';
import 'package:kaiting/presentation/widgets/animated_artwork_background.dart';
import 'package:kaiting/presentation/widgets/mini_player.dart';
import 'package:kaiting/presentation/widgets/progress_scrubber.dart';
import 'package:kaiting/presentation/widgets/sound_components.dart';
import 'package:kaiting/presentation/widgets/vinyl_record_art.dart';

void main() {
  PackageInfo.setMockInitialValues(
    appName: '开听',
    packageName: 'com.kaiting.player',
    version: '1.0.1',
    buildNumber: '4',
    buildSignature: '',
  );

  testWidgets('shared launch surface shows the complete 开听 lockup', (
    tester,
  ) async {
    await tester.pumpWidget(const KaitingLaunchApp());

    expect(
      find.image(const AssetImage('assets/branding/launch_mark.png')),
      findsOneWidget,
    );
    expect(find.text('开听'), findsOneWidget);
    expect(find.text('听自己的音乐'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, kaitingLaunchBackground);
  });

  testWidgets('preloaded playback session skips the Flutter launch screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
        sessionIsPreloaded: true,
      ),
    );

    expect(
      find.image(const AssetImage('assets/branding/launch_mark.png')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('desktop-search-action')), findsOneWidget);

    await _unmountAndFlush(tester);
  });

  testWidgets('preloaded catalog renders on the first app-shell frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    final snapshot = await loadLibraryCatalogSnapshot(repository);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          playback: playback,
          libraryRepository: repository,
          initialCatalog: snapshot,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('正在读取资料库'), findsNothing);
    expect(find.text('正在加载已索引的专辑和歌曲。'), findsNothing);
    expect(find.text('Test Album'), findsWidgets);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });

  testWidgets('shows repository albums instead of production demo data', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.macOS);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('开听'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/branding/app_icon_master-v9.png')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('desktop-search-action')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-settings-action')),
      findsOneWidget,
    );
    expect(find.text('快捷键'), findsNothing);
    expect(find.text('资料库'), findsWidgets);
    expect(find.text('Test Album'), findsWidgets);
    expect(find.text('本地'), findsNothing);
    expect(find.text('Test Track'), findsNothing);
    expect(find.text('范特西'), findsNothing);
    final desktopGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final desktopDelegate =
        desktopGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(desktopDelegate.mainAxisExtent, lessThan(250));
    expect(desktopDelegate.mainAxisSpacing, 16);
    final libraryArtworkDecorations = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('library-album-art-album:test')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where(
          (decoration) =>
              decoration.borderRadius != null || decoration.gradient != null,
        )
        .toList();
    expect(
      libraryArtworkDecorations.every(
        (decoration) => decoration.border == null,
      ),
      isTrue,
    );
    expect(
      libraryArtworkDecorations.every(
        (decoration) => decoration.boxShadow?.isEmpty ?? true,
      ),
      isTrue,
    );
    expect(
      libraryArtworkDecorations
          .singleWhere((decoration) => decoration.borderRadius != null)
          .borderRadius,
      BorderRadius.circular(14),
    );

    await tester.tap(find.text('Test Album').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 首歌'), findsOneWidget);

    final backButton = find.byKey(const ValueKey('desktop-album-back'));
    final titleBarAction = find.byKey(const ValueKey('desktop-search-action'));
    expect(backButton, findsOneWidget);
    expect(
      tester.getRect(backButton).top,
      greaterThanOrEqualTo(tester.getRect(titleBarAction).bottom),
    );

    await tester.tap(backButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('album-detail-background')), findsNothing);

    await tester.tap(find.text('Test Album').first);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('album-detail-background')), findsNothing);

    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(1194, 834);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Album').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Track'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('mini-player-condensed-content-padding')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == KaitingIcons.playing &&
            widget.size == 18,
      ),
      findsOneWidget,
    );

    await _unmountAndFlush(tester);
  });

  testWidgets('touch navigation stays available across iPad rotation', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('compact-library-navigation')),
      findsOneWidget,
    );
    expect(find.byType(SoundNavigationBar), findsOneWidget);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-mode-albums')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('compact-library-navigation')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('compact-library-navigation')))
          .height,
      34,
    );
    expect(
      find.byKey(const ValueKey('mobile-library-user-menu')),
      findsOneWidget,
    );
    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('compact-library-toolbar'))),
      const Size(358, 40),
    );
    final compactGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final compactDelegate =
        compactGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(compactDelegate.crossAxisCount, 2);
    expect(compactDelegate.mainAxisExtent, lessThan(220));
    expect(compactDelegate.mainAxisSpacing, 12);

    await tester.tap(find.byKey(const ValueKey('library-mode-artists')));
    await tester.pumpAndSettle();
    expect(find.byType(SliverGrid), findsNothing);
    expect(
      find.byKey(const ValueKey('library-collection-artist:test artist')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('library-mode-songs')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('compact-library-play-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('library-track-actions-track:test')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('library-track-row-track:test')))
          .height,
      64,
    );
    expect(
      find.byKey(const ValueKey('favorite-library-track:test')),
      findsNothing,
    );

    await _unmountAndFlush(tester);
  });

  testWidgets('iPad landscape back and navigation react on first tap', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    final snapshot = await loadLibraryCatalogSnapshot(repository);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          playback: playback,
          libraryRepository: repository,
          initialCatalog: snapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SoundNavigationBar), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('library-album-art-album:test')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-album-back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('desktop-album-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-album-back')), findsNothing);

    final navigation = find.byType(SoundNavigationBar);
    await tester.tap(
      find.descendant(
        of: navigation,
        matching: find.byIcon(KaitingIcons.settings),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsWidgets);
    expect(
      find.descendant(
        of: navigation,
        matching: find.byIcon(KaitingIcons.settingsFilled),
      ),
      findsOneWidget,
    );

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });

  testWidgets('swiping the library pager switches browse mode', (tester) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();

    // The touch shell browses via a horizontal pager; 专辑 is the first page.
    expect(find.byKey(const ValueKey('library-mode-pager')), findsOneWidget);
    expect(find.byType(SliverGrid), findsOneWidget);

    // Swipe left to reveal the 艺人 page. Visited pages stay alive offscreen,
    // so assert on what is actually hittable in the viewport.
    await tester.drag(
      find.byKey(const ValueKey('library-mode-pager')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('library-album-art-album:test')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('library-collection-artist:test artist')),
      findsOneWidget,
    );

    // Swipe right to return to 专辑.
    await tester.drag(
      find.byKey(const ValueKey('library-mode-pager')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('library-album-art-album:test')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find
          .byKey(const ValueKey('library-collection-artist:test artist'))
          .hitTestable(),
      findsNothing,
    );

    await _unmountAndFlush(tester);
  });

  testWidgets('empty library still swipes between browse modes', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();

    // With nothing indexed the pager still mounts, so a swipe never
    // dead-ends on the empty-state page.
    expect(find.byKey(const ValueKey('library-mode-pager')), findsOneWidget);
    expect(find.text('资料库还是空的').hitTestable(), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('library-mode-pager')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('资料库还是空的').hitTestable(), findsOneWidget);

    await _unmountAndFlush(tester);
  });

  testWidgets('foldable library keeps the compact toolbar row on every tab', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.android);
    // Opened foldable inner display: medium window class, mobile shell.
    tester.view.physicalSize = const Size(700, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();

    // Same right-aligned toolbar row as a phone, on every tab.
    expect(
      find.byKey(const ValueKey('compact-library-navigation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('compact-library-toolbar')),
      findsOneWidget,
    );

    // Songs tab carries play-all in the toolbar row; the desktop in-list
    // header must not duplicate it.
    await tester.tap(find.byKey(const ValueKey('library-mode-songs')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('compact-library-play-all')),
      findsOneWidget,
    );
    expect(find.text('播放全部'), findsOneWidget);

    await _unmountAndFlush(tester);
  });

  testWidgets('browses real artists without debug tools', (tester) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('播放验证（Debug）'), findsNothing);
    await tester.tap(find.text('艺人').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('library-collection-artist:test artist')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Artist'), findsWidgets);
    expect(find.text('1 张专辑 · 1 首歌曲'), findsOneWidget);
    expect(find.text('播放全部'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-artist-play')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-artist-shuffle')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('collection-detail-artwork')))
          .width,
      inInclusiveRange(152, 200),
    );
    await tester.drag(
      find.byKey(const ValueKey('collection-detail-hero')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Album'), findsWidgets);
    expect(find.text('Test Track'), findsNothing);
    expect(
      find.byKey(const ValueKey('library-collection-track-sort-menu')),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('desktop-artist-play')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('desktop-artist-play')));
    await tester.pump();
    expect(find.text('Test Track'), findsWidgets);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
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
      inInclusiveRange(112, 136),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('collection-detail-hero')))
          .height,
      lessThan(560),
    );
    final compactCollectionGrid = tester.widget<SliverGrid>(
      find.byType(SliverGrid),
    );
    final compactCollectionDelegate =
        compactCollectionGrid.gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    expect(compactCollectionDelegate.crossAxisCount, 2);
    expect(compactCollectionDelegate.mainAxisExtent, lessThan(220));
    expect(compactCollectionDelegate.mainAxisSpacing, 12);
    expect(
      find.byKey(const ValueKey('collection-track-row-track:test')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('collection-track-actions-track:test')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
  });

  testWidgets('sorts and filters each real library view', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('library-sort-menu'))).height,
      36,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('library-source-menu'))).height,
      36,
    );
    await tester.tap(find.byKey(const ValueKey('library-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('艺人 A–Z'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('排序：艺人 A–Z'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('library-source-menu')));
    await tester.pumpAndSettle();
    expect(find.text('WebDAV'), findsNothing);
    await tester.tap(find.text('本地').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('来源：本地'), findsWidgets);
    expect(find.text('Test Album'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('library-source-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部来源').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('来源：全部来源'), findsWidgets);
    expect(find.text('Test Album'), findsWidgets);

    await tester.tap(find.text('歌曲').first);
    await tester.pumpAndSettle();
    expect(find.text('1 首歌曲'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('library-sort-menu')));
    await tester.pumpAndSettle();
    expect(find.text('专辑 A–Z'), findsOneWidget);

    await _unmountAndFlush(tester);
  });

  testWidgets('mobile song fast index follows alphabet and year sorting', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithFastIndexTracks();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('歌曲').first);
    await tester.pumpAndSettle();

    final fastIndex = find.byKey(const ValueKey('library-song-fast-index'));
    expect(fastIndex, findsOneWidget);
    expect(tester.getSize(fastIndex).width, 44);
    expect(
      find.byKey(const ValueKey('library-song-fast-index-T')),
      findsOneWidget,
    );

    final indexRect = tester.getRect(fastIndex);
    final gesture = await tester.startGesture(
      Offset(
        indexRect.center.dx,
        indexRect.top + indexRect.height * (19.5 / 27),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    final overlay = find.byKey(
      const ValueKey('library-song-fast-index-overlay'),
    );
    expect(overlay, findsOneWidget);
    expect(
      find.descendant(of: overlay, matching: find.text('T')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('library-track-row-track:index:10')),
      findsOneWidget,
    );

    await gesture.moveTo(
      Offset(
        indexRect.center.dx,
        indexRect.top + indexRect.height * (25.5 / 27),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(of: overlay, matching: find.text('Z')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('library-track-row-track:index:20')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, 2000),
      5000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('年份（新到旧）').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('library-song-fast-index-A')),
      findsNothing,
    );
    for (final year in ['2026', '2018', '2010']) {
      expect(
        find.byKey(ValueKey('library-song-fast-index-$year')),
        findsOneWidget,
      );
    }
    final yearRect = tester.getRect(fastIndex);
    final yearGesture = await tester.startGesture(
      Offset(yearRect.center.dx, yearRect.top + yearRect.height * 0.84),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.descendant(of: overlay, matching: find.text('2010')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('library-track-row-track:index:20')),
      findsOneWidget,
    );
    await yearGesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
  });

  testWidgets('favorites and recently played are fully interactive', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Album').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Track'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('track-actions-track:test')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收藏').last);
    await tester.pumpAndSettle();
    expect((await repository.getFavoriteTracks()).single.trackId, 'track:test');
    expect((await repository.getPlayHistory()).single.trackId, 'track:test');

    await tester.tap(find.byKey(const ValueKey('desktop-album-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-library-user-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收藏').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('user-library-track-favorites-track:test')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('user-library-mode-recent')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('user-library-track-recent-track:test')),
      findsOneWidget,
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('user-track-row-track:test')))
          .height,
      64,
    );
    expect(
      find.byKey(const ValueKey('user-track-actions-track:test')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('favorite-track-track:test')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('add-user-track:test-to-playlist')),
      findsNothing,
    );

    await tester.tap(find.text('清除历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();
    expect(find.text('还没有最近播放'), findsOneWidget);
    expect(await repository.getPlayHistory(), isEmpty);
    expect((await repository.getFavoriteTracks()).single.trackId, 'track:test');

    await tester.tap(find.byKey(const ValueKey('user-library-mode-favorites')));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('user-track-row-track:test')))
          .height,
      64,
    );
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
  });

  testWidgets('playlists support creation, editing, ordering, and deletion', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum(includeSecondTrack: true);
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('歌曲').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('add-library-track:test-to-playlist')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-playlist-from-track')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-name-field')),
      'Road Trip',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-playlist-name')));
    await tester.pumpAndSettle();
    expect((await repository.getPlaylists()).single.name, 'Road Trip');
    expect((await repository.getPlaylistTracks()).single.trackId, 'track:test');
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('add-library-track:second-to-playlist')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('playlist-membership-1-track:second')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mobile-library-user-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放列表').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('playlist-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('playlist-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('playlist-1-track-track:test')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('playlist-1-track-track:second')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('rename-playlist')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-name-field')),
      'Morning Drive',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-playlist-name')));
    await tester.pumpAndSettle();
    expect((await repository.getPlaylists()).single.name, 'Morning Drive');

    final reorderable = tester.widget<SliverReorderableList>(
      find.byType(SliverReorderableList),
    );
    reorderable.onReorderItem!(0, 1);
    await tester.pumpAndSettle();
    expect(
      (await repository.getPlaylistTracks()).map((entry) => entry.trackId),
      ['track:second', 'track:test'],
    );

    await tester.tap(
      find.byKey(const ValueKey('playlist-track-actions-track:test')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一首播放'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('playlist-track-actions-track:test')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('从此列表移除'));
    await tester.pumpAndSettle();
    expect(
      (await repository.getPlaylistTracks()).single.trackId,
      'track:second',
    );

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('playlist-track-row-track:second')),
          )
          .height,
      64,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('delete-playlist')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-playlist')));
    await tester.pumpAndSettle();
    expect(await repository.getPlaylists(), isEmpty);
    expect(find.text('还没有播放列表'), findsOneWidget);

    await _unmountAndFlush(tester);
  });

  testWidgets('empty repository presents a source-management action', (
    tester,
  ) async {
    final repository = _repository();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('资料库还是空的'), findsOneWidget);
    expect(find.text('管理音乐来源'), findsOneWidget);

    await _unmountAndFlush(tester);
  });

  testWidgets('restored session remains visible without autoplay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    final sessionStore = PlaybackSessionStore.memory();
    addTearDown(repository.close);
    await sessionStore.save(
      const PlaybackSession(
        queue: [_testTrack],
        queueIndex: 0,
        positionMs: 60000,
      ),
    );

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: sessionStore,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Track'), findsOneWidget);
    final restoredProgress = tester.widget<ProgressScrubber>(
      find.byKey(const ValueKey('mini-player-progress')),
    );
    expect(restoredProgress.position, const Duration(milliseconds: 60000));
    expect(restoredProgress.duration, const Duration(milliseconds: 180000));
    expect(restoredProgress.interactive, isFalse);
    expect(find.byIcon(KaitingIcons.playMini), findsOneWidget);

    await _unmountAndFlush(tester);
  });

  testWidgets('active playback is checkpointed and flushed on background', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    final sessionStore = PlaybackSessionStore.memory();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: sessionStore,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Album').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Track'));
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    final checkpoint = await sessionStore.load();
    expect(checkpoint, isNotNull);
    expect(checkpoint!.queue.single.id, _testTrack.id);
    expect(checkpoint.positionMs, greaterThan(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect((await sessionStore.load())!.positionMs, greaterThanOrEqualTo(3000));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await _unmountAndFlush(tester);
  });

  testWidgets('compact mini player merges into bottom navigation dock', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_testTrack, queue: const [_testTrack]);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(playback: playback, libraryRepository: repository),
      ),
    );
    await tester.pump();

    final miniPlayerBottom = tester.getBottomLeft(find.byType(MiniPlayer)).dy;
    final navigationTop = tester.getTopLeft(find.byType(SoundNavigationBar)).dy;
    expect(navigationTop - miniPlayerBottom, 0);
    expect(find.byKey(const ValueKey('compact-playback-dock')), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isTrue);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });

  testWidgets('mobile now playing opens on tap and follows downward drag', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_testTrack, queue: const [_testTrack]);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(playback: playback, libraryRepository: repository),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(MiniPlayer), const Offset(0, -240));
    await tester.pump();
    expect(find.byType(NowPlayingScreen), findsNothing);

    await tester.tap(find.byType(MiniPlayer));
    await tester.pump();
    expect(
      tester.widget<NowPlayingScreen>(find.byType(NowPlayingScreen)).isActive,
      isFalse,
    );
    // First frame mounts the compact player; its post-frame callback starts
    // the expansion animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    expect(
      tester.widget<NowPlayingScreen>(find.byType(NowPlayingScreen)).isActive,
      isTrue,
    );
    final backgroundState = tester.state(
      find.byType(AnimatedArtworkBackground),
    );
    expect(
      tester.getTopLeft(find.byType(NowPlayingScreen)).dy,
      closeTo(0, 0.1),
    );
    expect(find.byKey(const ValueKey('now-playing-view-switch')), findsNothing);
    final favorite = find.byKey(
      ValueKey('favorite-now-playing-${_testTrack.id}'),
    );
    final addToPlaylist = find.byKey(
      ValueKey('add-now-playing-${_testTrack.id}-to-playlist'),
    );
    final visualToLyrics = find.byKey(
      const ValueKey('compact-visual-to-lyrics'),
    );
    final title = find.byKey(const ValueKey('now-playing-track-title'));
    final artist = find.byKey(const ValueKey('now-playing-track-artist'));
    final playbackControls = find.byKey(
      const ValueKey('compact-playback-controls'),
    );
    final titleActions = find.byKey(
      const ValueKey('compact-now-playing-title-actions'),
    );
    final topActions = find.byKey(const ValueKey('now-playing-drag-handle'));
    final artwork = find.byKey(const ValueKey('compact-now-playing-artwork'));
    final stage = find.byKey(const ValueKey('compact-visual-stage'));
    expect(
      tester
          .widget<ProgressScrubber>(
            find.descendant(
              of: playbackControls,
              matching: find.byType(ProgressScrubber),
            ),
          )
          .trackVerticalOffset,
      7,
    );
    expect(tester.getSize(topActions).height, lessThan(72));
    expect(
      tester.getTopLeft(artwork).dy - tester.getBottomLeft(topActions).dy,
      inInclusiveRange(36, 44),
    );
    expect(tester.getSize(stage).height, lessThanOrEqualTo(370));
    expect(tester.getSize(title).width, inInclusiveRange(160, 270));
    expect(
      tester.getTopLeft(artist).dy - tester.getBottomLeft(title).dy,
      greaterThanOrEqualTo(7),
    );
    expect(
      tester.getCenter(titleActions).dx,
      greaterThan(tester.getCenter(title).dx),
    );
    expect(
      tester.getCenter(favorite).dx,
      lessThan(tester.getCenter(addToPlaylist).dx),
    );
    expect(
      tester.getCenter(addToPlaylist).dx - tester.getCenter(favorite).dx,
      greaterThanOrEqualTo(47),
    );
    expect(tester.widget<IconButton>(favorite).iconSize, 24);
    expect(tester.widget<IconButton>(addToPlaylist).iconSize, 24);
    expect(
      (tester.getCenter(favorite).dy - tester.getCenter(titleActions).dy).abs(),
      lessThan(2),
    );
    final titleText = tester.widget<Text>(
      find.descendant(of: title, matching: find.text(_testTrack.title)).last,
    );
    expect(titleText.style?.fontSize, 22);
    final modeButton = find.byKey(const ValueKey('now-playing-mode-cycle'));
    final sleepButton = find.byKey(const ValueKey('now-playing-sleep-timer'));
    final controlsRect = tester.getRect(playbackControls);
    expect(
      tester.getCenter(modeButton).dx - controlsRect.left,
      closeTo(12, 0.1),
    );
    expect(
      controlsRect.right - tester.getCenter(sleepButton).dx,
      closeTo(12, 0.1),
    );
    expect(find.byKey(const ValueKey('show-now-playing-lyrics')), findsNothing);
    await tester.tap(sleepButton);
    await tester.pumpAndSettle();
    final sleepTimerOption = find.byKey(
      const ValueKey('now-playing-sleep-timer-15'),
    );
    expect(sleepTimerOption, findsOneWidget);
    expect(tester.widget(sleepTimerOption), isA<SoundListRow>());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final coverStage = tester.getRect(stage);
    final coverControls = tester.getRect(playbackControls);
    final coverTitleActions = tester.getRect(titleActions);
    final coverFavoriteCenter = tester.getCenter(favorite);
    await tester.tap(visualToLyrics);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('compact-lyrics')), findsOneWidget);
    expect(tester.getRect(stage), coverStage);
    expect(tester.getRect(playbackControls), coverControls);
    expect(tester.getRect(titleActions), coverTitleActions);
    expect(tester.getCenter(favorite).dx, closeTo(coverFavoriteCenter.dx, 1));
    await tester.tapAt(coverStage.topLeft + const Offset(8, 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final collapseGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('compact-player'))),
    );
    await collapseGesture.moveBy(const Offset(0, 320));
    await collapseGesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(
      tester.widget<NowPlayingScreen>(find.byType(NowPlayingScreen)).isActive,
      isFalse,
    );
    expect(
      tester.state(find.byType(AnimatedArtworkBackground)),
      same(backgroundState),
    );
    expect(tester.getTopLeft(find.byType(NowPlayingScreen)).dy, greaterThan(0));
    await collapseGesture.moveBy(const Offset(0, 380));
    await collapseGesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NowPlayingScreen), findsNothing);
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });

  testWidgets('mobile shell keeps content outside system safe areas', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.android);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      left: 12,
      top: 32,
      right: 8,
      bottom: 24,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final repository = _repository();
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_testTrack, queue: const [_testTrack]);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(playback: playback, libraryRepository: repository),
      ),
    );
    await tester.pump();

    final safeArea = tester.getRect(
      find.byKey(const ValueKey('mobile-content-safe-area')),
    );
    expect(safeArea.top, 0);
    final contentRect = tester.getRect(
      find
          .descendant(
            of: find.byKey(const ValueKey('mobile-content-safe-area')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(contentRect.top, greaterThanOrEqualTo(32));

    final miniPlayer = tester.getRect(find.byType(MiniPlayer));
    expect(miniPlayer.left, 0);
    expect(miniPlayer.right, 390);
    final navigation = tester.getRect(find.byType(SoundNavigationBar));
    expect(navigation.bottom, 844);
    expect(navigation.height, greaterThanOrEqualTo(70));
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });

  testWidgets('mobile system back closes detail pages before the app route', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.android);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum();
    final snapshot = await loadLibraryCatalogSnapshot(repository);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          playback: playback,
          libraryRepository: repository,
          initialCatalog: snapshot,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Test Album').first);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('mobile-detail-page-transition')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('album-detail-background')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('library-album-art-album:test')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('album-detail-background')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('album-detail-background')), findsNothing);
    expect(
      find.byKey(const ValueKey('library-album-art-album:test')),
      findsOneWidget,
    );

    await tester.tap(find.text('艺人').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Artist').first);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('artist-detail-background')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('artist-detail-background')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('artist-detail-background')),
      findsNothing,
    );
    expect(find.text('Test Artist'), findsOneWidget);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });

  testWidgets('mobile detail pages restore the originating list position', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.android);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithAlbum(extraAlbumCount: 12);
    final snapshot = await loadLibraryCatalogSnapshot(repository);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          playback: playback,
          libraryRepository: repository,
          initialCatalog: snapshot,
        ),
      ),
    );
    await tester.pump();

    final albumList = find.byKey(
      const PageStorageKey<String>('library-albums'),
    );
    final albumScrollable = find
        .descendant(of: albumList, matching: find.byType(Scrollable))
        .first;
    await tester.drag(albumList, const Offset(0, -520));
    await tester.pumpAndSettle();
    final positionBeforeOpen = tester
        .state<ScrollableState>(albumScrollable)
        .position
        .pixels;
    expect(positionBeforeOpen, greaterThan(0));

    final visibleAlbum = find.byKey(
      const ValueKey('library-album-art-album:extra:5'),
    );
    await tester.ensureVisible(visibleAlbum);
    await tester.pumpAndSettle();
    final expectedPosition = tester
        .state<ScrollableState>(albumScrollable)
        .position
        .pixels;
    await tester.tap(visibleAlbum);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('album-detail-background')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(albumScrollable).position.pixels,
      closeTo(expectedPosition, 0.5),
    );

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });

  testWidgets('desktop mini player is a full-width bottom dock', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.macOS);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_testTrack, queue: const [_testTrack]);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: AppShell(playback: playback, libraryRepository: repository),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(MiniPlayer));
    expect(rect.left, 0);
    expect(rect.right, 1200);
    expect(rect.bottom, 800);
    expect(rect.height, 76);
    expect(find.byType(SoundNavigationBar), findsNothing);

    final progressRect = tester.getRect(
      find.byKey(const ValueKey('mini-player-progress')),
    );
    final toggleCenter = tester.getCenter(
      find.byKey(const ValueKey('mini-player-playback-toggle')),
    );
    // Top progress track is 3pt tall and flush to the dock edge.
    expect(progressRect.top, closeTo(rect.top, 0.5));
    expect(progressRect.height, closeTo(3, 0.5));
    expect((toggleCenter.dy - rect.center.dy).abs(), lessThan(8));

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });

  testWidgets(
    'desktop never falls back to the mobile shell in a short window',
    (tester) async {
      _simulatePlatform(TargetPlatform.macOS);
      tester.view.physicalSize = const Size(1000, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _repository();
      final engine = SimulatedPlaybackEngine();
      final playback = SoundPlaybackController(engine: engine);
      await playback.playTrack(_testTrack, queue: const [_testTrack]);

      await tester.pumpWidget(
        MaterialApp(
          theme: SoundTheme.light,
          home: AppShell(playback: playback, libraryRepository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('开听'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('开听')).dy,
        greaterThan(soundMacOSTitlebarInset),
      );
      expect(find.byType(SoundNavigationBar), findsNothing);
      final dockRect = tester.getRect(find.byType(MiniPlayer));
      expect(dockRect.left, 0);
      expect(dockRect.right, 1000);
      expect(dockRect.bottom, 480);
      expect(dockRect.height, 76);
      expect(tester.takeException(), isNull);

      await _unmountAndFlush(tester);
      playback.dispose();
      engine.dispose();
      await repository.close();
    },
  );

  testWidgets('android tablets and foldables pick the shell by aspect', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.android);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(playback: playback, libraryRepository: repository),
      ),
    );

    Future<void> expectShell({required bool mobile}) async {
      await tester.pumpAndSettle();
      expect(find.text('开听'), mobile ? findsNothing : findsOneWidget);
      expect(
        find.byType(SoundNavigationBar),
        mobile ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }

    // 10" Android tablet: portrait is touch-first, landscape promotes.
    tester.view.physicalSize = const Size(800, 1280);
    await expectShell(mobile: true);
    tester.view.physicalSize = const Size(1280, 800);
    await expectShell(mobile: false);

    // Budget tablets can report a landscape width below 1000 - aspect ratio,
    // not width, decides. 960x600 is 16:10, so it still promotes.
    tester.view.physicalSize = const Size(960, 600);
    await expectShell(mobile: false);

    // Foldable inner display: near-square in both orientations, so it keeps
    // touch-first navigation even turned sideways.
    tester.view.physicalSize = const Size(840, 700);
    await expectShell(mobile: true);
    tester.view.physicalSize = const Size(700, 840);
    await expectShell(mobile: true);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });

  testWidgets('iPad keeps touch navigation across rotation and split view', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(834, 1194);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(playback: playback, libraryRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    // Portrait iPad keeps touch-first navigation like a phone.
    expect(find.text('开听'), findsNothing);
    expect(find.byType(SoundNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Landscape keeps the same touch navigation; only content layout changes.
    tester.view.physicalSize = const Size(1194, 834);
    await tester.pumpAndSettle();
    expect(find.text('开听'), findsNothing);
    expect(find.byType(SoundNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Split view drops back to the mobile shell.
    tester.view.physicalSize = const Size(600, 1024);
    await tester.pumpAndSettle();

    expect(find.text('开听'), findsNothing);
    expect(find.byType(SoundNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(KaitingIcons.settings));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsWidgets);
    expect(find.text('开发版本'), findsNothing);
    expect(find.text('1.0.1'), findsOneWidget);
    expect(find.text('播放'), findsWidgets);
    expect(find.text('资料库'), findsWidgets);
    expect(find.text('音乐来源'), findsOneWidget);
    expect(find.text('键盘快捷键'), findsNothing);
    expect(find.byKey(const ValueKey('settings-group-playback')), findsNothing);
    expect(find.text('添加本地文件夹'), findsNothing);
    final compactSettingsIcons = tester
        .widgetList<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('settings-overview')),
            matching: find.byType(Icon),
          ),
        )
        .map((icon) => icon.icon)
        .toSet();
    expect(compactSettingsIcons, {KaitingIcons.chevronRight});
    expect(
      tester.widget<Text>(find.text('设置队列结束和切歌方式')).style?.color,
      SoundGlassTheme.light.secondaryText,
    );
    expect(
      tester.widget<Text>(find.text('播放模式')).style?.color,
      SoundGlassTheme.light.primaryText,
    );

    final settingsScrollable = find
        .descendant(
          of: find.byKey(const ValueKey('settings-overview')),
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('skin-preset-selector')),
      240,
      scrollable: settingsScrollable,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skin-preset-selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('skin-preset-default')), findsOneWidget);
    expect(find.byKey(const ValueKey('skin-preset-pure')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('skin-preset-deep-night')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('skin-preset-deep-night')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skin-preset-selector')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('now-playing-style-selector')),
      240,
      scrollable: settingsScrollable,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('now-playing-style-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('now-playing-style-classic')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('now-playing-style-vinyl')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('now-playing-style-cover-focus')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('now-playing-style-immersive-lyrics')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('settings-open-lyrics-default-row')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('now-playing-style-vinyl')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('now-playing-style-selector')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-open-lyrics-default-row')),
      240,
      scrollable: settingsScrollable,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-open-lyrics-default-row')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('custom-accent-swatch')),
      -240,
      scrollable: settingsScrollable,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-accent-swatch')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('custom-accent-swatch')));
    await tester.pumpAndSettle();
    expect(find.text('自定义主题色'), findsWidgets);
    expect(find.byKey(const ValueKey('custom-accent-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-accent-hue')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('apply-custom-accent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-accent-preview')), findsNothing);

    await tester.scrollUntilVisible(
      find.text('播放模式'),
      -320,
      scrollable: settingsScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放模式'));
    await tester.pumpAndSettle();
    expect(find.byType(SoundBottomSheet), findsOneWidget);
    final compactOptionIcons = tester
        .widgetList<Icon>(
          find.descendant(
            of: find.byType(SoundBottomSheet),
            matching: find.byType(Icon),
          ),
        )
        .map((icon) => icon.icon)
        .toSet();
    expect(compactOptionIcons, {KaitingIcons.check});
    await tester.tap(
      find.byKey(const ValueKey('settings-playback-mode-shuffle')),
    );
    await tester.pumpAndSettle();
    expect(playback.playbackMode.name, 'shuffle');
    expect(find.text('随机播放'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-sleep-timer-row')));
    await tester.pumpAndSettle();
    expect(find.byType(SoundBottomSheet), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sleep-timer-15')));
    await tester.pumpAndSettle();
    expect(find.byType(SoundBottomSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-sources-row')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('source-settings')), findsOneWidget);
    expect(find.text('音乐来源'), findsOneWidget);
    expect(find.text('添加文件夹'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-overview')), findsOneWidget);
    expect(find.byKey(const ValueKey('source-settings')), findsNothing);

    tester.view.physicalSize = const Size(874, 402);
    await tester.pumpAndSettle();

    expect(find.byType(SoundNavigationBar), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-sleep-timer-row')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sleep-timer-cancel')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });

  testWidgets('now playing fits iPhone and portrait iPad widths', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_testTrack, queue: const [_testTrack]);

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(playback: playback)),
    );
    await tester.pump();

    expect(find.text('Test Track'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('compact-visual-to-lyrics')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('compact-visual-to-lyrics')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('这首歌曲没有内嵌歌词'), findsOneWidget);

    tester.view.physicalSize = const Size(834, 1194);
    await tester.pump();
    // Portrait iPad keeps the compact single-column player, matching the
    // mobile shell.
    expect(
      find.byKey(const ValueKey('compact-visual-to-lyrics')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('wide-now-playing-lyrics')), findsNothing);
    expect(tester.takeException(), isNull);

    // Landscape iPad promotes to the wide two-pane player via the sidebar
    // shell. This test places NowPlayingScreen outside the shell, so we
    // simulate the same dimensions directly.
    tester.view.physicalSize = const Size(1194, 834);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('wide-now-playing-lyrics')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
  });

  testWidgets('scrubbing the compact progress bar does not arm dismiss', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_testTrack, queue: const [_testTrack]);
    var dragStarts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingScreen(
          playback: playback,
          onVerticalDragStart: (_) => dragStarts++,
          onVerticalDragUpdate: (_) {},
          onVerticalDragEnd: (_) {},
        ),
      ),
    );
    await tester.pump();

    // A scrub with a vertical component must stay a scrub: the sheet has to
    // remain expanded instead of following the finger towards the mini
    // player.
    await tester.drag(
      find.byKey(const ValueKey('progress-scrubber-hit-target')),
      const Offset(40, 120),
    );
    await tester.pump();
    expect(dragStarts, 0);

    // The same downward drag anywhere else on the cover view still dismisses.
    await tester.drag(
      find.byKey(const ValueKey('compact-now-playing-artwork')),
      const Offset(0, 120),
    );
    await tester.pump();
    expect(dragStarts, 1);
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
  });

  testWidgets('scrubber holds the seek preview until the engine catches up', (
    tester,
  ) async {
    var positionMs = 10000;
    Duration? sought;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ProgressScrubber(
                position: Duration(milliseconds: positionMs),
                duration: const Duration(seconds: 100),
                onSeek: (target) => sought = target,
              );
            },
          ),
        ),
      ),
    );

    final hit = find.byKey(const ValueKey('progress-scrubber-hit-target'));
    final start = tester.getTopLeft(hit);
    final size = tester.getSize(hit);
    // Drag across a large portion of the bar so onSeek must fire.
    await tester.timedDragFrom(
      start + Offset(size.width * 0.15, size.height / 2),
      Offset(size.width * 0.55, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    await tester.pump();
    final target = sought;
    expect(target, isNotNull);
    expect(target!.inMilliseconds, greaterThan(positionMs));

    // The engine still reports the pre-seek position. Preview must keep the
    // committed target until position ticks catch up (no snap-back).
    rebuild(() {});
    await tester.pump();
    // Re-open seek target still held until parent position advances.
    expect(sought, target);

    rebuild(() => positionMs = target.inMilliseconds);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
  });

  testWidgets(
    'scrubber onPreviewChanged updates sibling labels while engine is frozen',
    (tester) async {
      // Mirrors paused playback: engine position stays put while the finger
      // drags; time labels must follow onPreviewChanged, not displayPosition.
      const enginePosition = Duration(seconds: 10);
      Duration? scrubPreview;
      Duration? sought;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                final shown = scrubPreview ?? enginePosition;
                return Column(
                  children: [
                    ProgressScrubber(
                      position: enginePosition,
                      duration: const Duration(seconds: 100),
                      onSeek: (target) => sought = target,
                      onPreviewChanged: (preview) {
                        setState(() => scrubPreview = preview);
                      },
                    ),
                    Text(
                      key: const ValueKey('scrub-preview-label'),
                      formatDuration(shown),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('0:10'), findsOneWidget);

      final hit = find.byKey(const ValueKey('progress-scrubber-hit-target'));
      final start = tester.getTopLeft(hit);
      final size = tester.getSize(hit);
      await tester.timedDragFrom(
        start + Offset(size.width * 0.1, size.height / 2),
        Offset(size.width * 0.6, 0),
        const Duration(milliseconds: 250),
      );
      await tester.pump();

      expect(sought, isNotNull);
      expect(
        sought!.inMilliseconds,
        greaterThan(enginePosition.inMilliseconds),
      );
      // Label must have left the frozen engine time while (or after) the drag.
      expect(find.text('0:10'), findsNothing);
      final label = tester.widget<Text>(
        find.byKey(const ValueKey('scrub-preview-label')),
      );
      expect(label.data, isNot(equals('0:10')));
      expect(tester.takeException(), isNull);

      await _unmountAndFlush(tester);
    },
  );

  testWidgets('vinyl style renders the record art on phone and desktop', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_testTrack, queue: const [_testTrack]);

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(playback: playback)),
    );
    await tester.pump();
    final classicTitle = tester.getRect(
      find.byKey(const ValueKey('now-playing-track-title')),
    );
    final classicControls = tester.getRect(
      find.byKey(const ValueKey('compact-playback-controls')),
    );
    final classicActions = tester.getRect(
      find.byKey(const ValueKey('compact-now-playing-title-actions')),
    );
    final classicStage = tester.getRect(
      find.byKey(const ValueKey('compact-visual-stage')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingScreen(
          playback: playback,
          style: NowPlayingStyle.vinyl,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('vinyl-record-art')), findsOneWidget);
    final vinylDisc = tester.getRect(
      find.byKey(const ValueKey('vinyl-record-disc')),
    );
    final vinylTitle = tester.getRect(
      find.byKey(const ValueKey('now-playing-track-title')),
    );
    final vinylControls = tester.getRect(
      find.byKey(const ValueKey('compact-playback-controls')),
    );
    final vinylActions = tester.getRect(
      find.byKey(const ValueKey('compact-now-playing-title-actions')),
    );
    final vinylStage = tester.getRect(
      find.byKey(const ValueKey('compact-visual-stage')),
    );
    expect(vinylDisc.center.dx, closeTo(vinylStage.center.dx, 0.5));
    expect(vinylStage, classicStage);
    expect(vinylTitle.left, closeTo(classicTitle.left, 0.5));
    expect(vinylTitle.right, closeTo(classicTitle.right, 0.5));
    expect(vinylControls.left, closeTo(classicControls.left, 0.5));
    expect(vinylControls.right, closeTo(classicControls.right, 0.5));
    expect(vinylActions.left, closeTo(classicActions.left, 0.5));
    expect(vinylActions.right, closeTo(classicActions.right, 0.5));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1100, 800);
    await tester.pump();

    expect(find.byKey(const ValueKey('vinyl-record-art')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wide-now-playing-lyrics')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
  });

  testWidgets('vinyl disc spins while playing and freezes on pause', (
    tester,
  ) async {
    final album = albumForTrack(_testTrack);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VinylRecordArt(album: album, isPlaying: true, size: 240),
          ),
        ),
      ),
    );
    await tester.pump();

    final spinning = tester.state<VinylRecordArtState>(
      find.byType(VinylRecordArt),
    );
    expect(spinning.isDiscSpinning, isTrue);

    await tester.pump(const Duration(seconds: 2));
    final turnsWhilePlaying = spinning.discTurns;
    expect(turnsWhilePlaying, greaterThan(0));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VinylRecordArt(album: album, isPlaying: false, size: 240),
          ),
        ),
      ),
    );
    await tester.pump();

    final paused = tester.state<VinylRecordArtState>(
      find.byType(VinylRecordArt),
    );
    expect(paused.isDiscSpinning, isFalse);
    final frozenTurns = paused.discTurns;
    expect(frozenTurns, closeTo(turnsWhilePlaying, 0.001));

    await tester.pump(const Duration(seconds: 2));
    expect(paused.discTurns, closeTo(frozenTurns, 0.001));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VinylRecordArt(album: album, isPlaying: true, size: 240),
          ),
        ),
      ),
    );
    await tester.pump();

    final resumed = tester.state<VinylRecordArtState>(
      find.byType(VinylRecordArt),
    );
    expect(resumed.isDiscSpinning, isTrue);
    expect(resumed.discTurns, closeTo(frozenTurns, 0.001));

    await _unmountAndFlush(tester);
  });

  testWidgets('vinyl freezes spin when inactive without requiring pause', (
    tester,
  ) async {
    final album = albumForTrack(_testTrack);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VinylRecordArt(
              album: album,
              isPlaying: true,
              isActive: true,
              size: 240,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final active = tester.state<VinylRecordArtState>(
      find.byType(VinylRecordArt),
    );
    expect(active.isDiscSpinning, isTrue);
    final turnsAtDeactivate = active.discTurns;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VinylRecordArt(
              album: album,
              isPlaying: true,
              isActive: false,
              size: 240,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final inactive = tester.state<VinylRecordArtState>(
      find.byType(VinylRecordArt),
    );
    expect(inactive.isDiscSpinning, isFalse);
    expect(inactive.discTurns, closeTo(turnsAtDeactivate, 0.001));

    await tester.pump(const Duration(seconds: 2));
    expect(inactive.discTurns, closeTo(turnsAtDeactivate, 0.001));

    await _unmountAndFlush(tester);
  });

  testWidgets('vinyl does not spin when reduced motion is enabled', (
    tester,
  ) async {
    final album = albumForTrack(_testTrack);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: VinylRecordArt(album: album, isPlaying: true, size: 240),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final state = tester.state<VinylRecordArtState>(
      find.byType(VinylRecordArt),
    );
    expect(state.isDiscSpinning, isFalse);
    expect(state.discTurns, 0);

    await tester.pump(const Duration(seconds: 2));
    expect(state.isDiscSpinning, isFalse);
    expect(state.discTurns, 0);

    await _unmountAndFlush(tester);
  });

  testWidgets('vinyl now-playing freezes spin when surface is inactive', (
    tester,
  ) async {
    _simulatePlatform(TargetPlatform.iOS);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(_testTrack, queue: const [_testTrack]);

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingScreen(
          playback: playback,
          style: NowPlayingStyle.vinyl,
          isActive: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final active = tester.state<VinylRecordArtState>(
      find.byType(VinylRecordArt),
    );
    expect(active.isDiscSpinning, isTrue);
    final turnsWhenActive = active.discTurns;

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingScreen(
          playback: playback,
          style: NowPlayingStyle.vinyl,
          isActive: false,
        ),
      ),
    );
    await tester.pump();

    final inactive = tester.state<VinylRecordArtState>(
      find.byType(VinylRecordArt),
    );
    expect(inactive.isDiscSpinning, isFalse);
    expect(inactive.discTurns, closeTo(turnsWhenActive, 0.001));

    await tester.pump(const Duration(seconds: 1));
    expect(inactive.discTurns, closeTo(turnsWhenActive, 0.001));
    // Playback itself is still running; only the surface animation freezes.
    expect(playback.snapshot.isPlaying, isTrue);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
  });

  testWidgets('tapping a synchronized lyric seeks immediately', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const track = Track(
      id: 'track:lyrics',
      title: 'Lyrics Track',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 1),
      source: SourceKind.local,
      mediaUri: 'file:///test/lyrics.flac',
      lyrics: [
        LyricLine(Duration(seconds: 2), 'First lyric'),
        LyricLine(Duration(seconds: 10), 'Second lyric'),
        LyricLine(Duration(seconds: 20), 'Third lyric'),
      ],
    );
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(track, queue: const [track]);

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(playback: playback)),
    );
    await tester.pump();
    await tester.tap(find.text('Second lyric'));
    await tester.pump();

    expect(engine.current.position, const Duration(seconds: 10));
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
  });

  testWidgets('wide synchronized lyrics start slightly above center', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const track = Track(
      id: 'track:lyrics-opening',
      title: 'Opening Lyrics Track',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 1),
      source: SourceKind.local,
      mediaUri: 'file:///test/lyrics-opening.flac',
      lyrics: [
        LyricLine(Duration(seconds: 2), 'Opening first lyric'),
        LyricLine(Duration(seconds: 10), 'Opening second lyric'),
      ],
    );
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(track, queue: const [track]);

    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(playback: playback)),
    );
    await tester.pump();

    final panelTop = tester
        .getTopLeft(find.byKey(const ValueKey('wide-now-playing-lyrics')))
        .dy;
    final panelHeight = tester
        .getSize(find.byKey(const ValueKey('wide-now-playing-lyrics')))
        .height;
    final firstLyricTop = tester
        .getTopLeft(find.text('Opening first lyric'))
        .dy;
    expect(
      firstLyricTop - panelTop,
      inInclusiveRange(panelHeight * 0.30, panelHeight * 0.45),
      reason: 'The opening lyric should sit above center without touching top.',
    );
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
  });

  testWidgets('progress-bar seek and lyric selection share one timeline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const track = Track(
      id: 'track:progress-lyrics',
      title: 'Timeline Track',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 1),
      source: SourceKind.local,
      mediaUri: 'file:///test/timeline.flac',
      lyrics: [
        LyricLine(Duration.zero, '作词：Author'),
        LyricLine(Duration(seconds: 10), 'Opening lyric'),
        LyricLine(Duration(seconds: 20), 'Middle lyric'),
        LyricLine(Duration(seconds: 45), 'Closing lyric'),
      ],
    );
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(track, queue: const [track]);
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(playback: playback)),
    );
    await tester.pump();

    final scrubRect = tester.getRect(
      find.byKey(const ValueKey('progress-scrubber-hit-target')),
    );
    await tester.tapAt(scrubRect.center);
    await tester.pump();

    expect(
      engine.current.position.inMilliseconds,
      inInclusiveRange(29000, 31000),
    );
    final activeStyle = tester.widget<AnimatedDefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Middle lyric'),
            matching: find.byType(AnimatedDefaultTextStyle),
          )
          .first,
    );
    final sourceTextStyle = tester.widget<AnimatedDefaultTextStyle>(
      find
          .ancestor(
            of: find.text('作词：Author'),
            matching: find.byType(AnimatedDefaultTextStyle),
          )
          .first,
    );
    expect(activeStyle.style.fontSize, 22);
    expect(sourceTextStyle.style.fontSize, 20);
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
  });

  testWidgets('equal-timestamp lyric lines highlight as one cue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const track = Track(
      id: 'track:parallel-lyrics',
      title: 'Parallel Lyrics',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 1),
      source: SourceKind.local,
      mediaUri: 'file:///test/parallel.flac',
      lyrics: [
        LyricLine(Duration(seconds: 5), 'Original line'),
        LyricLine(Duration(seconds: 5), 'Translated line'),
        LyricLine(Duration(seconds: 10), 'Next line'),
      ],
    );
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);
    await playback.playTrack(track, queue: const [track]);
    await playback.seek(const Duration(seconds: 5));
    await tester.pumpWidget(
      MaterialApp(home: NowPlayingScreen(playback: playback)),
    );
    await tester.pump();

    for (final text in ['Original line', 'Translated line']) {
      final style = tester.widget<AnimatedDefaultTextStyle>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      );
      expect(style.style.fontSize, 22);
    }
    expect(tester.takeException(), isNull);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
  });
}

void _simulatePlatform(TargetPlatform platform) {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
}

Future<void> _unmountAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  debugDefaultTargetPlatformOverride = null;
}

DriftLibraryRepository _repository() {
  return DriftLibraryRepository(LibraryDatabase(NativeDatabase.memory()));
}

Future<DriftLibraryRepository> _repositoryWithAlbum({
  bool includeSecondTrack = false,
  int extraAlbumCount = 0,
}) async {
  final repository = _repository();
  final now = DateTime.utc(2026, 7, 11);
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
      albums: [
        const LibraryAlbumRecord(
          id: 'album:test',
          sourceId: sourceId,
          title: 'Test Album',
          sortTitle: 'test album',
          albumArtist: 'Test Artist',
          artistId: 'artist:test',
          year: 2026,
          genre: 'Test',
        ),
        for (var index = 0; index < extraAlbumCount; index++)
          LibraryAlbumRecord(
            id: 'album:extra:$index',
            sourceId: sourceId,
            title: 'Extra Album $index',
            sortTitle: 'extra album $index',
            albumArtist: 'Test Artist',
            artistId: 'artist:test',
            year: 2026,
            genre: 'Test',
          ),
      ],
      tracks: [
        LibraryTrackRecord(
          id: _testTrack.id,
          sourceId: sourceId,
          albumId: 'album:test',
          artistId: 'artist:test',
          relativePath: 'test.flac',
          mediaUri: _testTrack.mediaUri!,
          title: _testTrack.title,
          artistName: _testTrack.artist,
          albumTitle: _testTrack.albumTitle,
          durationMs: _testTrack.duration.inMilliseconds,
          trackNumber: 1,
          modifiedAt: now,
        ),
        if (includeSecondTrack)
          LibraryTrackRecord(
            id: _secondTestTrack.id,
            sourceId: sourceId,
            albumId: 'album:test',
            artistId: 'artist:test',
            relativePath: 'second.flac',
            mediaUri: _secondTestTrack.mediaUri!,
            title: _secondTestTrack.title,
            artistName: _secondTestTrack.artist,
            albumTitle: _secondTestTrack.albumTitle,
            durationMs: _secondTestTrack.duration.inMilliseconds,
            trackNumber: 2,
            modifiedAt: now,
          ),
        for (var index = 0; index < extraAlbumCount; index++)
          LibraryTrackRecord(
            id: 'track:extra:$index',
            sourceId: sourceId,
            albumId: 'album:extra:$index',
            artistId: 'artist:test',
            relativePath: 'extra-$index.flac',
            mediaUri: 'file:///test/extra-$index.flac',
            title: 'Extra Track $index',
            artistName: 'Test Artist',
            albumTitle: 'Extra Album $index',
            durationMs: const Duration(minutes: 3).inMilliseconds,
            trackNumber: 1,
            modifiedAt: now,
          ),
      ],
    ),
  );
  return repository;
}

Future<DriftLibraryRepository> _repositoryWithFastIndexTracks() async {
  final repository = _repository();
  final now = DateTime.utc(2026, 7, 17);
  const sourceId = 'local:fast-index';
  const albumId = 'album:fast-index';
  const artistId = 'artist:fast-index';
  await repository.upsertSource(
    LibrarySourceRecord(
      id: sourceId,
      type: LibrarySourceType.local,
      displayName: 'Fast Index Music',
      rootUri: 'file:///fast-index/',
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
          id: artistId,
          sourceId: sourceId,
          name: 'Index Artist',
          sortName: 'index artist',
        ),
      ],
      albums: const [
        LibraryAlbumRecord(
          id: albumId,
          sourceId: sourceId,
          title: 'Index Album',
          sortTitle: 'index album',
          albumArtist: 'Index Artist',
          artistId: artistId,
        ),
      ],
      tracks: [
        for (var index = 0; index < 30; index++)
          LibraryTrackRecord(
            id: 'track:index:$index',
            sourceId: sourceId,
            albumId: albumId,
            artistId: artistId,
            relativePath: 'track-$index.flac',
            mediaUri: 'file:///fast-index/track-$index.flac',
            title: index < 10
                ? 'Apple ${index.toString().padLeft(2, '0')}'
                : index < 20
                ? '陶喆 ${index.toString().padLeft(2, '0')}'
                : 'Zulu ${index.toString().padLeft(2, '0')}',
            artistName: 'Index Artist',
            albumTitle: 'Index Album',
            durationMs: const Duration(minutes: 3).inMilliseconds,
            trackNumber: index + 1,
            year: index < 10
                ? 2026
                : index < 20
                ? 2018
                : 2010,
            modifiedAt: now,
          ),
      ],
    ),
  );
  return repository;
}

const _testTrack = Track(
  id: 'track:test',
  title: 'Test Track',
  artist: 'Test Artist',
  albumTitle: 'Test Album',
  duration: Duration(minutes: 3),
  source: SourceKind.local,
  mediaUri: 'file:///test/test.flac',
);

const _secondTestTrack = Track(
  id: 'track:second',
  title: 'Second Track',
  artist: 'Test Artist',
  albumTitle: 'Test Album',
  duration: Duration(minutes: 4),
  trackNumber: 2,
  source: SourceKind.local,
  mediaUri: 'file:///test/second.flac',
);
