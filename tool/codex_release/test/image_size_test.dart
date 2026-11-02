import 'dart:typed_data';

import 'package:codex_release/codex_release.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  test('reads PNG dimensions', () {
    final size = readRasterSize(pngHeader(953, 272))!;
    expect((size.width, size.height), (953, 272));
  });

  test('reads JPEG dimensions from the start-of-frame marker', () {
    final bytes = Uint8List.fromList([
      0xFF, 0xD8, // SOI
      0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0 with 2 bytes of data
      0xFF, 0xC0, 0x00, 0x0B, 0x08, // SOF0, length, precision
      0x00, 0x30, // height 48
      0x00, 0x40, // width 64
      0x03, 0x00, 0x00, 0x00,
    ]);
    expect(detectRasterFormat(bytes), RasterFormat.jpeg);
    final size = readRasterSize(bytes)!;
    expect((size.width, size.height), (64, 48));
  });

  test('reads extended WebP dimensions', () {
    final bytes = Uint8List(30);
    'RIFF'.codeUnits.asMap().forEach((i, c) => bytes[i] = c);
    'WEBP'.codeUnits.asMap().forEach((i, c) => bytes[8 + i] = c);
    'VP8X'.codeUnits.asMap().forEach((i, c) => bytes[12 + i] = c);
    // Canvas width-1 = 99 and height-1 = 49, as 24-bit little endian.
    bytes[24] = 99;
    bytes[27] = 49;
    final size = readRasterSize(bytes)!;
    expect((size.width, size.height), (100, 50));
  });

  test('returns null for unknown or truncated data', () {
    expect(readRasterSize(Uint8List.fromList([1, 2, 3])), isNull);
    expect(readRasterSize(pngHeader(1, 1).sublist(0, 18)), isNull);
  });
}
