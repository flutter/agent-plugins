import 'dart:async';
import 'dart:io';
import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

class CustomRule extends SkillRule {
  @override
  final String name = 'custom-rule';

  @override
  final AnalysisSeverity severity = AnalysisSeverity.error;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];
    if (context.rawContent.contains('TRIGGER_ERROR')) {
      errors.add(
        ValidationError(
          ruleId: name,
          severity: severity,
          file: 'SKILL.md',
          message: 'Custom rule triggered',
        ),
      );
    }
    return errors;
  }
}

class MismatchRule extends SkillRule {
  @override
  final String name = 'mismatch-rule';

  @override
  final AnalysisSeverity severity = AnalysisSeverity.warning;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    return [
      ValidationError(
        ruleId: name,
        severity: AnalysisSeverity.error, // Mismatch!
        file: 'SKILL.md',
        message: 'Triggered',
      ),
    ];
  }
}

void main() {
  group('Custom Rules', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('custom_rule_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Validator runs custom rule', () async {
      final Directory skillDir = await Directory('${tempDir.path}/skill-name').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: skill-name
description: A test skill
---
TRIGGER_ERROR''');

      final validator = Validator(customRules: [CustomRule()]);
      final ValidationResult result = await validator.validate(skillDir);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Custom rule triggered')));
    });

    test('Validator logs warning on severity mismatch', () async {
      final Directory skillDir = await Directory('${tempDir.path}/skill-name-3').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: skill-name-3
description: A test skill
---
Body''');

      final validator = Validator(customRules: [MismatchRule()]);

      final logs = <String>[];
      final StreamSubscription<LogRecord> subscription = Logger('dart_skills_lint').onRecord.listen(
        (record) {
          logs.add(record.message);
        },
      );

      try {
        await validator.validate(skillDir);
      } finally {
        await subscription.cancel();
      }

      expect(
        logs,
        contains(
          contains(
            'Rule "mismatch-rule" used severity AnalysisSeverity.error instead of defined AnalysisSeverity.warning',
          ),
        ),
      );
    });

    test('Validator throws ArgumentError on duplicate rule names', () {
      final rule1 = CustomRule();
      final rule2 = CustomRule(); // Same name 'custom-rule'

      expect(() => Validator(customRules: [rule1, rule2]), throwsArgumentError);
    });
  });
}
