import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/presentation/widgets/album_art.dart';

void main() {
  late Directory directory;
  late File artwork;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('sound-art-test-');
    artwork = File('${directory.path}/cover.png');
    await artwork.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
      ),
    );
  });

  tearDownAll(() async {
    await directory.delete(recursive: true);
  });

  testWidgets('decodes artwork in shared physical-pixel size buckets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    final album = Album(
      id: 'album',
      title: 'Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: const [Colors.indigo, Colors.black],
      tracks: const [],
      artworkUri: artwork.uri.toString(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            SizedBox.square(dimension: 48, child: AlbumArt(album: album)),
            SizedBox.square(dimension: 52, child: AlbumArt(album: album)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final providers = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .toList(growable: false);
    expect(providers, hasLength(2));
    for (final provider in providers) {
      expect(provider, isA<ResizeImage>());
      final resized = provider as ResizeImage;
      expect(resized.width, 128);
      expect(resized.height, 128);
      expect(resized.policy, ResizeImagePolicy.fit);
    }
    expect(providers.first, providers.last);
  });
}
