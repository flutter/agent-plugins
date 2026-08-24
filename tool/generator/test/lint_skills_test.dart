// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills_lint/skills_lint.dart';
import 'package:test/test.dart';

import 'custom_skill_rules/last_modified_rule.dart';

void main() {
  test('Run skills linter', () async {
    final lintErrors = <String>[];
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen((record) {
      if (record.level >= Level.WARNING) {
        lintErrors.add('${record.level.name}: ${record.message}');
      }
      printOnFailure('${record.level.name}: ${record.message}');
    });

    final originalDir = Directory.current;
    final isGenerator = originalDir.path.endsWith(p.join('tool', 'generator'));
    final isRoot = File(
      p.join(originalDir.path, 'tool', 'generator', 'skills_lint.yaml'),
    ).existsSync();

    if (!isGenerator && isRoot) {
      Directory.current = Directory(
        p.join(originalDir.path, 'tool', 'generator'),
      );
    }

    try {
      final configFile = File('skills_lint.yaml');
      expect(
        configFile.existsSync(),
        isTrue,
        reason:
            'skills_lint.yaml configuration file must exist in ${Directory.current.path}',
      );

      final skills = Directory(p.join('..', '..', 'skills'))
          .listSync()
          .whereType<Directory>();
      expect(
        skills,
        isNotEmpty,
        reason: 'Expected skills directory to contain skills.',
      );

      final config = await ConfigParser.loadConfig();
      expect(
        config.directoryConfigs,
        isNotEmpty,
        reason: 'Configuration directoryConfigs should not be empty.',
      );

      final isValid = await validateSkills(
        config: config,
        customRules: [LastModifiedRule()],
      );
      expect(
        isValid,
        isTrue,
        reason:
            'Skills linting failed with the following issues:\n${lintErrors.join('\n')}',
      );
    } finally {
      if (!isGenerator && isRoot) {
        Directory.current = originalDir;
      }
      await subscription.cancel();
    }
  });
}
