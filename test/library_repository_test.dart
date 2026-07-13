import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/library/library_records.dart';
import 'package:sound_player/library/persistence/drift_library_repository.dart';
import 'package:sound_player/library/persistence/library_database.dart';

void main() {
  late Directory temporaryDirectory;
  late File databaseFile;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'sound-library-test-',
    );
    databaseFile = File('${temporaryDirectory.path}/library.sqlite');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('persists a complete source scan after closing and reopening', () async {
    final createdAt = DateTime.utc(2026, 7, 11, 10);
    var repository = _openRepository(databaseFile);
    await repository.upsertSource(
      _source(createdAt, permissionBookmark: Uint8List.fromList([1, 3, 5, 7])),
    );
    await repository.markSourceScanning(
      'source-local',
      startedAt: createdAt.add(const Duration(minutes: 1)),
    );
    await repository.replaceSourceScan(
      _scan(
        completedAt: createdAt.add(const Duration(minutes: 2)),
        tracks: [_track('track-one', '01-one.flac', title: 'One')],
        lyrics: const [
          LibraryLyricRecord(
            trackId: 'track-one',
            sequence: 0,
            timestampMs: 1200,
            text: 'First line',
          ),
          LibraryLyricRecord(
            trackId: 'track-one',
            sequence: 1,
            timestampMs: 4600,
            text: 'Second line',
          ),
        ],
      ),
    );
    await repository.close();

    repository = _openRepository(databaseFile);
    final source = await repository.getSource('source-local');
    final artists = await repository.getArtists(sourceId: 'source-local');
    final albums = await repository.getAlbums(sourceId: 'source-local');
    final tracks = await repository.getTracks(sourceId: 'source-local');
    final lyrics = await repository.getLyrics('track-one');

    expect(source, isNotNull);
    expect(source!.status, LibrarySourceStatus.available);
    expect(source.scanRevision, 1);
    expect(source.lastScanStartedAt, createdAt.add(const Duration(minutes: 1)));
    expect(source.lastError, isNull);
    expect(source.permissionBookmark, [1, 3, 5, 7]);
    expect(artists.single.name, 'First Artist');
    expect(albums.single.title, 'First Album');
    expect(tracks.single.title, 'One');
    expect(tracks.single.durationMs, 223190);
    expect(lyrics.map((line) => line.text), ['First line', 'Second line']);

    await repository.deleteSource('source-local');
    expect(await repository.getTracks(sourceId: 'source-local'), isEmpty);
    expect(await repository.getAlbums(sourceId: 'source-local'), isEmpty);
    await repository.close();
  });

  test(
    'replaces missing rows atomically and rolls back a failed scan',
    () async {
      final createdAt = DateTime.utc(2026, 7, 11, 11);
      final repository = _openRepository(databaseFile);
      await repository.upsertSource(_source(createdAt));
      await repository.replaceSourceScan(
        _scan(
          completedAt: createdAt.add(const Duration(minutes: 1)),
          tracks: [
            _track('track-one', '01-one.mp3', title: 'One'),
            _track('track-two', '02-two.mp3', title: 'Two'),
          ],
        ),
      );

      await repository.replaceSourceScan(
        _scan(
          completedAt: createdAt.add(const Duration(minutes: 2)),
          tracks: [_track('track-two', '02-two.mp3', title: 'Two updated')],
          lyrics: const [
            LibraryLyricRecord(
              trackId: 'track-two',
              sequence: 0,
              timestampMs: 1000,
              text: 'Committed line',
            ),
          ],
        ),
      );

      var tracks = await repository.getTracks(sourceId: 'source-local');
      expect(tracks.map((track) => track.id), ['track-two']);
      expect(tracks.single.title, 'Two updated');
      expect((await repository.getSource('source-local'))!.scanRevision, 2);

      final failedScan = _scan(
        completedAt: createdAt.add(const Duration(minutes: 3)),
        tracks: [_track('track-two', '02-two.mp3', title: 'Must roll back')],
        lyrics: const [
          LibraryLyricRecord(
            trackId: 'track-two',
            sequence: 0,
            timestampMs: 2000,
            text: 'Duplicate A',
          ),
          LibraryLyricRecord(
            trackId: 'track-two',
            sequence: 0,
            timestampMs: 3000,
            text: 'Duplicate B',
          ),
        ],
      );
      await expectLater(
        repository.replaceSourceScan(failedScan),
        throwsA(anything),
      );

      tracks = await repository.getTracks(sourceId: 'source-local');
      final lyrics = await repository.getLyrics('track-two');
      final source = await repository.getSource('source-local');
      expect(tracks.single.title, 'Two updated');
      expect(lyrics.single.text, 'Committed line');
      expect(source!.scanRevision, 2);
      await repository.close();
    },
  );

  test('replaces legacy semantic rows when generated IDs change', () async {
    final createdAt = DateTime.utc(2026, 7, 13, 9);
    final repository = _openRepository(databaseFile);
    await repository.upsertSource(_source(createdAt));
    await repository.replaceSourceScan(
      _identityScan('legacy', createdAt.add(const Duration(minutes: 1))),
    );

    await repository.replaceSourceScan(
      _identityScan('current', createdAt.add(const Duration(minutes: 2))),
    );

    final artists = await repository.getArtists(sourceId: 'source-local');
    final albums = await repository.getAlbums(sourceId: 'source-local');
    final tracks = await repository.getTracks(sourceId: 'source-local');
    expect(artists.single.id, 'artist-current');
    expect(albums.single.id, 'album-current');
    expect(tracks.single.id, 'track-current');
    expect(tracks.single.artistId, 'artist-current');
    expect(tracks.single.albumId, 'album-current');
    expect((await repository.getSource('source-local'))?.scanRevision, 2);
    await repository.close();
  });
}

