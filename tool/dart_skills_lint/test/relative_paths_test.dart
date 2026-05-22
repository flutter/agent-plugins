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
  group('Relative Paths Validation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paths_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('passes with valid relative file path (existing file)', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}[Link to a reference](references/DETAILS.md)\n',
      );

      final Directory refDir = await Directory('${skillDir.path}/references').create();
      await File('${refDir.path}/DETAILS.md').writeAsString('Details here');

      final validator = Validator(
        ruleOverrides: {RelativePathsRule.ruleName: AnalysisSeverity.warning},
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('warns with missing relative file path', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}[Link to a references file missing](references/MISSING.md)\n',
      );

      final validator = Validator(
        ruleOverrides: {RelativePathsRule.ruleName: AnalysisSeverity.warning},
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.warnings, contains(contains('Linked file does not exist')));
    });

    test('fails with absolute file path', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}[Absolute path link](/tmp/some_absolute_path/file.md)\n',
      );

      final validator = Validator(
        ruleOverrides: {
          RelativePathsRule.ruleName: AnalysisSeverity.warning,
          AbsolutePathsRule.ruleName: AnalysisSeverity.error,
        },
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Absolute filepath found in link')));
    });

    test('ignores web URLs, emails, javascript, data URIs, and anchors', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}- [Web link](http://example.com)\n- [Web TLS link](https://example.com)\n- [Email link](mailto:user@domain.com)\n- [JS link](javascript:alert(1))\n- [Data URI](data:image/png;base64,iVBORw)\n- [Anchor link](#section-name)\n',
      );

      final validator = Validator(
        ruleOverrides: {RelativePathsRule.ruleName: AnalysisSeverity.warning},
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty); // None of these should trigger local file checks
    });

    test('passes with valid relative image path and title', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}![Accessible description](images/screenshot.png "Hover description")\n',
      );

      final Directory imgDir = await Directory('${skillDir.path}/images').create();
      await File('${imgDir.path}/screenshot.png').writeAsString('image content');

      final validator = Validator(
        ruleOverrides: {RelativePathsRule.ruleName: AnalysisSeverity.warning},
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('passes with relative path containing line fragments', () async {
      final Directory skillDir = await Directory(
        '${tempDir.path}/a/b/c/test-skill',
      ).create(recursive: true);
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}[Link to lines](../../../CONTRIBUTING.md#L64-L80)\n',
      );

      await File('${tempDir.path}/a/CONTRIBUTING.md').create(recursive: true);

      final validator = Validator(
        ruleOverrides: {RelativePathsRule.ruleName: AnalysisSeverity.warning},
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('passes with relative path containing anchor fragments', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}[Link to section](styleguide.md#miscellaneous-languages)\n',
      );

      await File('${skillDir.path}/styleguide.md').writeAsString('Styleguide content');

      final validator = Validator(
        ruleOverrides: {RelativePathsRule.ruleName: AnalysisSeverity.warning},
      );
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('passes with leading and trailing whitespace in link', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}[Link with whitespace]( styleguide.md )\n',
      );

      await File('${skillDir.path}/styleguide.md').writeAsString('Styleguide content');

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
