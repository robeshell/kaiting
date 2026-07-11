import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/library/library_records.dart';
import 'package:sound_player/presentation/controllers/library_catalog_controller.dart';

void main() {
  test(
    'maps persisted metadata and media resources into presentation models',
    () {
      final now = DateTime.utc(2026, 7, 11);
      final result = mapLibraryAlbums(
        sources: [
          LibrarySourceRecord(
            id: 'source:local',
            type: LibrarySourceType.local,
            displayName: 'Music',
            rootUri: 'file:///music/',
            status: LibrarySourceStatus.available,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        albums: const [
          LibraryAlbumRecord(
            id: 'album:real',
            sourceId: 'source:local',
            title: 'Indexed Album',
            sortTitle: 'indexed album',
            albumArtist: 'Indexed Artist',
            year: 2025,
            genre: 'Ambient',
            artworkKey: 'file:///cache/cover.jpg',
          ),
        ],
        tracks: [
          LibraryTrackRecord(
            id: 'track:real',
            sourceId: 'source:local',
            albumId: 'album:real',
            relativePath: 'album/song.flac',
            mediaUri: 'file:///music/album/song.flac',
            title: 'Indexed Track',
            artistName: 'Indexed Artist',
            albumTitle: 'Indexed Album',
            durationMs: 182000,
            trackNumber: 3,
            modifiedAt: now,
          ),
        ],
        lyricsByTrackId: const {
          'track:real': [
            LibraryLyricRecord(
              trackId: 'track:real',
              sequence: 0,
              timestampMs: 1200,
              text: 'A real lyric',
            ),
          ],
        },
      );

      expect(result, hasLength(1));
      final album = result.single;
      expect(album.title, 'Indexed Album');
      expect(album.source, SourceKind.local);
      expect(album.year, 2025);
      expect(album.genre, 'Ambient');
      expect(album.artworkUri, 'file:///cache/cover.jpg');

      final track = album.tracks.single;
      expect(track.mediaUri, 'file:///music/album/song.flac');
      expect(track.artworkUri, album.artworkUri);
      expect(track.year, album.year);
      expect(track.genre, album.genre);
      expect(track.lyrics.single.text, 'A real lyric');
      expect(track.lyrics.single.time, const Duration(milliseconds: 1200));
    },
  );

  test('omits empty albums instead of creating fake tracks', () {
    final result = mapLibraryAlbums(
      sources: const [],
      albums: const [
        LibraryAlbumRecord(
          id: 'album:empty',
          sourceId: 'source:missing',
          title: 'Empty Album',
          sortTitle: 'empty album',
          albumArtist: 'Unknown Artist',
        ),
      ],
      tracks: const [],
      lyricsByTrackId: const {},
    );

    expect(result, isEmpty);
  });
}
