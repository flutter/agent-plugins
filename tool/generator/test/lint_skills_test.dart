// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'custom_skill_rules/last_modified_rule.dart';

void main() {
  test('Run skills linter', () async {
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen((record) {
      printOnFailure('${record.level.name}: ${record.message}');
    });

    final originalDir = Directory.current;
    final parts = p.split(originalDir.path);
    final isRoot =
        !(parts.length >= 2 &&
            parts[parts.length - 2] == 'tool' &&
            parts.last == 'generator');

    if (isRoot) {
      Directory.current = Directory(p.join('tool', 'generator'));
    }

    try {
      final config = await ConfigParser.loadConfig();
      expect(
        config.directoryConfigs,
        isNotEmpty,
        reason: 'Configuration directoryConfigs should not be empty.',
      );

      expect(
        await validateSkills(config: config, customRules: [LastModifiedRule()]),
        isTrue,
      );
    } finally {
      if (isRoot) {
        Directory.current = originalDir;
      }
      await subscription.cancel();
    }
  });
}
