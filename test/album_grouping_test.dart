import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/library/scanning/album_grouping.dart';

void main() {
  test('keeps disc folders inside one release identity', () {
    final discOne = stableGroupedAlbumId(
      sourceId: 'local:music',
      albumTitle: 'The Complete Sessions',
      albumArtist: 'Main Artist',
      relativePath: 'Main Artist/The Complete Sessions/CD 1/01.flac',
      discNumber: 1,
    );
    final discTwo = stableGroupedAlbumId(
      sourceId: 'local:music',
      albumTitle: 'The Complete Sessions',
      relativePath: 'Main Artist/The Complete Sessions/Disc 2/01.flac',
      discNumber: 2,
    );

    expect(discTwo, discOne);
  });

  test('separates same-title releases by album artist and release folder', () {
    final first = stableGroupedAlbumId(
      sourceId: 'local:music',
      albumTitle: 'Greatest Hits',
      albumArtist: 'Artist One',
      relativePath: 'Artist One/Greatest Hits/01.flac',
    );
    final second = stableGroupedAlbumId(
      sourceId: 'local:music',
      albumTitle: 'Greatest Hits',
      albumArtist: 'Artist Two',
      relativePath: 'Artist Two/Greatest Hits/01.flac',
    );

    expect(second, isNot(first));
  });

  test('does not treat an unrelated child folder as another release', () {
    final rootTrack = stableGroupedAlbumId(
      sourceId: 'local:music',
      albumTitle: 'One Album',
      relativePath: '01.flac',
    );
    final nestedTrack = stableGroupedAlbumId(
      sourceId: 'local:music',
      albumTitle: 'One Album',
      relativePath: 'extras/02.flac',
    );

    expect(nestedTrack, rootTrack);
  });

  test('compilation identity ignores participating track artists', () {
    final first = stableGroupedAlbumId(
      sourceId: 'webdav:music',
      albumTitle: 'Festival Collection',
      isCompilation: true,
      relativePath: '/music/Festival Collection/01.mp3',
    );
    final second = stableGroupedAlbumId(
      sourceId: 'webdav:music',
      albumTitle: 'Festival Collection',
      isCompilation: true,
      relativePath: '/music/Festival Collection/02.mp3',
    );

    expect(second, first);
  });
}
