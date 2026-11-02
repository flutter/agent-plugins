import 'dart:typed_data';

/// The pixel dimensions of a raster image.
class ImageSize {
  const ImageSize(this.width, this.height);

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  @override
  String toString() => '$width×$height';
}

/// The raster formats OpenAI accepts for branding images.
enum RasterFormat { png, jpeg, webp }

/// Detects the raster format of [bytes] from its signature, or returns null.
RasterFormat? detectRasterFormat(Uint8List bytes) {
  if (_startsWith(bytes, const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return RasterFormat.png;
  }
  if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) {
    return RasterFormat.jpeg;
  }
  if (bytes.length >= 12 &&
      _ascii(bytes, 0, 4) == 'RIFF' &&
      _ascii(bytes, 8, 4) == 'WEBP') {
    return RasterFormat.webp;
  }
  return null;
}

/// Reads the dimensions of a PNG, JPEG, or WebP image from its header.
///
/// Returns null if the format isn't recognized or the header is malformed.
/// Only the header is read; the image data itself isn't decoded.
ImageSize? readRasterSize(Uint8List bytes) {
  try {
    return switch (detectRasterFormat(bytes)) {
      RasterFormat.png => _pngSize(bytes),
      RasterFormat.jpeg => _jpegSize(bytes),
      RasterFormat.webp => _webpSize(bytes),
      null => null,
    };
  } on RangeError {
    return null;
  }
}

ImageSize? _pngSize(Uint8List bytes) {
  // The IHDR chunk always comes first: length (4), type (4), width, height.
  if (_ascii(bytes, 12, 4) != 'IHDR') return null;
  final data = ByteData.sublistView(bytes);
  return ImageSize(data.getUint32(16), data.getUint32(20));
}

ImageSize? _jpegSize(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF) return null;
    final marker = bytes[offset + 1];
    // Skip fill bytes.
    if (marker == 0xFF) {
      offset++;
      continue;
    }
    // Markers without a length field.
    if (marker == 0xD8 ||
        marker == 0x01 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      offset += 2;
      continue;
    }
    final length = data.getUint16(offset + 2);
    final isStartOfFrame =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isStartOfFrame) {
      return ImageSize(data.getUint16(offset + 7), data.getUint16(offset + 5));
    }
    offset += 2 + length;
  }
  return null;
}

ImageSize? _webpSize(Uint8List bytes) {
  final chunk = _ascii(bytes, 12, 4);
  final data = ByteData.sublistView(bytes);
  switch (chunk) {
    case 'VP8 ':
      // Lossy: frame tag (3 bytes) and start code (3 bytes) precede the size.
      return ImageSize(
        data.getUint16(26, Endian.little) & 0x3FFF,
        data.getUint16(28, Endian.little) & 0x3FFF,
      );
    case 'VP8L':
      // Lossless: signature byte, then 14-bit width-1 and height-1.
      final bits = data.getUint32(21, Endian.little);
      return ImageSize((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
    case 'VP8X':
      // Extended: 24-bit canvas width-1 and height-1.
      int read24(int offset) =>
          bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
      return ImageSize(read24(24) + 1, read24(27) + 1);
  }
  return null;
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

String _ascii(Uint8List bytes, int start, int length) {
  if (bytes.length < start + length) return '';
  return String.fromCharCodes(bytes.sublist(start, start + length));
}
