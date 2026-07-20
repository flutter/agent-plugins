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

    try {
      final String packageDir = Directory.current.path.endsWith('generator')
          ? Directory.current.path
          : p.join(Directory.current.path, 'tool', 'generator');
      final String configPath = p.join(packageDir, 'dart_skills_lint.yaml');
      final String skillsDir = p.normalize(p.join(packageDir, '..', '..', 'skills'));

      final config = await ConfigParser.loadConfig(path: configPath);
      expect(
        config.directoryConfigs,
        isNotEmpty,
        reason: 'Configuration directoryConfigs should not be empty.',
      );

      expect(
        await validateSkills(
          skillDirPaths: [skillsDir],
          config: config,
          customRules: [LastModifiedRule()],
        ),
        isTrue,
      );
    } finally {
      await subscription.cancel();
    }
  });
}
