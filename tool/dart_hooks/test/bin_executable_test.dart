// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('all .dart files in bin/ are executable', () {
    // Locate the bin/ directory reliably.
    var binDir = Directory('bin');
    if (!binDir.existsSync()) {
      binDir = Directory('../bin');
    }
    expect(binDir.existsSync(), isTrue, reason: 'bin/ directory should exist');

    final List<File> dartFiles = binDir
        .listSync()
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .toList();

    expect(dartFiles, isNotEmpty, reason: 'Should find .dart files in bin/');

    for (final file in dartFiles) {
      final FileStat stat = file.statSync();
      final String modeString = stat.modeString();
      // modeString is formatted like 'rwxr-xr-x'.
      // Index 2 corresponds to the owner's executable bit.
      final bool isExecutable = modeString.length >= 3 && modeString[2] == 'x';
      expect(
        isExecutable,
        isTrue,
        reason: '${file.path} is not marked executable (mode: $modeString)',
      );
    }
  });
}
