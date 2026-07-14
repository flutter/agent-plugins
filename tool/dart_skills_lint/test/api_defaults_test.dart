// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_skills_lint/dart_skills_lint.dart';
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
        customRuleSeverities: {'valid-yaml-metadata': AnalysisSeverity.disabled},
      );
      final ValidationResult result = await validator.validate(skillDir);

      final bool hasYamlError = result.validationErrors.any(
        (e) => e.ruleId == 'valid-yaml-metadata',
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
      expect(config.ruleSeverities, contains('check-relative-paths'));
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
            ruleSeverities: {'check-trailing-whitespace': AnalysisSeverity.error},
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
            ruleSeverities: {
              'check-trailing-whitespace': AnalysisSeverity.error,
              'description-length': AnalysisSeverity.warning,
            },
          ),
          LintTargetConfig(
            path: p.join(tempDir.path, 'skills/nested'),
            ruleSeverities: {
              'description-length': AnalysisSeverity.error,
              'check-trailing-whitespace': AnalysisSeverity.disabled,
            },
          ),
        ],
      );

      final session = ValidationSession(
        config: config,
        resolvedRuleSeverities: {},
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
      final Map<String, AnalysisSeverity> parentRules = session.resolveRuleSeveritiesForPath(
        p.join(tempDir.path, 'skills/some-skill'),
      );
      expect(parentRules['check-trailing-whitespace'], equals(AnalysisSeverity.error));
      expect(parentRules['description-length'], equals(AnalysisSeverity.warning));

      // Child path should merge and override parent rules
      final Map<String, AnalysisSeverity> childRules = session.resolveRuleSeveritiesForPath(
        p.join(tempDir.path, 'skills/nested/nested-skill'),
      );
      expect(
        childRules['check-trailing-whitespace'],
        equals(AnalysisSeverity.disabled),
      ); // child override
      expect(childRules['description-length'], equals(AnalysisSeverity.error)); // child override
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
            ruleSeverities: <String, AnalysisSeverity>{},
          ),
          LintTargetConfig(
            path: p.join(tempDir.path, 'skills/nested'),
            ruleSeverities: <String, AnalysisSeverity>{},
          ),
        ],
      );

      final session = ValidationSession(
        config: config,
        resolvedRuleSeverities: {},
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
          ruleSeverities: {'check-trailing-whitespace': AnalysisSeverity.error},
        ),
      ],
    );

    final session = ValidationSession(
      config: config,
      resolvedRuleSeverities: {},
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
    final Map<String, AnalysisSeverity> relativeRules = session.resolveRuleSeveritiesForPath(
      'skills/my-skill',
    );
    expect(relativeRules['check-trailing-whitespace'], equals(AnalysisSeverity.error));

    // 2. Evaluate absolute input
    final String absoluteInput = p.absolute('skills/my-skill');
    final Map<String, AnalysisSeverity> absoluteRules = session.resolveRuleSeveritiesForPath(
      absoluteInput,
    );
    expect(absoluteRules['check-trailing-whitespace'], equals(AnalysisSeverity.error));
  });
}
