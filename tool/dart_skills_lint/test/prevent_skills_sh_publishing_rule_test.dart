// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/skill_context.dart';
import 'package:dart_skills_lint/src/models/validation_error.dart';
import 'package:dart_skills_lint/src/rules/prevent_skills_sh_publishing_rule.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('PreventSkillsShPublishingRule', () {
    test('flags when YAML frontmatter is completely missing', () async {
      final rule = PreventSkillsShPublishingRule(severity: AnalysisSeverity.warning);
      final context = SkillContext(
        directory: Directory('dummy'),
        rawContent: 'Just some text, no frontmatter.',
      );

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('Missing YAML frontmatter'));
    });

    test('returns no errors when there is a YAML parsing error', () async {
      final rule = PreventSkillsShPublishingRule(severity: AnalysisSeverity.warning);
      final context = SkillContext(
        directory: Directory('dummy'),
        rawContent: '---\ninvalid: yaml: : mapping\n---\n',
        yamlParsingError: 'YAML parsing error details',
      );

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isEmpty);
    });

    test('flags when metadata field is missing', () async {
      final rule = PreventSkillsShPublishingRule(severity: AnalysisSeverity.warning);
      final context = SkillContext(
        directory: Directory('dummy'),
        rawContent: '---\nname: my-skill\ndescription: Test\n---\n',
        parsedYaml: loadYaml('name: my-skill\ndescription: Test\n') as YamlMap,
      );

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('Missing "metadata" block in YAML frontmatter.'));
    });

    test('flags when metadata is not a map', () async {
      final rule = PreventSkillsShPublishingRule(severity: AnalysisSeverity.warning);
      final parsed =
          loadYaml('name: my-skill\ndescription: Test\nmetadata: "some string"\n') as YamlMap;
      final context = SkillContext(
        directory: Directory('dummy'),
        rawContent: '---\nname: my-skill\ndescription: Test\nmetadata: "some string"\n---\n',
        parsedYaml: parsed,
      );

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('"metadata" must be a YAML mapping (dictionary).'));
    });

    test('flags when metadata internal is false', () async {
      final rule = PreventSkillsShPublishingRule(severity: AnalysisSeverity.warning);
      final parsed =
          loadYaml('name: my-skill\ndescription: Test\nmetadata:\n  internal: false\n') as YamlMap;
      final context = SkillContext(
        directory: Directory('dummy'),
        rawContent: '---\nname: my-skill\ndescription: Test\nmetadata:\n  internal: false\n---\n',
        parsedYaml: parsed,
      );

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isNotEmpty);
      expect(
        errors.first.message,
        contains('The "internal" field under "metadata" must be explicitly set to boolean true'),
      );
    });

    test('flags when metadata internal is a string', () async {
      final rule = PreventSkillsShPublishingRule(severity: AnalysisSeverity.warning);
      final parsed =
          loadYaml('name: my-skill\ndescription: Test\nmetadata:\n  internal: "True"\n') as YamlMap;
      final context = SkillContext(
        directory: Directory('dummy'),
        rawContent: '---\nname: my-skill\ndescription: Test\nmetadata:\n  internal: "True"\n---\n',
        parsedYaml: parsed,
      );

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('is set to a string "True"'));
    });

    test('flags when metadata internal is a string with whitespace', () async {
      final rule = PreventSkillsShPublishingRule(severity: AnalysisSeverity.warning);
      final parsed =
          loadYaml('name: my-skill\ndescription: Test\nmetadata:\n  internal: "  True  "\n')
              as YamlMap;
      final context = SkillContext(
        directory: Directory('dummy'),
        rawContent:
            '---\nname: my-skill\ndescription: Test\nmetadata:\n  internal: "  True  "\n---\n',
        parsedYaml: parsed,
      );

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('is set to a string "  True  "'));
    });

    test('passes when metadata internal is true', () async {
      final rule = PreventSkillsShPublishingRule(severity: AnalysisSeverity.warning);
      final parsed =
          loadYaml('name: my-skill\ndescription: Test\nmetadata:\n  internal: true\n') as YamlMap;
      final context = SkillContext(
        directory: Directory('dummy'),
        rawContent: '---\nname: my-skill\ndescription: Test\nmetadata:\n  internal: true\n---\n',
        parsedYaml: parsed,
      );

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isEmpty);
    });
  });
}
