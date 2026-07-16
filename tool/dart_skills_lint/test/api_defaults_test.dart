// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:dart_skills_lint/src/rules/description_length_rule.dart';
import 'package:dart_skills_lint/src/rules/trailing_whitespace_rule.dart';
import 'package:dart_skills_lint/src/rules/valid_yaml_metadata_rule.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  test('validateSkills applies default rules when not specified', () async {
    await withTempDir((tempDir) async {
      final Directory skillDir = await createDummySkill(
        tempDir,
        name: 'test-skill',
        skillContent: 'Invalid YAML No Frontmatter',
      );

      // Call validateSkills with empty overrides.
      // It should apply default rules, including valid-yaml-metadata.
      final bool isValid = await validateSkills(individualSkillPaths: [skillDir.path]);

      expect(isValid, isFalse, reason: 'Should fail due to default rule valid-yaml-metadata.');
    });
  });

  test('Validator skips disabled rules', () async {
    await withTempDir((tempDir) async {
      final Directory skillDir = await createDummySkill(
        tempDir,
        name: 'test-skill',
        skillContent: 'Invalid YAML No Frontmatter',
      );

      // Create validator with the rule disabled.
      final validator = Validator(
        ruleConfigs: {
          ValidYamlMetadataRule.ruleName: RuleConfig(severity: AnalysisSeverity.disabled),
        },
      );
      final ValidationResult result = await validator.validate(skillDir);

      final bool hasYamlError = result.validationErrors.any(
        (e) => e.ruleId == ValidYamlMetadataRule.ruleName,
      );
      expect(
        hasYamlError,
        isFalse,
        reason: 'Should not have valid-yaml-metadata error when disabled.',
      );
    });
  });

  test('loadConfig resolves tilde in custom config path', () async {
    final String? home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    expect(home, isNotNull, reason: 'HOME or USERPROFILE environment variable must be set.');

    final tempFile = File(p.join(home!, 'dart_skills_lint_temp_test.yaml'));
    await tempFile.writeAsString('''
dart_skills_lint:
  rules:
    check-relative-paths: error
''');

    try {
      // Under the current code, this will fail because loadConfig does not do tilde expansion.
      final Configuration config = await ConfigParser.loadConfig(
        path: '~/dart_skills_lint_temp_test.yaml',
      );
      expect(config.ruleConfigs, contains('check-relative-paths'));
    } finally {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    }
  });

  test('Path resolution avoids collision with prefix-sharing directories', () async {
    await withTempDir((tempDir) async {
      // We create two directories: 'skills-tests/test-skill' (the one being evaluated)
      // and 'skills' (the one defined in config)
      final configDir = Directory(p.join(tempDir.path, 'skills'));
      final Directory skillDir = await createDummySkill(
        tempDir,
        name: 'skills-tests/test-skill',
        skillContent: '''
---
name: test-skill
description: A test skill
---
Line with space 
''', // Trailing space
      );

      // Create a Configuration with rules enabled specifically for 'skills'
      final config = Configuration(
        directoryConfigs: [
          LintTargetConfig(
            path: configDir.path,
            ruleConfigs: {
              TrailingWhitespaceRule.ruleName: const RuleConfigPatch(
                severity: AnalysisSeverity.error,
              ),
            },
          ),
        ],
      );

      // Call validateSkills. Under unsafe prefix-matching, 'skills-tests'
      // starts with 'skills' (prefix collision) and enables trailing whitespace checks as error.
      // It should pass because 'skills-tests' is NOT the same directory as 'skills'.
      final bool isValid = await validateSkills(
        individualSkillPaths: [skillDir.path],
        config: config,
      );

      expect(
        isValid,
        isTrue,
        reason: 'Should pass because skills-tests does not match configuration for skills.',
      );
    });
  });

  test('loadConfig captures YAML parsing errors in Configuration.parsingErrors', () async {
    await withTempDir((tempDir) async {
      final configFile = File(p.join(tempDir.path, 'dart_skills_lint.yaml'));
      await configFile.writeAsString('''
dart_skills_lint:
  rules:
    check-trailing-whitespace: [error, warning
'''); // unclosed bracket YAML syntax error

      final Configuration config = await ConfigParser.loadConfig(path: configFile.path);

      expect(config.parsingErrors, isNotEmpty);
      expect(config.parsingErrors.first, contains('Failed to parse'));
    });
  });

  test('Nested Directory Rule Inheritance merging and precedence override', () async {
    await withTempDir((tempDir) {
      // parent path: 'skills' (enables check-trailing-whitespace: error, description-length: warning)
      // child path: 'skills/nested' (enables description-length: error, check-trailing-whitespace: disabled)
      final config = Configuration(
        directoryConfigs: [
          LintTargetConfig(
            path: p.join(tempDir.path, 'skills'),
            ruleConfigs: {
              TrailingWhitespaceRule.ruleName: const RuleConfigPatch(
                severity: AnalysisSeverity.error,
              ),
              DescriptionLengthRule.ruleName: const RuleConfigPatch(
                severity: AnalysisSeverity.warning,
              ),
            },
          ),
          LintTargetConfig(
            path: p.join(tempDir.path, 'skills/nested'),
            ruleConfigs: {
              DescriptionLengthRule.ruleName: const RuleConfigPatch(
                severity: AnalysisSeverity.error,
              ),
              TrailingWhitespaceRule.ruleName: const RuleConfigPatch(
                severity: AnalysisSeverity.disabled,
              ),
            },
          ),
        ],
      );

      final session = ValidationSession(
        config: config,
        ignoreFileOverride: null,
        customRules: [],
        printWarnings: true,
        fastFail: false,
        quiet: true,
        generateBaseline: false,
        fix: false,
        fixApply: false,
      );

      // Parent path should have parent rules applied
      final Map<String, RuleConfig> parentRules = session.resolveRuleConfigsForPath(
        p.join(tempDir.path, 'skills/some-skill'),
      );
      expect(
        parentRules[TrailingWhitespaceRule.ruleName]?.severity,
        equals(AnalysisSeverity.error),
      );
      expect(
        parentRules[DescriptionLengthRule.ruleName]?.severity,
        equals(AnalysisSeverity.warning),
      );

      // Child path should merge and override parent rules
      final Map<String, RuleConfig> childRules = session.resolveRuleConfigsForPath(
        p.join(tempDir.path, 'skills/nested/nested-skill'),
      );
      expect(
        childRules[TrailingWhitespaceRule.ruleName]?.severity,
        equals(AnalysisSeverity.disabled),
      ); // child override
      expect(
        childRules[DescriptionLengthRule.ruleName]?.severity,
        equals(AnalysisSeverity.error),
      ); // child override
    });
  });

  test('Nested Directory Ignore File Inheritance', () async {
    await withTempDir((tempDir) {
      // parent path: 'skills' (defines ignoreFile)
      // child path: 'skills/nested' (does not define ignoreFile, should inherit)
      final config = Configuration(
        directoryConfigs: [
          LintTargetConfig(
            path: p.join(tempDir.path, 'skills'),
            ignoreFile: 'parent_ignores.json',
            ruleConfigs: const {},
          ),
          LintTargetConfig(path: p.join(tempDir.path, 'skills/nested'), ruleConfigs: const {}),
        ],
      );

      final session = ValidationSession(
        config: config,
        ignoreFileOverride: null,
        customRules: [],
        printWarnings: true,
        fastFail: false,
        quiet: true,
        generateBaseline: false,
        fix: false,
        fixApply: false,
      );

      // Parent ignore file should match
      expect(
        session.resolveIgnoreFile(p.join(tempDir.path, 'skills/some-skill')),
        equals('parent_ignores.json'),
      );

      // Child should inherit parent ignore file
      expect(
        session.resolveIgnoreFile(p.join(tempDir.path, 'skills/nested/nested-skill')),
        equals('parent_ignores.json'),
      );
    });
  });

  test('Absolute vs. Relative Path Resolution matching', () {
    // Config defines path as relative 'skills'
    final config = Configuration(
      directoryConfigs: [
        LintTargetConfig(
          path: 'skills',
          ruleConfigs: {
            TrailingWhitespaceRule.ruleName: const RuleConfigPatch(
              severity: AnalysisSeverity.error,
            ),
          },
        ),
      ],
    );

    final session = ValidationSession(
      config: config,
      ignoreFileOverride: null,
      customRules: [],
      printWarnings: true,
      fastFail: false,
      quiet: true,
      generateBaseline: false,
      fix: false,
      fixApply: false,
    );

    // 1. Evaluate relative input: 'skills/my-skill'
    final Map<String, RuleConfig> relativeRules = session.resolveRuleConfigsForPath(
      'skills/my-skill',
    );
    expect(
      relativeRules[TrailingWhitespaceRule.ruleName]?.severity,
      equals(AnalysisSeverity.error),
    );

    // 2. Evaluate absolute input
    final String absoluteInput = p.absolute('skills/my-skill');
    final Map<String, RuleConfig> absoluteRules = session.resolveRuleConfigsForPath(absoluteInput);
    expect(
      absoluteRules[TrailingWhitespaceRule.ruleName]?.severity,
      equals(AnalysisSeverity.error),
    );
  });
}
