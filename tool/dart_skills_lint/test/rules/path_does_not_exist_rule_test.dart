// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/skill_context.dart';
import 'package:dart_skills_lint/src/models/validation_error.dart';
import 'package:dart_skills_lint/src/rules/path_does_not_exist_rule.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('PathDoesNotExistRule', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('path_does_not_exist_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('passes when directory exists and contains SKILL.md', () async {
      final skillDir = Directory(p.join(tempDir.path, 'valid-skill'));
      await skillDir.create();
      await File(p.join(skillDir.path, 'SKILL.md')).writeAsString('name: valid-skill');

      final rule = PathDoesNotExistRule(severity: AnalysisSeverity.error);
      final context = SkillContext(directory: skillDir, rawContent: 'name: valid-skill');

      final List<ValidationError> errors = await rule.validate(context);
      expect(errors, isEmpty);
    });

    test('flags when SKILL.md is missing', () async {
      final skillDir = Directory(p.join(tempDir.path, 'missing-skill-md'));
      await skillDir.create();

      final rule = PathDoesNotExistRule(severity: AnalysisSeverity.error);
      final context = SkillContext(directory: skillDir, rawContent: '');

      final List<ValidationError> errors = await rule.validate(context);
      expect(errors, isNotEmpty);
      expect(errors.first.ruleId, equals(PathDoesNotExistRule.ruleName));
      expect(errors.first.message, contains('SKILL.md is missing'));
    });

    test('flags when directory does not exist', () async {
      final skillDir = Directory(p.join(tempDir.path, 'non-existent'));

      final rule = PathDoesNotExistRule(severity: AnalysisSeverity.error);
      final context = SkillContext(directory: skillDir, rawContent: '');

      final List<ValidationError> errors = await rule.validate(context);
      expect(errors, isNotEmpty);
      expect(errors.first.ruleId, equals(PathDoesNotExistRule.ruleName));
      expect(errors.first.message, contains('Directory does not exist'));
    });

    test('flags when path is a file instead of a directory', () async {
      final skillDirAsFile = File(p.join(tempDir.path, 'is-a-file'));
      await skillDirAsFile.create();

      final rule = PathDoesNotExistRule(severity: AnalysisSeverity.error);
      final context = SkillContext(directory: Directory(skillDirAsFile.path), rawContent: '');

      final List<ValidationError> errors = await rule.validate(context);
      expect(errors, isNotEmpty);
      expect(errors.first.ruleId, equals(PathDoesNotExistRule.ruleName));
      expect(errors.first.message, contains('Path is not a directory'));
    });

    test('bypasses validation when full directory path matches exclude RegExp', () async {
      final skillDir = Directory(p.join(tempDir.path, 'nested', 'target-workspace'));
      await skillDir.create(recursive: true); // missing SKILL.md

      final rule = PathDoesNotExistRule(
        severity: AnalysisSeverity.error,
        excludeRegExp: RegExp(r'nested/target-workspace'),
      );
      final context = SkillContext(directory: skillDir, rawContent: '');

      final List<ValidationError> errors = await rule.validate(context);
      expect(errors, isEmpty);
    });

    test('bypasses validation when full directory path with backslashes is normalized', () async {
      final skillDir = Directory(p.join(tempDir.path, 'target-workspace'));
      await skillDir.create();

      // Simulate Windows path structure intentionally using backslashes
      final String windowsStylePath = skillDir.path.replaceAll('/', r'\');
      final windowsDir = Directory(windowsStylePath);

      final rule = PathDoesNotExistRule(
        severity: AnalysisSeverity.error,
        excludeRegExp: RegExp(r'/target-workspace'),
      );
      final context = SkillContext(directory: windowsDir, rawContent: '');

      final List<ValidationError> errors = await rule.validate(context);
      expect(errors, isEmpty);
    });

    test('bypasses validation when directory name matches alternation RegExp', () async {
      final skillDir1 = Directory(p.join(tempDir.path, 'test-workspace'));
      final skillDir2 = Directory(p.join(tempDir.path, 'evals'));
      await skillDir1.create();
      await skillDir2.create();

      final rule = PathDoesNotExistRule(
        severity: AnalysisSeverity.error,
        excludeRegExp: RegExp(r'.*-workspace|evals'),
      );

      final context1 = SkillContext(directory: skillDir1, rawContent: '');
      final context2 = SkillContext(directory: skillDir2, rawContent: '');

      expect(await rule.validate(context1), isEmpty);
      expect(await rule.validate(context2), isEmpty);
    });
  });
}
