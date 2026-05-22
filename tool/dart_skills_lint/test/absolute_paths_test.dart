// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/skill_context.dart';

import 'package:dart_skills_lint/src/rules/absolute_paths_rule.dart';
import 'package:dart_skills_lint/src/rules/relative_paths_rule.dart';
import 'package:dart_skills_lint/src/validator.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Absolute Paths Validation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('absolute_path_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('flags absolute path starting with / as warning by default', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}[Absolute link](/absolute/path.md)\n',
      );

      final validator = Validator();
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(
        result.warnings,
        contains(contains('Absolute filepath found in link: /absolute/path.md')),
      );
    });

    test('flags windows absolute path starting with drive letter as error', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}[Windows absolute link](C:\\absolute\\path.md)\n',
      );

      final validator = Validator();
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(
        result.warnings,
        contains(contains(r'Absolute filepath found in link: C:\absolute\path.md')),
      );
    });

    test('ignores valid relative paths resembling windows drives', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'test-skill')}[Relative link](C:relative.md)\n');

      final validator = Validator(
        ruleOverrides: {RelativePathsRule.ruleName: AnalysisSeverity.disabled},
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('ignores ordinary file links', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'test-skill')}[Relative link](file.md)\n');

      final validator = Validator(
        ruleOverrides: {RelativePathsRule.ruleName: AnalysisSeverity.disabled},
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });
    test('ignores absolute paths when disabled', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}Body with [broken link](missing.md) and [absolute link](/absolute/path.md)',
      );

      final validator = Validator(
        ruleOverrides: {AbsolutePathsRule.ruleName: AnalysisSeverity.disabled},
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test(
      'flags absolute path as warning when absolutePathsSeverity: AnalysisSeverity.warning',
      () async {
        final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
        await File('${skillDir.path}/SKILL.md').writeAsString(
          '${buildFrontmatter(name: 'test-skill')}Body with [absolute link](/absolute/path.md)',
        );

        final validator = Validator(
          ruleOverrides: {AbsolutePathsRule.ruleName: AnalysisSeverity.warning},
        );
        final ValidationResult result = await validator.validate(skillDir);

        expect(result.isValid, isTrue); // Warnings don't fail validation
        expect(result.errors, isEmpty);
        expect(
          result.warnings,
          contains(contains('Absolute filepath found in link: /absolute/path.md')),
        );
      },
    );

    test('fixes absolute path to relative if file exists', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      final File targetFile = await File('${tempDir.path}/target.md').create();

      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'test-skill')}[Link](${targetFile.path})\n');

      final rule = AbsolutePathsRule();
      final file = File('${skillDir.path}/SKILL.md');
      final String content = await file.readAsString();
      final context = SkillContext(directory: skillDir, rawContent: content);

      final String fixedContent = await rule.fix('SKILL.md', content, context.directory);

      expect(fixedContent, contains('(../target.md)'));
    });

    test('does not fix absolute path if file does not exist', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();

      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'test-skill')}[Link](/non/existent/file.md)\n');

      final rule = AbsolutePathsRule();
      final file = File('${skillDir.path}/SKILL.md');
      final String content = await file.readAsString();
      final context = SkillContext(directory: skillDir, rawContent: content);

      final String fixedContent = await rule.fix('SKILL.md', content, context.directory);

      expect(fixedContent, contains('(/non/existent/file.md)'));
    });
  });
}
