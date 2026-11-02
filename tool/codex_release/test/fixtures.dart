import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:codex_release/codex_release.dart';

/// A square SVG icon.
const squareSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
    '<rect width="100" height="100"/></svg>';

/// A valid release manifest. Tests copy and modify it.
Map<String, Object?> validManifest() => {
  'name': 'dart-flutter',
  'version': '1.0.8',
  'description': 'Dart and Flutter skills.',
  'author': {'name': 'Google LLC', 'url': 'https://flutter.dev'},
  'homepage': 'https://github.com/flutter/agent-plugins',
  'keywords': ['flutter', 'dart'],
  'skills': './skills/',
  'interface': {
    'displayName': 'Dart and Flutter',
    'shortDescription': 'Build Dart and Flutter apps',
    'longDescription': 'Use official Dart and Flutter skills.',
    'developerName': 'Google LLC',
    'category': 'Developer Tools',
    'capabilities': ['Skills'],
    'websiteURL': 'https://flutter.dev',
    'composerIcon': './assets/icon.svg',
    'logo': './assets/icon.svg',
  },
  'extensions': {
    'com.openai': {
      'publication': {'release_notes': 'Updated skills.'},
    },
  },
};

/// A valid SKILL.md for a skill called [name].
String skillMd(String name, {String description = 'Does a thing.'}) =>
    '---\nname: $name\ndescription: $description\n---\n\n# $name\n\nSteps.\n';

/// The files of a valid package. Tests copy and modify them.
Map<String, Object> validFiles({Map<String, Object?>? manifest}) => {
  manifestPath: manifest ?? validManifest(),
  'assets/icon.svg': squareSvg,
  'skills/dart-one/SKILL.md': skillMd('dart-one'),
  'skills/dart-two/SKILL.md': skillMd('dart-two'),
  'skills/dart-two/references/notes.md': '# Notes\n',
};

/// Zips [files]. Values can be a JSON map (encoded as the manifest), a
/// string, or bytes.
Uint8List zip(Map<String, Object> files) {
  final archive = Archive();
  files.forEach((path, content) {
    final List<int> bytes = switch (content) {
      final Map<String, Object?> json => utf8.encode(jsonEncode(json)),
      final String text => utf8.encode(text),
      final List<int> data => data,
      _ => throw ArgumentError('Unsupported content for $path'),
    };
    archive.add(ArchiveFile.bytes(path, bytes));
  });
  return ZipEncoder().encodeBytes(archive);
}

/// Validates [files] and returns the finding codes.
List<String> codesFor(Map<String, Object> files, {String? expectedVersion}) =>
    validateZip(
      zip(files),
      expectedVersion: expectedVersion,
    ).map((f) => f.code).toList();

/// Minimal PNG header bytes for a [width]×[height] image.
Uint8List pngHeader(int width, int height) {
  final data = ByteData(33);
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < 8; i++) {
    data.setUint8(i, signature[i]);
  }
  data.setUint32(8, 13);
  'IHDR'.codeUnits.asMap().forEach((i, c) => data.setUint8(12 + i, c));
  data
    ..setUint32(16, width)
    ..setUint32(20, height)
    ..setUint8(24, 8)
    ..setUint8(25, 6);
  return data.buffer.asUint8List();
}
