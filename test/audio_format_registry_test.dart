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
