// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/rule_config.dart';
import 'package:dart_skills_lint/src/models/validation_result.dart';
import 'package:dart_skills_lint/src/validator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class MockInaccessibleFile implements File {
  MockInaccessibleFile(this._path);
  final String _path;

  @override
  String get path => _path;

  @override
  bool existsSync() => true;

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async {
    throw FileSystemException('File is inaccessible', _path);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

base class TestIOOverrides extends IOOverrides {
  TestIOOverrides(this.targetPath);
  final String targetPath;

  @override
  File createFile(String path) {
    if (path == targetPath) {
      return MockInaccessibleFile(path);
    }
    return super.createFile(path);
  }
}

void main() {
  group('Directory Structure Validation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('skill_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('fails if directory does not exist', () async {
      final nonExistentDir = Directory('path/to/nothing');
      final validator = Validator();
      final ValidationResult result = await validator.validate(nonExistentDir);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Directory does not exist')));
    });

    test('fails if path is a file', () async {
      final file = File('${tempDir.path}/some_file');
      await file.create();
      final validator = Validator();
      final ValidationResult result = await validator.validate(Directory(file.path));

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('is not a directory')));
    });

    test('fails if SKILL.md is missing', () async {
      final validator = Validator();
      final ValidationResult result = await validator.validate(tempDir);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('SKILL.md is missing')));
    });

    test('fails if SKILL.md cannot be read', () async {
      final skillDir = Directory(p.join(tempDir.path, 'test-skill-inaccessible'));
      await skillDir.create();
      final String filePath = p.join(skillDir.path, 'SKILL.md');

      final overrides = TestIOOverrides(filePath);
      await IOOverrides.runWithIOOverrides(() async {
        try {
          final validator = Validator();
          final ValidationResult validationResult = await validator.validate(skillDir);

          // ignore: avoid_print
          print(
            'DEBUG errors: ${validationResult.validationErrors.map((e) => "${e.ruleId}: ${e.message}").toList()}',
          );
          expect(validationResult.isValid, isFalse);
          expect(
            validationResult.validationErrors.any(
              (e) => e.ruleId == Validator.skillFileInaccessible,
            ),
            isTrue,
          );
        } catch (e, s) {
          fail('Unexpected exception during validation: $e\n$s');
        }
      }, overrides);
    });

    test('obeys skill-file-inaccessible severity override', () async {
      final skillDir = Directory(p.join(tempDir.path, 'test-skill-override'));
      await skillDir.create();
      final String filePath = p.join(skillDir.path, 'SKILL.md');

      final overrides = TestIOOverrides(filePath);
      await IOOverrides.runWithIOOverrides(() async {
        try {
          final validator = Validator(
            ruleConfigs: {
              Validator.skillFileInaccessible: const RuleConfig(severity: AnalysisSeverity.warning),
            },
          );
          final ValidationResult validationResult = await validator.validate(skillDir);

          // ignore: avoid_print
          print(
            'DEBUG errors (override): ${validationResult.validationErrors.map((e) => "${e.ruleId}: ${e.message}").toList()}',
          );
          expect(validationResult.isValid, isTrue);
          expect(
            validationResult.validationErrors.any(
              (e) =>
                  e.ruleId == Validator.skillFileInaccessible &&
                  e.severity == AnalysisSeverity.warning,
            ),
            isTrue,
          );
        } catch (e, s) {
          fail('Unexpected exception during validation: $e\n$s');
        }
      }, overrides);
    });

    test('passes if directory exists and contains SKILL.md', () async {
      final skillDir = Directory(p.join(tempDir.path, 'test-skill'));
      await skillDir.create();
      await File(p.join(skillDir.path, 'SKILL.md')).writeAsString('''
---
name: test-skill
description: A test skill
---
Body''');

      final validator = Validator();
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isTrue, reason: result.errors.isEmpty ? '' : result.errors.first);
      expect(result.errors, isEmpty);
    });
  });
}
