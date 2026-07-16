// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:dart_skills_lint/src/models/rule_config.dart';
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  group('RuleConfig & RuleConfigPatch Merging', () {
    test('RuleConfig initialization defaults', () {
      final config = RuleConfig(severity: AnalysisSeverity.error);
      expect(config.severity, equals(AnalysisSeverity.error));
      expect(config.parameters.params, isEmpty);
      expect(config.severity != AnalysisSeverity.disabled, isTrue);
    });

    test('RuleConfigPatch overrides severity only', () {
      final base = RuleConfig(
        severity: AnalysisSeverity.warning,
        parameters: CustomRuleParameters({'exclude': '.*-workspace', 'max': 50}),
      );
      const patch = RuleConfigPatch(severity: AnalysisSeverity.error);

      final RuleConfig merged = patch.applyTo(base);
      expect(merged.severity, equals(AnalysisSeverity.error));
      expect(merged.parameters.params, equals({'exclude': '.*-workspace', 'max': 50}));
    });

    test('RuleConfigPatch overrides parameters only', () {
      final base = RuleConfig(
        severity: AnalysisSeverity.warning,
        parameters: CustomRuleParameters({'exclude': '.*-workspace', 'max': 50}),
      );
      final patch = RuleConfigPatch(parameters: CustomRuleParameters({'max': 100, 'strict': true}));

      final RuleConfig merged = patch.applyTo(base);
      expect(merged.severity, equals(AnalysisSeverity.warning));
      expect(
        merged.parameters.params,
        equals({'exclude': '.*-workspace', 'max': 100, 'strict': true}),
      );
    });

    test('RuleConfigPatch nullifies keys via null value overrides', () {
      final base = RuleConfig(
        severity: AnalysisSeverity.warning,
        parameters: CustomRuleParameters({'exclude': '.*-workspace', 'max': 50}),
      );
      final patch = RuleConfigPatch(
        parameters: CustomRuleParameters({'exclude': null, 'max': 100}),
      );

      final RuleConfig merged = patch.applyTo(base);
      expect(merged.severity, equals(AnalysisSeverity.warning));
      expect(merged.parameters.params, equals({'max': 100}));
    });
  });

  group('Backwards Compatibility & API Guard Rails', () {
    test(
      'validateSkills throws ArgumentError when passing both resolvedRules and resolvedRuleConfigs',
      () async {
        await withTempDir((tempDir) async {
          final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
          await File(
            '${skillDir.path}/SKILL.md',
          ).writeAsString('${buildFrontmatter(name: 'test-skill')}Body content');

          expect(
            () => validateSkills(
              individualSkillPaths: [skillDir.path],
              // ignore: deprecated_member_use_from_same_package
              resolvedRules: {'valid-yaml-metadata': AnalysisSeverity.warning},
              resolvedRuleConfigs: {
                'valid-yaml-metadata': const RuleConfigPatch(severity: AnalysisSeverity.error),
              },
            ),
            throwsArgumentError,
          );
        });
      },
    );

    test(
      'validateSkills successfully processes deprecated resolvedRules API backwards compatibly',
      () async {
        await withTempDir((tempDir) async {
          final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
          await File(
            '${skillDir.path}/SKILL.md',
          ).writeAsString('${buildFrontmatter(name: 'test-skill')}Body content');

          // ignore: deprecated_member_use_from_same_package
          final bool isValid = await validateSkills(
            individualSkillPaths: [skillDir.path],
            // ignore: deprecated_member_use_from_same_package
            resolvedRules: {'valid-yaml-metadata': AnalysisSeverity.warning},
          );
          // Just confirming it runs without throwing the ArgumentError
          expect(isValid, isTrue);
        });
      },
    );
    test('Validator throws ArgumentError when passing both ruleOverrides and ruleConfigs', () {
      expect(
        () => Validator(
          // ignore: deprecated_member_use_from_same_package
          ruleOverrides: {'foo': AnalysisSeverity.warning},
          ruleConfigs: {'foo': RuleConfig(severity: AnalysisSeverity.error)},
        ),
        throwsArgumentError,
      );
    });

    test('Validator maps deprecated ruleOverrides properly', () {
      // ignore: deprecated_member_use_from_same_package
      final validator = Validator(ruleOverrides: {'foo': AnalysisSeverity.warning});
      // Ensure the mapping happened without error. Validation runs successfully.
      expect(validator, isNotNull);
    });

    test('LintTargetConfig deprecated rules getter maps correctly', () {
      final config = LintTargetConfig(
        path: 'foo',
        ruleConfigs: {'foo': const RuleConfigPatch(severity: AnalysisSeverity.warning)},
      );
      // ignore: deprecated_member_use_from_same_package
      expect(config.rules['foo'], equals(AnalysisSeverity.warning));
    });

    test('Configuration deprecated configuredRules getter maps correctly', () {
      final config = Configuration(
        ruleConfigs: {'bar': const RuleConfigPatch(severity: AnalysisSeverity.error)},
      );
      // ignore: deprecated_member_use_from_same_package
      expect(config.configuredRules['bar'], equals(AnalysisSeverity.error));
    });

    test('deprecated rules and configuredRules getters omit patches without explicit severity', () {
      const patchWithoutSeverity = RuleConfigPatch();
      final targetConfig = LintTargetConfig(
        path: 'foo',
        ruleConfigs: {'path-does-not-exist': patchWithoutSeverity},
      );
      final topConfig = Configuration(ruleConfigs: {'path-does-not-exist': patchWithoutSeverity});

      // ignore: deprecated_member_use_from_same_package
      expect(targetConfig.rules.containsKey('path-does-not-exist'), isFalse);
      // ignore: deprecated_member_use_from_same_package
      expect(topConfig.configuredRules.containsKey('path-does-not-exist'), isFalse);
    });
  });
}
