// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/rules/absolute_paths_rule.dart';
import 'package:dart_skills_lint/src/rules/relative_paths_rule.dart';
import 'package:dart_skills_lint/src/validator.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Relative Path Flag Validation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('relative_path_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('validates links when relativePathsSeverity = warning', () async {
      final skillDir = Directory('${tempDir.path}/test-skill');
      await skillDir.create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}Body with [broken link](missing.md) and [absolute link](/absolute/path.md)',
      );

      final validator = Validator(
        ruleOverrides: {
          RelativePathsRule.ruleName: AnalysisSeverity.warning,
          AbsolutePathsRule.ruleName: AnalysisSeverity.error,
        },
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains(contains('Absolute filepath found in link: /absolute/path.md')),
      );
      expect(result.warnings, contains(contains('Linked file does not exist: missing.md')));
    });

    test('passes when relativePathsSeverity = warning and links are valid', () async {
      final skillDir = Directory('${tempDir.path}/test-skill');
      await skillDir.create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}Body with [valid relative link](valid.md)',
      );
      await File('${skillDir.path}/valid.md').writeAsString('Valid file content');

      final validator = Validator(
        ruleOverrides: {RelativePathsRule.ruleName: AnalysisSeverity.warning},
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });
}
