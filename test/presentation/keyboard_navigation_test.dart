import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/app/sound_app.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/library/persistence/drift_library_repository.dart';
import 'package:kaiting/library/persistence/library_database.dart';
import 'package:kaiting/playback/playback_session.dart';
import 'package:kaiting/playback/simulated_playback_engine.dart';
import 'package:kaiting/presentation/app_shell.dart';
import 'package:kaiting/presentation/screens/album_detail_screen.dart';
import 'package:kaiting/presentation/screens/now_playing_screen.dart';

void main() {
  testWidgets('global shortcuts control playback and switch primary pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithTwoTracks();
    final engine = SimulatedPlaybackEngine();
    final sessionStore = PlaybackSessionStore.memory();
    await sessionStore.save(
      const PlaybackSession(
        queue: [_firstTrack, _secondTrack],
        queueIndex: 0,
        positionMs: 0,
      ),
    );
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: engine,
        repository: repository,
        sessionStore: sessionStore,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(engine.current.track?.id, _firstTrack.id);
    expect(engine.current.isPlaying, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(engine.current.isPlaying, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(engine.current.isPlaying, isTrue);
    expect(
      find.byKey(const ValueKey('library-search-field')),
      findsNothing,
      reason: 'Space must not activate the currently focused sidebar item.',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(engine.current.isPlaying, isFalse);

    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.arrowRight);
    expect(engine.current.track?.id, _secondTrack.id);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(engine.current.isPlaying, isFalse);

    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.keyF);
    final searchField = find.byKey(const ValueKey('library-search-field'));
    expect(searchField, findsOneWidget);
    expect(tester.widget<TextField>(searchField).focusNode?.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(engine.current.isPlaying, isFalse);

    await tester.enterText(searchField, 'Test');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(searchField).controller?.text, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(searchField, findsNothing);
    expect(find.text('Test Album'), findsWidgets);

    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.digit3);
    expect(find.byKey(const ValueKey('settings-overview')), findsOneWidget);
    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.digit1);
    expect(find.text('Test Album'), findsWidgets);

    await tester.tap(find.text('Second Track').last);
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingScreen), findsNothing);

    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.slash);
    expect(find.text('键盘快捷键'), findsOneWidget);
    final shortcutDialog = tester.getRect(
      find.byKey(const ValueKey('sound-dialog')),
    );
    expect(shortcutDialog.width, 520);
    expect(shortcutDialog.height, lessThan(752));
    expect(shortcutDialog.top, greaterThanOrEqualTo(24));
    expect(
      tester.getTopLeft(find.text('⌘/Ctrl + ← / →')).dy -
          tester.getTopLeft(find.text('空格')).dy,
      lessThan(50),
      reason: 'Shortcut rows must stay compact instead of filling the dialog.',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('键盘快捷键'), findsNothing);

    await _unmountAndFlush(tester);
  });

  testWidgets('tab, arrows, enter, and escape complete navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await _repositoryWithTwoTracks();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(
        engine: SimulatedPlaybackEngine(),
        repository: repository,
        sessionStore: PlaybackSessionStore.memory(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final firstFocus = FocusManager.instance.primaryFocus;
    expect(firstFocus, isNotNull);
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-search-field')), findsOneWidget);

    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.digit1);
    final focusBeforeArrow = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(focusBeforeArrow));

    final theme = Theme.of(tester.element(find.byType(AppShell)));
    expect(theme.focusColor, SoundTheme.light.focusColor);
    final focusSide = theme.iconButtonTheme.style?.side?.resolve({
      WidgetState.focused,
    });
    expect(focusSide?.color, SoundColors.accent);
    expect(focusSide?.width, 2);

    await tester.tap(find.text('Test Album').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlbumDetailScreen), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlbumDetailScreen), findsNothing);

    await _unmountAndFlush(tester);
  });
}

Future<void> _sendPrimaryShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _unmountAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<DriftLibraryRepository> _repositoryWithTwoTracks() async {
  final repository = DriftLibraryRepository(
    LibraryDatabase(NativeDatabase.memory()),
  );
  final now = DateTime.utc(2026, 7, 13);
  const sourceId = 'local:keyboard';
  await repository.upsertSource(
    LibrarySourceRecord(
      id: sourceId,
      type: LibrarySourceType.local,
      displayName: 'Keyboard Test Music',
      rootUri: 'file:///keyboard/',
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
          id: 'artist:keyboard',
          sourceId: sourceId,
          name: 'Test Artist',
          sortName: 'test artist',
        ),
      ],
      albums: const [
        LibraryAlbumRecord(
          id: 'album:keyboard',
          sourceId: sourceId,
          title: 'Test Album',
          sortTitle: 'test album',
          albumArtist: 'Test Artist',
          artistId: 'artist:keyboard',
        ),
      ],
      tracks: [
        _trackRecord(_firstTrack, sourceId, 1),
        _trackRecord(_secondTrack, sourceId, 2),
      ],
    ),
  );
  return repository;
}

LibraryTrackRecord _trackRecord(Track track, String sourceId, int number) {
  return LibraryTrackRecord(
    id: track.id,
    sourceId: sourceId,
    albumId: 'album:keyboard',
    artistId: 'artist:keyboard',
    relativePath: '$number.flac',
    mediaUri: track.mediaUri!,
    title: track.title,
    artistName: track.artist,
    albumTitle: track.albumTitle,
    durationMs: track.duration.inMilliseconds,
    trackNumber: number,
    modifiedAt: DateTime.utc(2026, 7, 13),
  );
}

const _firstTrack = Track(
  id: 'track:keyboard:first',
  title: 'First Track',
  artist: 'Test Artist',
  albumTitle: 'Test Album',
  duration: Duration(minutes: 3),
  source: SourceKind.local,
  mediaUri: 'file:///keyboard/1.flac',
);

const _secondTrack = Track(
  id: 'track:keyboard:second',
  title: 'Second Track',
  artist: 'Test Artist',
  albumTitle: 'Test Album',
  duration: Duration(minutes: 4),
  trackNumber: 2,
  source: SourceKind.local,
  mediaUri: 'file:///keyboard/2.flac',
);
