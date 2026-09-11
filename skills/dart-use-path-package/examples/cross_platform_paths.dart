// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Checks if [file] resides inside a 'canvaskit' directory and has a '.wasm' extension.
bool isCanvasKitWasmAsset(File file) {
  final segments = p.split(file.path);
  return segments.contains('canvaskit') && p.extension(file.path) == '.wasm';
}

/// Converts an OS-native file path into a POSIX-style web asset key.
String computeWebAssetKey(String filePath, String projectRoot) {
  final relative = p.relative(filePath, from: projectRoot);
  final segments = p.split(relative);
  return switch (segments) {
    ['assets', ...] => p.posix.joinAll(segments),
    _ => p.posix.joinAll(['assets', ...segments]),
  };
}

/// Inserts a content hash before file extensions, safely handling compound
/// extensions (e.g. '.js.map') versus multi-dot stems (e.g. 'main.dart.wasm').
String insertContentHash(String filename, String hash) {
  final compoundExt = p.extension(filename, 2);
  final ext = compoundExt.endsWith('.map')
      ? compoundExt
      : p.extension(filename);
  final stem = filename.substring(0, filename.length - ext.length);
  return '$stem.$hash$ext';
}

/// Converts an OS-native relative path to a POSIX path suitable for
/// `.gitignore`, `.gitattributes`, or Git tree objects.
String toGitPath(String relativeNativePath) =>
    p.posix.joinAll(p.split(relativeNativePath));

void main() {
  print('Git path: ${toGitPath(r'lib\src\file.dart')}');
  print('Asset key: ${computeWebAssetKey('assets/icon.png', '.')}');
  print('Content hash: ${insertContentHash('main.dart.js.map', 'a1b2c3')}');
}
