// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/entry_point.dart';
import 'package:dart_skills_lint/src/fixable_rule.dart';
import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/skill_context.dart';
import 'package:dart_skills_lint/src/models/skill_rule.dart';
import 'package:dart_skills_lint/src/models/validation_error.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class RuleA extends SkillRule implements FixableRule {
  @override
  String get name => 'rule-a';

  @override
  AnalysisSeverity get severity => AnalysisSeverity.warning;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    return [
      ValidationError(
        ruleId: name,
        message: 'Error A',
        severity: AnalysisSeverity.warning,
        file: 'SKILL.md',
      ),
    ];
  }

  @override
  Future<String> fix(String filePath, String currentContent, Directory directory) async {
    return '$currentContent A';
  }
}

class RuleB extends SkillRule implements FixableRule {
  @override
  String get name => 'rule-b';

  @override
  AnalysisSeverity get severity => AnalysisSeverity.warning;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    return [
      ValidationError(
        ruleId: name,
        message: 'Error B',
        severity: AnalysisSeverity.warning,
        file: 'SKILL.md',
      ),
    ];
  }

  @override
  Future<String> fix(String filePath, String currentContent, Directory directory) async {
    return '$currentContent B';
  }
}

class RuleThrows extends SkillRule implements FixableRule {
  @override
  String get name => 'rule-throws';

  @override
  AnalysisSeverity get severity => AnalysisSeverity.warning;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    return [
      ValidationError(
        ruleId: name,
        message: 'Error Throws',
        severity: AnalysisSeverity.warning,
        file: 'SKILL.md',
      ),
    ];
  }

  @override
  Future<String> fix(String filePath, String currentContent, Directory directory) async {
    throw Exception('Fix failed');
  }
}

void main() {
  group('Fixer Sequential Execution', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fixer_test.');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('applies fixes in order', () async {
      final skillDir = Directory(p.join(tempDir.path, 'test-skill'));
      await skillDir.create();
      final skillFile = File(p.join(skillDir.path, 'SKILL.md'));
      await skillFile.writeAsString('Original');

      final bool success = await validateSkillsInternal(
        individualSkillPaths: [skillDir.path],
        fixApply: true,
        quiet: true,
        customRules: [RuleA(), RuleB()],
      );

      expect(success, isFalse);

      final String content = await skillFile.readAsString();
      expect(content, 'Original A B');
    });

    test(
      '--fast-fail stops processing subsequent skills but completes current skill fixes',
      () async {
        final skillDir1 = Directory(p.join(tempDir.path, 'test-skill-1'));
        await skillDir1.create();
        final skillFile1 = File(p.join(skillDir1.path, 'SKILL.md'));
        await skillFile1.writeAsString('Original1');

        final skillDir2 = Directory(p.join(tempDir.path, 'test-skill-2'));
        await skillDir2.create();
        final skillFile2 = File(p.join(skillDir2.path, 'SKILL.md'));
        await skillFile2.writeAsString('Original2');

        final bool success = await validateSkillsInternal(
          individualSkillPaths: [skillDir1.path, skillDir2.path],
          fixApply: true,
          fastFail: true,
          quiet: true,
          customRules: [RuleA()],
        );

        expect(success, isFalse);

        final String content1 = await skillFile1.readAsString();
        expect(content1, 'Original1 A');

        final String content2 = await skillFile2.readAsString();
        expect(content2, 'Original2');
      },
    );

    test('handles exceptions in fix method gracefully', () async {
      final skillDir = Directory(p.join(tempDir.path, 'test-skill'));
      await skillDir.create();
      final skillFile = File(p.join(skillDir.path, 'SKILL.md'));
      await skillFile.writeAsString('Original');

      final bool success = await validateSkillsInternal(
        individualSkillPaths: [skillDir.path],
        fixApply: true,
        quiet: true,
        customRules: [RuleThrows()],
      );

      expect(success, isFalse);

      final String content = await skillFile.readAsString();
      expect(content, 'Original');
    });
  });
}
