// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/memory.dart';

/// Lists subdirectory names using the [FileSystem]'s own path context
/// rather than the host OS's global `p.*` functions.
List<String> listSubdirectoryNames(Directory dir) {
  final pathContext = dir.fileSystem.path;
  return dir
      .listSync()
      .whereType<Directory>()
      .map((d) => pathContext.basename(d.path))
      .toList();
}

void main() {
  // Simulates a Windows filesystem running inside a unit test on Linux/macOS.
  final fs = MemoryFileSystem(style: FileSystemStyle.windows);
  final projectDir = fs.directory(r'C:\workspace\app\lib')
    ..createSync(recursive: true);
  fs.directory(r'C:\workspace\app\lib\src').createSync();

  final subdirs = listSubdirectoryNames(projectDir);
  print('Subdirectories: $subdirs');
}
