import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/library/scanning/audio_metadata_extractor.dart';

void main() {
  test('extracts MP3 tags, duration, artwork, and embedded lyrics', () async {
    final directory = await Directory.systemTemp.createTemp('sound-mp3-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fixture.mp3');
    await file.writeAsBytes(
      _withMp3Lyrics(base64Decode(_mp3Fixture), '[00:00.00]Hello MP3'),
    );

    final metadata = await const PackageAudioMetadataExtractor().extract(file);

    expect(metadata.title, 'Fixture MP3');
    expect(metadata.artist, 'Fixture Artist');
    expect(metadata.album, 'Fixture Album');
    expect(metadata.trackNumber, 2);
    expect(metadata.discNumber, 1);
    expect(metadata.year, 2026);
    expect(metadata.genre, 'Test');
    expect(metadata.lyrics, '[00:00.00]Hello MP3');
    expect(metadata.duration, greaterThan(Duration.zero));
    expect(metadata.artwork?.mimeType, 'image/png');
    expect(metadata.artwork?.bytes, isNotEmpty);
  });

  test('extracts FLAC Vorbis comments and stream duration', () async {
    final directory = await Directory.systemTemp.createTemp('sound-flac-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fixture.flac');
    await file.writeAsBytes(base64Decode(_flacFixture));

    final metadata = await const PackageAudioMetadataExtractor().extract(file);

    expect(metadata.title, 'Fixture FLAC');
    expect(metadata.artist, 'Fixture Artist');
    expect(metadata.album, 'Fixture Album');
    expect(metadata.trackNumber, 3);
    expect(metadata.discNumber, 1);
    expect(metadata.year, 2026);
    expect(metadata.genre, 'Test');
    expect(metadata.lyrics, '[00:00.00]Hello FLAC');
    expect(metadata.duration, greaterThan(Duration.zero));
  });
}

Uint8List _withMp3Lyrics(Uint8List bytes, String lyrics) {
  final tagSize =
      ((bytes[6] & 0x7f) << 21) |
      ((bytes[7] & 0x7f) << 14) |
      ((bytes[8] & 0x7f) << 7) |
      (bytes[9] & 0x7f);
  final payload = <int>[3, ...ascii.encode('eng'), 0, ...utf8.encode(lyrics)];
  final frame = <int>[
    ...ascii.encode('USLT'),
    ..._syncSafe(payload.length),
    0,
    0,
    ...payload,
  ];
  final durationPayload = <int>[3, ...ascii.encode('1000')];
  final durationFrame = <int>[
    ...ascii.encode('TLEN'),
    ..._syncSafe(durationPayload.length),
    0,
    0,
    ...durationPayload,
  ];
  final tagEnd = 10 + tagSize;
  var frameEnd = 10;
  while (frameEnd + 10 <= tagEnd &&
      bytes.skip(frameEnd).take(4).any((value) => value != 0)) {
    final frameSize =
        ((bytes[frameEnd + 4] & 0x7f) << 21) |
        ((bytes[frameEnd + 5] & 0x7f) << 14) |
        ((bytes[frameEnd + 6] & 0x7f) << 7) |
        (bytes[frameEnd + 7] & 0x7f);
    frameEnd += 10 + frameSize;
  }
  final nextTagSize = frameEnd - 10 + durationFrame.length + frame.length;
  final audioFrames = bytes.skip(tagEnd).toList(growable: false);
  return Uint8List.fromList([
    ...bytes.take(6),
    ..._syncSafe(nextTagSize),
    ...bytes.skip(10).take(frameEnd - 10),
    ...durationFrame,
    ...frame,
    for (var repeat = 0; repeat < 20; repeat++) ...audioFrames,
  ]);
}

List<int> _syncSafe(int value) => [
  (value >> 21) & 0x7f,
  (value >> 14) & 0x7f,
  (value >> 7) & 0x7f,
  value & 0x7f,
];

const _mp3Fixture =
    'SUQzBAAAAAACQFRJVDIAAAANAAADRml4dHVyZSBNUDMAVFBFMQAAABAAAANGaXh0dXJlIEFydGlzdABU'
    'QUxCAAAADwAAA0ZpeHR1cmUgQWxidW0AVFJDSwAAAAMAAAMyAFRQT1MAAAADAAADMQBURFJDAAAABgAA'
    'AzIwMjYAVENPTgAAAAYAAANUZXN0AFRYWFgAAAAaAAADVVNMVABbMDA6MDAuMDBdSGVsbG8gTVAzAFRT'
    'U0UAAAAPAAADTGF2ZjYyLjEyLjEwMABBUElDAAAAawAAA2ltYWdlL3BuZwAAAIlQTkcNChoKAAAADUlI'
    'RFIAAAACAAAAAggCAAAA/dSacwAAAAlwSFlzAAAAAQAAAAEATyXE1gAAABBJREFUeJxj/MMAAixgkgEA'
    'DQQBAr9QFbMAAAAASUVORK5CYIIAAAAAAAAAAAAA/+M4wAAAAAAAAAAAAEluZm8AAAAPAAAAAwAAAbAA'
    'qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV'
    '1dXV1dXV////////////////////////////////////////////AAAAAExhdmM2Mi4yOAAAAAAAAAAA'
    'AAAAACQC8AAAAAAAAAGw9wpEpwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAA/+MYxAAAAANIAAAAAExBTUUzLjEwMFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV'
    'VVVVVVVVVVVVVVVVVVVVVVVV/+MYxDsAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV'
    'VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV/+MYxHYAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVV'
    'VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV';

const _flacFixture =
    'ZkxhQwAAACICQAJAAAANAAANAfQA8AAAAZBrQxvy2nyTErPlwh5n9lkbhAAAzw0AAABMYXZmNjIuMTIuMTAwCQAAABIAAAB0aXRsZT1GaXh0dXJlIEZMQUMVAAAAYXJ0aXN0PUZpeHR1cmUgQXJ0aXN0EwAAAGFsYnVtPUZpeHR1cmUgQWxidW0NAAAAdHJhY2tudW1iZXI9MwwAAABkaXNjbnVtYmVyPTEJAAAAZGF0ZT0yMDI2CgAAAGdlbnJlPVRlc3QbAAAAbHlyaWNzPVswMDowMC4wMF1IZWxsbyBGTEFDFQAAAGVuY29kZXI9TGF2ZjYyLjEyLjEwMP/4dAgAAY8kAAAAfV8=';