DriftLibraryRepository _openRepository(File file) {
  return DriftLibraryRepository(LibraryDatabase(NativeDatabase(file)));
}

LibrarySourceRecord _source(
  DateTime createdAt, {
  Uint8List? permissionBookmark,
}) {
  return LibrarySourceRecord(
    id: 'source-local',
    type: LibrarySourceType.local,
    displayName: 'Local music',
    rootUri: 'file:///music',
    permissionBookmark: permissionBookmark,
    status: LibrarySourceStatus.idle,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

LibraryScanBatch _scan({
  required DateTime completedAt,
  required List<LibraryTrackRecord> tracks,
  List<LibraryLyricRecord> lyrics = const [],
}) {
  return LibraryScanBatch(
    sourceId: 'source-local',
    completedAt: completedAt,
    artists: const [
      LibraryArtistRecord(
        id: 'artist-one',
        sourceId: 'source-local',
        name: 'First Artist',
        sortName: 'first artist',
      ),
    ],
    albums: const [
      LibraryAlbumRecord(
        id: 'album-one',
        sourceId: 'source-local',
        artistId: 'artist-one',
        title: 'First Album',
        sortTitle: 'first album',
        albumArtist: 'First Artist',
        year: 2026,
        genre: 'Test',
      ),
    ],
    tracks: tracks,
    lyrics: lyrics,
  );
}

LibraryTrackRecord _track(
  String id,
  String relativePath, {
  required String title,
}) {
  return LibraryTrackRecord(
    id: id,
    sourceId: 'source-local',
    albumId: 'album-one',
    artistId: 'artist-one',
    relativePath: relativePath,
    mediaUri: 'file:///music/$relativePath',
    title: title,
    artistName: 'First Artist',
    albumTitle: 'First Album',
    durationMs: 223190,
    trackNumber: 1,
    discNumber: 1,
    contentType: 'audio/mpeg',
    fileSize: 9218085,
    modifiedAt: DateTime.utc(2026, 7, 10),
  );
}

LibraryScanBatch _identityScan(String identity, DateTime completedAt) {
  final artistId = 'artist-$identity';
  final albumId = 'album-$identity';
  final trackId = 'track-$identity';
  return LibraryScanBatch(
    sourceId: 'source-local',
    completedAt: completedAt,
    artists: [
      LibraryArtistRecord(
        id: artistId,
        sourceId: 'source-local',
        name: 'Same Artist',
        sortName: 'same artist',
      ),
    ],
    albums: [
      LibraryAlbumRecord(
        id: albumId,
        sourceId: 'source-local',
        artistId: artistId,
        title: 'Same Album',
        sortTitle: 'same album',
        albumArtist: 'Same Artist',
      ),
    ],
    tracks: [
      LibraryTrackRecord(
        id: trackId,
        sourceId: 'source-local',
        albumId: albumId,
        artistId: artistId,
        relativePath: 'same.mp3',
        mediaUri: 'file:///music/same.mp3',
        title: 'Same Track',
        artistName: 'Same Artist',
        albumTitle: 'Same Album',
        durationMs: 1000,
        modifiedAt: completedAt,
      ),
    ],
  );
}
