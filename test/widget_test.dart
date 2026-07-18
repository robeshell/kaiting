import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/app/sound_app.dart';
import 'package:sound_player/core/sound_theme.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/library/library_records.dart';
import 'package:sound_player/library/persistence/drift_library_repository.dart';
import 'package:sound_player/library/persistence/library_database.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/playback_session.dart';
import 'package:sound_player/playback/simulated_playback_engine.dart';
import 'package:sound_player/presentation/app_shell.dart';
import 'package:sound_player/presentation/controllers/library_catalog_controller.dart';
import 'package:sound_player/presentation/screens/now_playing_screen.dart';
import 'package:sound_player/presentation/widgets/animated_artwork_background.dart';
import 'package:sound_player/presentation/widgets/mini_player.dart';
import 'package:sound_player/presentation/widgets/sound_components.dart';

void main() {
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

    expect(find.text('Reverie'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/branding/app_icon_master-v6.png')),
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
      BorderRadius.circular(6),
    );

    await tester.tap(find.text('Test Album').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 首歌'), findsOneWidget);

    await tester.tap(find.text('Test Track'));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.graphic_eq_rounded &&
            widget.size == 18,
      ),
      findsOneWidget,
    );

    await _unmountAndFlush(tester);
  });

  testWidgets(
    'library navigation is not repeated beside a persistent sidebar',
    (tester) async {
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

      expect(find.byKey(const ValueKey('library-mode-albums')), findsNothing);

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
      expect(compactDelegate.mainAxisExtent, lessThan(220));
      expect(compactDelegate.mainAxisSpacing, 12);

      await tester.tap(find.byKey(const ValueKey('library-mode-artists')));
      await tester.pumpAndSettle();
      final artistGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final artistDelegate =
          artistGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(artistDelegate.mainAxisExtent, lessThan(220));
      expect(artistDelegate.mainAxisSpacing, 12);

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
    },
  );

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
      inInclusiveRange(280, 420),
    );
    await tester.drag(
      find.byKey(const ValueKey('collection-detail-hero')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Track'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('library-collection-track-sort-menu')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('library-collection-track-sort-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('专辑与曲序'));
    await tester.pumpAndSettle();
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
      inInclusiveRange(204, 244),
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
    expect(compactCollectionDelegate.mainAxisExtent, lessThan(220));
    expect(compactCollectionDelegate.mainAxisSpacing, 12);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('collection-track-row-track:test')),
          )
          .height,
      64,
    );
    expect(
      find.byKey(const ValueKey('collection-track-actions-track:test')),
      findsOneWidget,
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

    await tester.tap(find.byTooltip('收藏歌曲'));
    await tester.pumpAndSettle();
    expect((await repository.getFavoriteTracks()).single.trackId, 'track:test');
    expect((await repository.getPlayHistory()).single.trackId, 'track:test');

    await tester.tap(find.text('收藏').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('user-library-track-favorites-track:test')),
      findsOneWidget,
    );

    await tester.tap(find.text('最近播放').first);
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

    await tester.tap(find.text('播放列表').first);
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

    await tester.drag(
      find.byIcon(Icons.drag_handle_rounded).first,
      const Offset(0, 80),
    );
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
    final restoredSlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const ValueKey('mini-player-progress')),
        matching: find.byType(Slider),
      ),
    );
    expect(restoredSlider.value, 60000);
    expect(restoredSlider.max, 180000);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

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
    final lyrics = find.byKey(const ValueKey('show-now-playing-lyrics'));
    final title = find.byKey(const ValueKey('now-playing-track-title'));
    final playbackControls = find.byKey(
      const ValueKey('compact-cover-playback-controls'),
    );
    final secondaryActions = find.byKey(
      const ValueKey('compact-now-playing-secondary-actions'),
    );
    final topActions = find.byKey(const ValueKey('now-playing-drag-handle'));
    final artwork = find.byKey(const ValueKey('compact-now-playing-artwork'));
    expect(tester.getSize(topActions).height, lessThan(72));
    expect(
      tester.getTopLeft(artwork).dy - tester.getBottomLeft(topActions).dy,
      lessThanOrEqualTo(10),
    );
    expect(tester.getSize(title).width, greaterThan(300));
    expect(
      tester.getTopLeft(secondaryActions).dy,
      greaterThan(tester.getBottomLeft(playbackControls).dy),
    );
    expect(
      tester.getCenter(lyrics).dx,
      lessThan(tester.getCenter(addToPlaylist).dx),
    );
    expect(
      tester.getCenter(addToPlaylist).dx,
      lessThan(tester.getCenter(favorite).dx),
    );
    expect(
      tester.getCenter(favorite).dx - tester.getCenter(lyrics).dx,
      greaterThan(250),
    );

    final coverLyricsCenter = tester.getCenter(lyrics);
    final coverFavoriteCenter = tester.getCenter(favorite);
    await tester.tap(lyrics);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final returnToCover = find.byKey(
      const ValueKey('return-now-playing-cover'),
    );
    expect(
      find.byKey(const ValueKey('compact-lyrics-secondary-actions')),
      findsOneWidget,
    );
    expect(
      tester.getCenter(returnToCover).dx,
      closeTo(coverLyricsCenter.dx, 1),
    );
    expect(tester.getCenter(favorite).dx, closeTo(coverFavoriteCenter.dx, 1));
    expect(
      (tester.getCenter(returnToCover).dy - coverLyricsCenter.dy).abs(),
      lessThan(80),
    );
    await tester.tap(returnToCover);
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
    await tester.pump();
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
    expect(progressRect.center.dy, closeTo(rect.top + 8, 0.1));
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

      expect(find.text('Reverie'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Reverie')).dy,
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

  testWidgets('shell adapts between full iPad and split-view widths', (
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

    expect(find.text('Reverie'), findsOneWidget);
    expect(find.byType(SoundNavigationBar), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(600, 1024);
    await tester.pumpAndSettle();

    expect(find.text('Reverie'), findsNothing);
    expect(find.byType(SoundNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsWidgets);
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
    expect(compactSettingsIcons, {Icons.chevron_right_rounded});

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
    expect(compactOptionIcons, {Icons.check_rounded});
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
    expect(find.byTooltip('查看歌词'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('查看歌词'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('这首歌曲没有内嵌歌词'), findsOneWidget);

    tester.view.physicalSize = const Size(834, 1194);
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

  testWidgets('synchronized lyrics start near the top before the first cue', (
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
    final firstLyricTop = tester
        .getTopLeft(find.text('Opening first lyric'))
        .dy;
    expect(
      firstLyricTop - panelTop,
      lessThan(100),
      reason: 'The lyric list should not reserve half a viewport above line 1.',
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

    final sliderRect = tester.getRect(find.byType(Slider));
    await tester.tapAt(sliderRect.center);
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
