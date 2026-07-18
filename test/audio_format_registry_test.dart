import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/library/scanning/audio_format_registry.dart';
import 'package:sound_player/library/scanning/audio_metadata_fallback.dart';

void main() {
  test(
    'recognizes the same common formats for local paths and remote URLs',
    () {
      const expected = <String, String>{
        '.mp3': 'audio/mpeg',
        '.flac': 'audio/flac',
        '.m4a': 'audio/mp4',
        '.aac': 'audio/aac',
        '.wav': 'audio/wav',
        '.ogg': 'audio/ogg',
        '.opus': 'audio/ogg',
      };

      expect(
        supportedAudioFormats.map((format) => format.extension).toSet(),
        expected.keys.toSet(),
      );
      for (final entry in expected.entries) {
        expect(isSupportedAudioPath('Album/Track${entry.key}'), isTrue);
        expect(
          audioContentTypeForPath(
            'https://example.test/Music/TRACK${entry.key.toUpperCase()}?v=1',
          ),
          entry.value,
        );
        expect(audioExtensionForPath('Track${entry.key}#fragment'), entry.key);
      }
      expect(isSupportedAudioPath('renamed.wma'), isFalse);
      expect(isSupportedAudioPath('cover.jpg'), isFalse);
    },
  );

  test('normalizes Android content-provider MIME aliases', () {
    expect(audioFormatForMimeType('audio/x-m4a')?.extension, '.m4a');
    expect(
      audioFormatForMimeType('audio/x-wav; charset=binary')?.extension,
      '.wav',
    );
    expect(audioFormatForMimeType('audio/opus')?.extension, '.opus');
    expect(isSupportedAudioMimeType('video/mp4'), isFalse);
  });

  test('rejects macOS metadata files that retain audio extensions', () {
    expect(isSupportedAudioPath('Album/._Track.mp3'), isFalse);
    expect(
      isSupportedAudioPath(
        'https://example.test/Music/%2E_Track.flac?download=1',
      ),
      isFalse,
    );
    expect(isSupportedAudioPath(r'Album\._Track.m4a'), isFalse);
    expect(isSupportedAudioPath('__MACOSX/Album/Track.aac'), isFalse);
    expect(isSupportedAudioPath('Album/Track.mp3'), isTrue);
  });

  test('accepts plain WebDAV display names with literal percent signs', () {
    expect(isSupportedAudioPath('100% Love.mp3'), isTrue);
    expect(isMacOSMetadataPath('100% Love.mp3'), isFalse);
    expect(isMacOSMetadataPath('._100% Love.mp3'), isTrue);
  });

  test('rejects high-confidence OS and NAS metadata trees', () {
    for (final path in <String>[
      r'$RECYCLE.BIN/deleted.mp3',
      'System Volume Information/index.flac',
      '.Trash-1000/song.m4a',
      '.Spotlight-V100/cache.aac',
      'lost+found/orphan.wav',
      '@eaDir/song.mp3/thumbnail.mp3',
      '#recycle/old.ogg',
      '.@__thumb/cover.opus',
      '.snapshot/yesterday/song.mp3',
    ]) {
      expect(isSupportedAudioPath(path), isFalse, reason: path);
    }
    expect(isSupportedAudioPath('.hidden-song.mp3'), isTrue);
  });

  test('recognizes Apple metadata magic without another file read', () {
    expect(hasAppleMetadataHeader(<int>[0x00, 0x05, 0x16, 0x07]), isTrue);
    expect(hasAppleMetadataHeader(<int>[0x00, 0x05, 0x16, 0x00]), isTrue);
    expect(hasAppleMetadataHeader(<int>[0x49, 0x44, 0x33, 0x04]), isFalse);
  });

  test('distinguishes M4A metadata from raw AAC filename fallback', () {
    final m4a = audioFormatForPath('lossless.m4a');
    final aac = audioFormatForPath('stream.aac');

    expect(m4a?.displayName, 'M4A (AAC/ALAC)');
    expect(m4a?.metadataReaderSupported, isTrue);
    expect(aac?.metadataReaderSupported, isFalse);
    expect(
      canUseFilenameMetadataFallback(
        'stream.aac',
        Uint8List.fromList(<int>[0xff, 0xf1, 0x50, 0x80, 0x01, 0x7f, 0xfc]),
      ),
      isTrue,
    );
    expect(
      canUseFilenameMetadataFallback(
        'damaged.aac',
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      ),
      isFalse,
    );
    expect(
      canUseFilenameMetadataFallback(
        'truncated.mp3',
        Uint8List.fromList(<int>[
          0x49,
          0x44,
          0x33,
          0x04,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x20,
        ]),
      ),
      isFalse,
    );
  });
}
