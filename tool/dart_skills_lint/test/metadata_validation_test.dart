// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/models/validation_error.dart';
import 'package:dart_skills_lint/src/rules/disallowed_field_rule.dart';
import 'package:dart_skills_lint/src/validator.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Metadata (YAML) Validation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('metadata_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('fails if YAML metadata is invalid', () async {
      await File('${tempDir.path}/SKILL.md').writeAsString('''
---
invalid: yaml: frontmatter
---
Body''');
      final validator = Validator();
      final ValidationResult result = await validator.validate(tempDir);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Invalid YAML metadata')));
    });

    test('fails if required field "name" is missing', () async {
      await File('${tempDir.path}/SKILL.md').writeAsString('''
---
description: A test skill
---
Body''');
      final validator = Validator();
      final ValidationResult result = await validator.validate(tempDir);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Missing required field: name')));
    });

    test('fails if required field "description" is missing', () async {
      await File('${tempDir.path}/SKILL.md').writeAsString('''
---
name: metadata-test
---
Body''');
      final validator = Validator();
      final ValidationResult result = await validator.validate(tempDir);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Missing required field: description')));
    });

    test('passes without warning if disallowed fields are present', () async {
      final skillDir = Directory('${tempDir.path}/metadata-test');
      await skillDir.create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: metadata-test
description: A test skill
extra-field: not allowed
---
Body''');

      final validator = Validator();
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue);
      expect(result.warnings, isEmpty);

      final Iterable<ValidationError> disallowedErrors = result.validationErrors.where(
        (e) => e.ruleId == DisallowedFieldRule.ruleName,
      );
      expect(disallowedErrors, isEmpty);
    });

    test('passes with all allowed fields and valid YAML', () async {
      await File('${tempDir.path}/SKILL.md').writeAsString('''
---
name: metadata-test
description: A test skill
license: MIT
compatibility: Python 3.10
metadata:
  version: 1.0.0
allowed-tools: git
---
Body''');
      final validator = Validator();
      // We need to make sure directory name matches name in metadata
      final skillDir = Directory('${tempDir.path}/metadata-test');
      await skillDir.create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'metadata-test')}Body');

      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue, reason: result.errors.isEmpty ? '' : result.errors.first);
      expect(result.errors, isEmpty);
    });
  });
}
