import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/library/scanning/platform_channel_local_media_catalog.dart';

void main() {
  test('maps SAF listings and releases prepared metadata files', () async {
    final calls = <String>[];
    final catalog = PlatformChannelLocalMediaCatalog(
      invoker: (method, arguments) async {
        calls.add(method);
        return switch (method) {
          'listAudioFiles' => <Object?>[
            <Object?, Object?>{
              'relativePath': 'Album/Track.flac',
              'mediaUri': 'content://provider/track',
              'modifiedAtMs': 1000,
              'contentType': 'audio/flac',
              'fileSize': 42,
            },
          ],
          'prepareAudioFile' => '${Directory.systemTemp.path}/track.flac',
          'releasePreparedAudioFile' => null,
          _ => throw StateError(method),
        };
      },
    );

    final files = await catalog.listAudioFiles('content://provider/tree');
    expect(files.single.relativePath, 'Album/Track.flac');
    expect(
      files.single.modifiedAt,
      DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
    expect(files.single.fileSize, 42);

    final prepared = await catalog.prepareForMetadata(files.single);
    expect(prepared.file.path, endsWith('track.flac'));
    await prepared.release();
    await prepared.release();

    expect(calls, [
      'listAudioFiles',
      'prepareAudioFile',
      'releasePreparedAudioFile',
    ]);
  });
}
