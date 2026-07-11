import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/app/sound_app.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/library/library_records.dart';
import 'package:sound_player/library/persistence/drift_library_repository.dart';
import 'package:sound_player/library/persistence/library_database.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/simulated_playback_engine.dart';
import 'package:sound_player/presentation/app_shell.dart';
import 'package:sound_player/presentation/widgets/mini_player.dart';

void main() {
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
      SoundApp(engine: SimulatedPlaybackEngine(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('资料库'), findsWidgets);
    expect(find.text('Test Album'), findsWidgets);
    expect(find.text('Test Track'), findsOneWidget);
    expect(find.text('范特西'), findsNothing);

    final libraryTrack = find.ancestor(
      of: find.text('Test Track'),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(libraryTrack);
    await tester.tap(libraryTrack);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 首歌'), findsOneWidget);

    await tester.tap(find.text('Test Track'));
    await tester.pump();
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);

    await _unmountAndFlush(tester);
  });

  testWidgets('empty repository presents a source-management action', (
    tester,
  ) async {
    final repository = _repository();
    addTearDown(repository.close);

    await tester.pumpWidget(
      SoundApp(engine: SimulatedPlaybackEngine(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('资料库还是空的'), findsOneWidget);
    expect(find.text('管理音乐来源'), findsOneWidget);

    await _unmountAndFlush(tester);
  });

  testWidgets('compact mini player sits just above bottom navigation', (
    tester,
  ) async {
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
    final navigationTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
    expect(navigationTop - miniPlayerBottom, 10);

    await _unmountAndFlush(tester);
    playback.dispose();
    engine.dispose();
    await repository.close();
  });
}

Future<void> _unmountAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

DriftLibraryRepository _repository() {
  return DriftLibraryRepository(LibraryDatabase(NativeDatabase.memory()));
}

Future<DriftLibraryRepository> _repositoryWithAlbum() async {
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
      albums: const [
        LibraryAlbumRecord(
          id: 'album:test',
          sourceId: sourceId,
          title: 'Test Album',
          sortTitle: 'test album',
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
