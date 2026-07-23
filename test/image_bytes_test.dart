import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/library/scanning/image_bytes.dart';

void main() {
  test('accepts a complete PNG and rejects zero-padded truncation', () {
    // Minimal valid 1x1 PNG.
    final png = base64DecodePng1x1();
    expect(looksLikeCompleteImageBytes(png), isTrue);

    final truncated = Uint8List(png.length + 200000)
      ..setAll(0, png.sublist(0, png.length - 12));
    // Overwrite end with zeros (no IEND).
    expect(looksLikeCompleteImageBytes(truncated), isFalse);
  });

  test('accepts multi-MB PNGs whose IEND sits 8 bytes from EOF', () {
    // Regression: tail scan used to start at length-12 and walk *backwards*,
    // so it never inspected the real "IEND" type at length-8. Small fixtures
    // still passed via the <4KiB full scan; ~1.4MB FLAC covers did not.
    const size = 1_466_316;
    final tiny = base64DecodePng1x1();
    final large = Uint8List(size)..setAll(0, tiny.sublist(0, 8)); // PNG signature
    large.setAll(size - 12, const [
      0x00, 0x00, 0x00, 0x00, // chunk length
      0x49, 0x45, 0x4e, 0x44, // IEND
      0xae, 0x42, 0x60, 0x82, // CRC
    ]);
    expect(looksLikeCompleteImageBytes(large), isTrue);

    final zeroPadded = Uint8List(size)..setAll(0, tiny.sublist(0, 8));
    expect(looksLikeCompleteImageBytes(zeroPadded), isFalse);
  });

  test('accepts a complete JPEG and rejects truncation', () {
    final jpeg = Uint8List.fromList([
      0xff, 0xd8, 0xff, 0xe0, // SOI + APP0 marker start
      ...List<int>.filled(32, 0),
      0xff, 0xd9, // EOI
    ]);
    expect(looksLikeCompleteImageBytes(jpeg), isTrue);

    final truncated = Uint8List.fromList([
      0xff, 0xd8, 0xff, 0xe0,
      ...List<int>.filled(32, 0),
      // missing EOI
    ]);
    expect(looksLikeCompleteImageBytes(truncated), isFalse);
  });

  test('artworkFileLooksValid rejects missing and truncated files', () async {
    final dir = await Directory.systemTemp.createTemp('art-valid-');
    addTearDown(() => dir.delete(recursive: true));

    final good = File('${dir.path}/good.png');
    await good.writeAsBytes(base64DecodePng1x1());
    expect(artworkFileLooksValid(good.uri.toString()), isTrue);

    final bad = File('${dir.path}/bad.png');
    final png = base64DecodePng1x1();
    final truncated = Uint8List(png.length)
      ..setAll(0, png.sublist(0, png.length - 12));
    await bad.writeAsBytes(truncated);
    expect(artworkFileLooksValid(bad.uri.toString()), isFalse);

    expect(artworkFileLooksValid(null), isFalse);
    expect(
      artworkFileLooksValid(File('${dir.path}/missing.png').uri.toString()),
      isFalse,
    );
  });
}

/// 1×1 red PNG.
Uint8List base64DecodePng1x1() {
  // Standard minimal PNG with IEND.
  return Uint8List.fromList([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xde, 0x00, 0x00, 0x00,
    0x0c, 0x49, 0x44, 0x41, 0x54, 0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0x00,
    0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x05, 0xfe, 0xd4, 0xef, 0x00, 0x00,
    0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
  ]);
}
