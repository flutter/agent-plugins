// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/models/skill_context.dart';
import 'package:dart_skills_lint/src/rules/description_length_rule.dart';
import 'package:dart_skills_lint/src/rules/name_format_rule.dart';
import 'package:dart_skills_lint/src/rules/valid_yaml_metadata_rule.dart';
import 'package:dart_skills_lint/src/validator.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

void main() {
  group('Field Specific Constraints Validation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fields_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Skill Name', () {
      test('fails if not lowercase', () async {
        final Directory skillDir = await Directory('${tempDir.path}/Skill-Name').create();
        await File('${skillDir.path}/SKILL.md').writeAsString('${buildFrontmatter()}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(result.errors, contains(contains('lowercase')));
      });

      test('fails if too long (> ${NameFormatRule.maxNameLength} chars)', () async {
        final String longName = 'a' * (NameFormatRule.maxNameLength + 1);
        final Directory skillDir = await Directory('${tempDir.path}/$longName').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: longName)}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(
          result.errors,
          contains(contains('Maximum ${NameFormatRule.maxNameLength} characters')),
        );
      });

      test('fails if contains invalid characters', () async {
        final Directory skillDir = await Directory('${tempDir.path}/skill_name').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'skill_name')}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(result.errors, contains(contains('lowercase letters, digits, and hyphens')));
      });

      test('fails if has leading hyphen', () async {
        final Directory skillDir = await Directory('${tempDir.path}/-skill-name').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: '-skill-name')}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(result.errors, contains(contains('leading or trailing hyphens')));
      });

      test('fails if has trailing hyphen', () async {
        final Directory skillDir = await Directory('${tempDir.path}/skill-name-').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'skill-name-')}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(result.errors, contains(contains('leading or trailing hyphens')));
      });

      test('fails if has consecutive hyphens', () async {
        final Directory skillDir = await Directory('${tempDir.path}/skill--name').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'skill--name')}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(result.errors, contains(contains('consecutive hyphens')));
      });

      test('fails if name does not match directory name', () async {
        final Directory skillDir = await Directory('${tempDir.path}/wrong-name').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'right-name')}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(result.errors, contains(contains('must exactly match the parent directory name')));
      });

      test('fixes name to match directory name (not replacing underscores)', () async {
        final Directory skillDir = await Directory('${tempDir.path}/my_skill').create();
        final file = File('${skillDir.path}/SKILL.md');
        await file.writeAsString('''
---
name: wrong-name
description: A test skill
---
Body''');

        final rule = NameFormatRule();
        final String content = await file.readAsString();
        final RegExpMatch? match = RegExp(
          r'^---\s*\n(.*?)\n---\s*\n',
          dotAll: true,
        ).firstMatch(content);
        final parsedYaml = loadYaml(match!.group(1)!) as YamlMap?;
        final context = SkillContext(
          directory: skillDir,
          rawContent: content,
          parsedYaml: parsedYaml,
        );

        final String fixedContent = await rule.fix('SKILL.md', content, context.directory);

        expect(fixedContent, contains('name: my_skill'));
      });
    });

    group('Description', () {
      test('fails if too long (> ${DescriptionLengthRule.maxDescriptionLength} chars)', () async {
        final String longDesc = 'a' * (DescriptionLengthRule.maxDescriptionLength + 1);
        final Directory skillDir = await Directory('${tempDir.path}/skill-name').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'skill-name', description: longDesc)}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(
          result.errors,
          contains(contains('Maximum ${DescriptionLengthRule.maxDescriptionLength} characters')),
        );
      });
    });

    group('Compatibility', () {
      test('fails if too long (> ${ValidYamlMetadataRule.maxCompatibilityLength} chars)', () async {
        final String longComp = 'a' * (ValidYamlMetadataRule.maxCompatibilityLength + 1);
        final Directory skillDir = await Directory('${tempDir.path}/skill-name').create();
        await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: skill-name
description: A test skill
compatibility: $longComp
---
Body''');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(
          result.errors,
          contains(contains('Maximum ${ValidYamlMetadataRule.maxCompatibilityLength} characters')),
        );
      });
    });
  });
}
