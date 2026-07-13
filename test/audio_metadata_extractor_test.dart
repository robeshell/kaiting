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

  test('keeps MP3 track artist separate from the album artist', () async {
    final directory = await Directory.systemTemp.createTemp('sound-mp3-aa-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/album-artist.mp3');
    await file.writeAsBytes(
      _withId3TextFrame(
        base64Decode(_mp3Fixture),
        'TPE2',
        'Fixture Album Artist',
      ),
    );

    final metadata = await const PackageAudioMetadataExtractor().extract(file);

    expect(metadata.artist, 'Fixture Artist');
    expect(metadata.albumArtist, 'Fixture Album Artist');
  });

  test('reads FLAC album artist and compilation comments', () async {
    final directory = await Directory.systemTemp.createTemp('sound-flac-aa-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/album-artist.flac');
    final withAlbumArtist = _withFlacComment(
      base64Decode(_flacFixture),
      'ALBUMARTIST',
      'Fixture Album Artist',
    );
    await file.writeAsBytes(
      _withFlacComment(withAlbumArtist, 'COMPILATION', '1'),
    );

    final metadata = await const PackageAudioMetadataExtractor().extract(file);

    expect(metadata.artist, 'Fixture Artist');
    expect(metadata.albumArtist, 'Fixture Album Artist');
    expect(metadata.isCompilation, isTrue);
  });
}

Uint8List _withId3TextFrame(Uint8List bytes, String frameId, String value) {
  final tagSize =
      ((bytes[6] & 0x7f) << 21) |
      ((bytes[7] & 0x7f) << 14) |
      ((bytes[8] & 0x7f) << 7) |
      (bytes[9] & 0x7f);
  final payload = <int>[3, ...utf8.encode(value)];
  final frame = <int>[
    ...ascii.encode(frameId),
    ..._syncSafe(payload.length),
    0,
    0,
    ...payload,
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
  final nextTagSize = frameEnd - 10 + frame.length;
  return Uint8List.fromList([
    ...bytes.take(6),
    ..._syncSafe(nextTagSize),
    ...bytes.skip(10).take(frameEnd - 10),
    ...frame,
    ...bytes.skip(tagEnd),
  ]);
}

Uint8List _withFlacComment(Uint8List bytes, String key, String value) {
  var offset = 4;
  while (offset + 4 <= bytes.length) {
    final header = bytes[offset];
    final type = header & 0x7f;
    final length =
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    final payloadStart = offset + 4;
    final payloadEnd = payloadStart + length;
    if (payloadEnd > bytes.length) break;
    if (type == 4) {
      final payload = bytes.sublist(payloadStart, payloadEnd);
      final vendorLength = _littleEndianUint32(payload, 0);
      final countOffset = 4 + vendorLength;
      final count = _littleEndianUint32(payload, countOffset);
      final updatedPayload = Uint8List.fromList(payload);
      _writeLittleEndianUint32(updatedPayload, countOffset, count + 1);
      final comment = utf8.encode('$key=$value');
      final nextLength = length + 4 + comment.length;
      return Uint8List.fromList([
        ...bytes.take(offset),
        header,
        (nextLength >> 16) & 0xff,
        (nextLength >> 8) & 0xff,
        nextLength & 0xff,
        ...updatedPayload,
        ..._littleEndianBytes(comment.length),
        ...comment,
        ...bytes.skip(payloadEnd),
      ]);
    }
    offset = payloadEnd;
  }
  throw StateError('Fixture does not contain a FLAC Vorbis comment block.');
}

int _littleEndianUint32(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

void _writeLittleEndianUint32(Uint8List bytes, int offset, int value) {
  bytes[offset] = value & 0xff;
  bytes[offset + 1] = (value >> 8) & 0xff;
  bytes[offset + 2] = (value >> 16) & 0xff;
  bytes[offset + 3] = (value >> 24) & 0xff;
}

List<int> _littleEndianBytes(int value) => [
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

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
