import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/library/scanning/album_artist_resolver.dart';

void main() {
  test('uses the majority track artist as the album artist', () {
    final resolver = AlbumArtistResolver()
      ..add('周杰伦')
      ..add('周杰伦')
      ..add('周杰伦&费玉清');

    expect(resolver.resolve(), '周杰伦');
  });

  test('finds a shared lead artist when collaboration counts tie', () {
    final resolver = AlbumArtistResolver()
      ..add('周杰伦&费玉清')
      ..add('周杰伦/潘儿');

    expect(resolver.resolve(), '周杰伦');
  });

  test('uses various artists when unrelated performers tie', () {
    final resolver = AlbumArtistResolver()
      ..add('Artist One')
      ..add('Artist Two');

    expect(resolver.resolve(), '群星');
  });

  test('prefers an explicit album artist over participating artists', () {
    final resolver = AlbumArtistResolver()
      ..add('Lead Artist')
      ..add('Guest Artist')
      ..addAlbumArtist('Official Album Artist');

    expect(resolver.resolve(), 'Official Album Artist');
  });

  test('marks an untagged multi-artist compilation as various artists', () {
    final resolver = AlbumArtistResolver()
      ..add('Artist One')
      ..markCompilation();

    expect(resolver.resolve(), '群星');
  });
}
