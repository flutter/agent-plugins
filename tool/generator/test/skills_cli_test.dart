// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../bin/skills.dart' as cli;

void main() {
  group('skills CLI entrypoint', () {
    late Directory tempDir;

    setUp(() async {
      exitCode = 0;
      tempDir = await Directory.systemTemp.createTemp('skills_cli_test');
    });

    tearDown(() async {
      exitCode = 0;
      await tempDir.delete(recursive: true);
    });

    test('exits 0 for --version and warning-only runs', () async {
      await cli.main(['--version']);
      expect(exitCode, 0);

      final emptyConfig = File(p.join(tempDir.path, 'empty.yaml'))
        ..writeAsStringSync('[]');
      await cli.main(['generate-skill', emptyConfig.path]);
      expect(exitCode, 0);
    });

    test('sets exitCode = 64 on UsageException', () async {
      await cli.main(['--unknown-flag']);
      expect(exitCode, 64);
    });

    test('sets exitCode = 1 when a SEVERE error is logged', () async {
      final missingPath = p.join(tempDir.path, 'does_not_exist.yaml');
      await cli.main(['generate-skill', missingPath]);
      expect(exitCode, 1);
    });
  });
}
