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
      test('fails if not lowercase, error names the frontmatter field', () async {
        final Directory skillDir = await Directory('${tempDir.path}/Skill-Name').create();
        await File('${skillDir.path}/SKILL.md').writeAsString('${buildFrontmatter()}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(
          result.errors,
          contains(contains('Frontmatter `name` "Skill-Name" must be lowercase')),
        );
        expect(result.errors, contains(contains('Suggested: "skill-name"')));
      });

      test('fails if too long, error reports both lengths and names the field', () async {
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
          contains(contains('Frontmatter `name` is ${longName.length} characters')),
        );
        expect(result.errors, contains(contains('maximum is ${NameFormatRule.maxNameLength}')));
      });

      test('fails if contains invalid characters; suggests hyphen-normalized form', () async {
        final Directory skillDir = await Directory('${tempDir.path}/skill_name').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'skill_name')}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(
          result.errors,
          contains(contains('Frontmatter `name` "skill_name" contains invalid characters')),
        );
        expect(result.errors, contains(contains('Suggested: "skill-name"')));
      });

      test('fails if has leading hyphen; suggests stripped form', () async {
        final Directory skillDir = await Directory('${tempDir.path}/-skill-name').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: '-skill-name')}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(result.errors, contains(contains('"-skill-name" has leading or trailing hyphens')));
        expect(result.errors, contains(contains('Suggested: "skill-name"')));
      });

      test('fails if has trailing hyphen; suggests stripped form', () async {
        final Directory skillDir = await Directory('${tempDir.path}/skill-name-').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'skill-name-')}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(result.errors, contains(contains('"skill-name-" has leading or trailing hyphens')));
        expect(result.errors, contains(contains('Suggested: "skill-name"')));
      });

      test('fails if has consecutive hyphens; suggests collapsed form', () async {
        final Directory skillDir = await Directory('${tempDir.path}/skill--name').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'skill--name')}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(result.errors, contains(contains('"skill--name" has consecutive hyphens')));
        expect(result.errors, contains(contains('Suggested: "skill-name"')));
      });

      test('mismatched name vs dir: error offers both directions to fix', () async {
        final Directory skillDir = await Directory('${tempDir.path}/wrong-name').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'right-name')}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);
        expect(
          result.errors,
          contains(
            contains(
              'Frontmatter `name` "right-name" does not match the parent '
              'directory name "wrong-name"',
            ),
          ),
        );
        expect(result.errors, contains(contains('setting `name: wrong-name` in SKILL.md')));
        expect(
          result.errors,
          contains(contains('renaming the directory from "wrong-name" to "right-name"')),
        );
      });

      test('suggestNormalizedName normalizes case, separators, edges, length', () {
        expect(NameFormatRule.suggestNormalizedName('My_Cool Skill!'), 'my-cool-skill');
        expect(NameFormatRule.suggestNormalizedName('--leading--double--'), 'leading-double');
        expect(
          NameFormatRule.suggestNormalizedName('a' * (NameFormatRule.maxNameLength + 10)),
          'a' * NameFormatRule.maxNameLength,
        );
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
          contains(contains('maximum is ${DescriptionLengthRule.maxDescriptionLength}')),
        );
      });

      test('error message includes char count and |HERE| cutoff excerpt', () async {
        // 50 chars before, 50 chars after the cutoff for a distinctive excerpt.
        final String before = 'B' * 50;
        final String after = 'A' * 50;
        final String longDesc =
            'P' * (DescriptionLengthRule.maxDescriptionLength - 50) + before + after;
        expect(longDesc.length, DescriptionLengthRule.maxDescriptionLength + 50);

        final Directory skillDir = await Directory('${tempDir.path}/skill-name').create();
        await File(
          '${skillDir.path}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'skill-name', description: longDesc)}Body');
        final validator = Validator();
        final ValidationResult result = await validator.validate(skillDir);
        expect(result.isValid, isFalse);

        final String error = result.errors.firstWhere((e) => e.contains('Description field is'));
        expect(error, contains('Description field is ${longDesc.length} characters'));
        expect(error, contains('maximum is ${DescriptionLengthRule.maxDescriptionLength}'));
        expect(
          error,
          contains('Cutoff at character ${DescriptionLengthRule.maxDescriptionLength}'),
        );
        expect(error, contains('|HERE|'));
        // The chars right before/after the cutoff should appear in the excerpt.
        expect(error, contains('BBBBB|HERE|AAAAA'));
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
