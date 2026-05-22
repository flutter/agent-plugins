// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:dart_skills_lint/src/entry_point.dart';
import 'package:dart_skills_lint/src/models/check_type.dart';
import 'package:dart_skills_lint/src/models/ignore_entry.dart';
import 'package:dart_skills_lint/src/models/skills_ignores.dart';
import 'package:dart_skills_lint/src/rule_registry.dart';
import 'package:dart_skills_lint/src/validator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

import 'test_utils.dart';

void main() {
  group('CLI Integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cli_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('de-duplicates baseline entries for multiple identical rule failures', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'test-skill')}[Link 1](missing1.md)\n[Link 2](missing2.md)\n',
      );

      // Run with --generate-baseline
      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
        '--generate-baseline',
      ]);
      await process.shouldExit(0);

      final ignoreFile = File('${skillDir.parent.path}/$defaultIgnoreFileName');
      expect(ignoreFile.existsSync(), isTrue);

      final String content = await ignoreFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final skills = json[SkillsIgnores.skillsKey] as Map<String, dynamic>;
      final ignores = skills['test-skill'] as List;

      // Should be 1 entry only! Both relative link failures utilize the same ruleId/fileName de-duplication.
      expect(ignores.length, equals(1));
    });

    test('individual skill baseline is loaded on subsequent runs', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'test-skill')}[Link](missing.md)\n');

      final TestProcess genProcess = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
        '--generate-baseline',
      ]);
      await genProcess.shouldExit(0);

      final ignoreFile = File('${tempDir.path}/$defaultIgnoreFileName');
      expect(ignoreFile.existsSync(), isTrue);

      final TestProcess runProcess = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
      ]);
      await runProcess.shouldExit(0);
    });

    test(
      'cross-skill baseline de-duplicates and suppresses all errors across different skills',
      () async {
        final Directory skillsDir = await Directory('${tempDir.path}/skills').create();

        // Create skill-one with a broken link
        final Directory skill1Dir = await Directory('${skillsDir.path}/skill-one').create();
        await File('${skill1Dir.path}/SKILL.md').writeAsString(
          '${buildFrontmatter(name: 'skill-one', description: 'Skill one with a broken link')}[Link to nowhere](../nowhere/SKILL.md)\n',
        );

        // Create skill-two with a broken link
        final Directory skill2Dir = await Directory('${skillsDir.path}/skill-two').create();
        await File('${skill2Dir.path}/SKILL.md').writeAsString(
          '${buildFrontmatter(name: 'skill-two', description: 'Skill two with a broken link')}[Link to nowhere](../nowhere/SKILL.md)\n',
        );

        final configFile = File('${tempDir.path}/dart_skills_lint.yaml');
        await configFile.writeAsString('''
dart_skills_lint:
  directories:
    - path: "skills"
      rules:
        check-relative-paths: error
      ignore_file: "$defaultIgnoreFileName"
''');

        // 1. Run with --generate-baseline. It should evaluate all skills and write both to the baseline!
        final TestProcess genProcess = await TestProcess.start('dart', [
          p.normalize(p.absolute('bin/cli.dart')),
          '-d',
          'skills',
          '--generate-baseline',
        ], workingDirectory: tempDir.path);
        await genProcess.shouldExit(0); // Exits 0 if --generate-baseline is passed

        final ignoreFile = File('${tempDir.path}/$defaultIgnoreFileName');
        expect(ignoreFile.existsSync(), isTrue);

        final String content = await ignoreFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final skills = json[SkillsIgnores.skillsKey] as Map<String, dynamic>;

        expect(skills.containsKey('skill-one'), isTrue);
        expect(skills.containsKey('skill-two'), isTrue);

        // 2. Run again silently. It should succeed with exit 0 because all errors are ignored!
        final TestProcess runProcess = await TestProcess.start('dart', [
          p.normalize(p.absolute('bin/cli.dart')),
          '-d',
          'skills',
          '-q',
        ], workingDirectory: tempDir.path);
        await runProcess.shouldExit(0);
      },
    );

    test('exits with 0 and success message for valid skill', () async {
      final Directory skillDir = await Directory('${tempDir.path}/valid-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'valid-skill', description: 'A valid skill')}Body');

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
      ]);

      final List<String> stdout = await process.stdout.rest.toList();
      expect(stdout.join('\n'), contains(skillIsValidMsg));
      await process.shouldExit(0);
    });

    test('exits with 1 and error message for invalid skill', () async {
      final Directory skillDir = await Directory('${tempDir.path}/invalid-skill').create();
      // SKILL.md is missing

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
      ]);

      final List<String> stderr = await process.stderr.rest.toList();
      final String stderrStr = stderr.join('\n');
      expect(stderrStr, contains(skillIsInvalidMsg));
      expect(stderrStr, contains('SKILL.md is missing'));
      await process.shouldExit(1);
    });

    test('exits with 0 and validates subdirectories if named "skills"', () async {
      final Directory skillsDir = await Directory('${tempDir.path}/skills').create();
      final Directory skill1 = await Directory('${skillsDir.path}/skill-a').create();
      await File(
        '${skill1.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'skill-a', description: 'Skill A')}Body');

      final Directory skill2 = await Directory('${skillsDir.path}/skill-b').create();
      await File(
        '${skill2.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'skill-b', description: 'Skill B')}Body');

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-d',
        skillsDir.path,
      ]);

      // Verify outputs for both skills (sorted order)
      final List<String> stdout = await process.stdout.rest.toList();
      final String stdoutStr = stdout.join('\n');
      expect(stdoutStr, contains(evaluatingDirMsg));
      expect(stdoutStr, contains('--- Validating skill: skill-a ---'));
      expect(stdoutStr, contains(skillIsValidMsg));

      expect(stdoutStr, contains('--- Validating skill: skill-b ---'));
      expect(stdoutStr, contains(skillIsValidMsg));

      await process.shouldExit(0);
    });

    test('ignores subdirectories starting with a dot "." in "skills" folder', () async {
      final Directory skillsDir = await Directory('${tempDir.path}/skills').create();
      final Directory skill1 = await Directory('${skillsDir.path}/skill-a').create();
      await File(
        '${skill1.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'skill-a', description: 'Skill A')}Body');

      await Directory('${skillsDir.path}/.dart_tool').create();

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-d',
        skillsDir.path,
      ]);

      final List<String> stdout = await process.stdout.rest.toList();
      final String stdoutStr = stdout.join('\n');
      expect(stdoutStr, contains('--- Validating skill: skill-a ---'));
      expect(stdoutStr, contains(skillIsValidMsg));
      expect(stdoutStr, isNot(contains('.dart_tool')));

      await process.shouldExit(0);
    });

    test('exits with 1 if any subdirectory skill fails in "skills" folder', () async {
      final Directory skillsDir = await Directory('${tempDir.path}/skills').create();
      final Directory skill1 = await Directory('${skillsDir.path}/skill-a').create();
      await File(
        '${skill1.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'skill-a', description: 'Skill A')}Body');

      await Directory('${skillsDir.path}/skill-b').create(); // No SKILL.md

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-d',
        skillsDir.path,
      ]);

      // Verify outputs
      final List<String> stdout = await process.stdout.rest.toList();
      expect(stdout.join('\n'), contains('--- Validating skill: skill-a ---'));
      expect(stdout.join('\n'), contains(skillIsValidMsg));

      expect(stdout.join('\n'), contains('--- Validating skill: skill-b ---'));
      final List<String> stderr = await process.stderr.rest.toList();
      expect(stderr.join('\n'), contains(skillIsInvalidMsg));
      await process.shouldExit(1);
    });

    test(
      'exits with 1 early and does not process subsequent skills if --fast-fail is passed',
      () async {
        final Directory skillsDir = await Directory('${tempDir.path}/skills').create();

        await Directory('${skillsDir.path}/skill-a').create();
        // skill-a does not create SKILL.md, so it is invalid and will fail first (sorted order)

        await Directory('${skillsDir.path}/skill-b').create();
        await File(
          '${p.join(tempDir.path, 'skills', 'skill-b')}/SKILL.md',
        ).writeAsString('${buildFrontmatter(name: 'skill-b', description: 'Skill B')}Body');

        final TestProcess process = await TestProcess.start('dart', [
          'bin/cli.dart',
          '-d',
          skillsDir.path,
          '--fast-fail',
        ]);

        // Verify outputs for skill-a
        final List<String> stdout = await process.stdout.rest.toList();
        final String stdoutStr = stdout.join('\n');
        expect(stdoutStr, contains(evaluatingDirMsg));
        expect(stdoutStr, contains('--- Validating skill: skill-a ---'));

        final List<String> stderr = await process.stderr.rest.toList();
        expect(stderr.join('\n'), contains(skillIsInvalidMsg));

        // Since process exits after skill-a, stdout should be closed and no further lines (like skill-b) should appear.
        await process.shouldExit(1);
      },
    );

    test('exits with 0 and suppresses success messages if --quiet is passed', () async {
      final Directory skillDir = await Directory('${tempDir.path}/valid-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'valid-skill', description: 'A valid skill')}Body');

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
        '--quiet',
      ]);

      await process.shouldExit(0);

      // Stdout should be empty for a valid skill in quiet mode
      final List<String> rest = await process.stdout.rest.toList();
      expect(rest, isEmpty);
    });
    test('fails with 64 when no flags passed and both defaults are missing', () async {
      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
      ], workingDirectory: tempDir.path);

      final List<String> stderr = await process.stderr.rest.toList();
      expect(stderr.join('\n'), contains('Missing skills directory. Checked defaults:'));
      await process.shouldExit(64);
    });

    test('picks up .claude/skills when no flags passed and it exists', () async {
      final Directory claudeDir = await Directory(
        '${tempDir.path}/.claude/skills',
      ).create(recursive: true);
      final Directory skillDir = await Directory('${claudeDir.path}/valid-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'valid-skill', description: 'A valid skill')}Body');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
      ], workingDirectory: tempDir.path);

      final List<String> stdout = await process.stdout.rest.toList();
      expect(stdout.join('\n'), contains('Skill is valid.'));
      await process.shouldExit(0);
    });
    test('expands ~/ to HOME environment variable', () async {
      final Directory skillDir = await Directory('${tempDir.path}/some-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'some-skill')}Body');

      final TestProcess process = await TestProcess.start(
        'dart',
        [p.normalize(p.absolute('bin/cli.dart')), '-s', '~/some-skill'],
        environment: {'HOME': tempDir.path},
      );

      final List<String> stdout = await process.stdout.rest.toList();
      expect(stdout.join('\n'), contains('Skill is valid.'));
      await process.shouldExit(0);
    });

    test('overrides valid-yaml-metadata flag to disabled', () async {
      final Directory skillDir = await Directory('${tempDir.path}/invalid-yaml').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('Invalid YAML No Frontmatter');

      // 1. Run normally. Should fail because valid-yaml-metadata defaults to true (error).
      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
      ]);
      await process.shouldExit(1);

      // 2. Run with --no-valid-yaml-metadata. Should pass because the check is disabled!
      final TestProcess noYamlProcess = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
        '--no-valid-yaml-metadata',
      ]);
      await noYamlProcess.shouldExit(0);
    });

    test('fails if -d specifies a directory with zero skills', () async {
      final Directory emptyDir = await Directory('${tempDir.path}/empty-root').create();

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-d',
        emptyDir.path,
      ]);

      await process.shouldExit(1);
      final List<String> stderr = await process.stderr.rest.toList();
      expect(
        stderr.join('\n'),
        contains('No skills found to validate in the specified directories.'),
      );
    });

    test('fails if -d specifies a single skill directory (no sub-folders found)', () async {
      final Directory skillAsRoot = await Directory('${tempDir.path}/single-skill-root').create();
      await File('${skillAsRoot.path}/SKILL.md').writeAsString(
        '${buildFrontmatter(name: 'single-skill-root', description: 'Not a root, but a skill folder.')}Body',
      );

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-d',
        skillAsRoot.path,
      ]);

      await process.shouldExit(1);
      final List<String> stderr = await process.stderr.rest.toList();
      expect(
        stderr.join('\n'),
        contains(
          'appears to be an individual skill. Use --skill / -s instead of -d / --skills-directory.',
        ),
      );
    });

    test('validates multiple skills with multiple -s flags', () async {
      final Directory skill1 = await Directory('${tempDir.path}/skill-1').create();
      await File(
        '${skill1.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'skill-1', description: 'Skill 1')}Body');

      final Directory skill2 = await Directory('${tempDir.path}/skill-2').create();
      await File(
        '${skill2.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'skill-2', description: 'Skill 2')}Body');

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skill1.path,
        '-s',
        skill2.path,
      ]);

      await process.shouldExit(0);
      final List<String> stdout = await process.stdout.rest.toList();
      final String stdoutStr = stdout.join('\n');
      expect(stdoutStr, contains('--- Validating skill: skill-1 ---'));
      expect(stdoutStr, contains('--- Validating skill: skill-2 ---'));
    });

    test('handles malformed JSON ignore-file gracefully by falling back', () async {
      final malformedFile = File('${tempDir.path}/malformed.json');
      await malformedFile.writeAsString('{ malformed json }');

      final Directory skillFolder = await Directory('${tempDir.path}/skill-x').create();
      await File(
        '${skillFolder.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'skill-x', description: 'Valid skill')}Body');

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillFolder.path,
        '--ignore-file',
        malformedFile.path,
      ]);

      await process.shouldExit(0); // Valid skill should still pass
      final List<String> stdout = await process.stdout.rest.toList();
      expect(stdout.join('\n'), contains('Evaluating directory:'));
    });

    test('CLI help displays all registered rules', () async {
      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '--help',
      ]);
      await process.shouldExit(0);
      final List<String> stdout = await process.stdout.rest.toList();
      final String stdoutStr = stdout.join('\n');

      for (final CheckType check in RuleRegistry.allChecks) {
        expect(stdoutStr, contains(check.name));
      }
    });

    test('CLI help does not display path-does-not-exist', () async {
      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '--help',
      ]);
      await process.shouldExit(0);
      final List<String> stdout = await process.stdout.rest.toList();
      final String stdoutStr = stdout.join('\n');

      expect(stdoutStr, isNot(contains(Validator.pathDoesNotExist)));
    });

    test('ignores directory missing SKILL.md if listed in ignore file', () async {
      final Directory skillsDir = await Directory('${tempDir.path}/skills').create();

      // Create a valid skill
      final Directory skillDir = await Directory('${skillsDir.path}/valid-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('---\nname: valid-skill\ndescription: A valid skill\n---\nBody');

      // Create a non-skill directory
      await Directory('${skillsDir.path}/contributing').create();

      // Create ignore file
      final ignoreFile = File('${tempDir.path}/$defaultIgnoreFileName');
      await ignoreFile.writeAsString(
        jsonEncode({
          SkillsIgnores.skillsKey: {
            'contributing': [
              {
                IgnoreEntry.ruleIdKey: Validator.pathDoesNotExist,
                IgnoreEntry.fileNameKey: 'skills/contributing',
              },
            ],
          },
        }),
      );

      final configFile = File('${tempDir.path}/dart_skills_lint.yaml');
      await configFile.writeAsString('''
dart_skills_lint:
  directories:
    - path: "skills"
      ignore_file: "$defaultIgnoreFileName"
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-d',
        'skills',
      ], workingDirectory: tempDir.path);

      await process.shouldExit(0);

      final List<String> stdout = await process.stdout.rest.toList();
      final String stdoutStr = stdout.join('\n');
      expect(stdoutStr, contains('--- Validating skill: valid-skill ---'));
      expect(stdoutStr, contains('--- Validating skill: contributing ---'));
    });

    test('CLI reports trailing whitespace as error when enabled via config', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'test-skill')}Line with 1 space \n');

      final configFile = File('${tempDir.path}/dart_skills_lint.yaml');
      await configFile.writeAsString('''
dart_skills_lint:
  directories:
    - path: "test-skill"
      rules:
        check-trailing-whitespace: error
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
      ], workingDirectory: tempDir.path);

      final List<String> stderr = await process.stderr.rest.toList();
      final String stderrStr = stderr.join('\n');
      expect(stderrStr, contains('has 1 trailing space(s)'));
      await process.shouldExit(1);
    });

    test('--fix dry-runs and shows diff but does not modify file', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'test-skill')}Line with 1 space \n');

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
        '--fix',
        '--check-trailing-whitespace',
      ]);

      final List<String> stdout = await process.stdout.rest.toList();
      final String stdoutStr = stdout.join('\n');
      expect(stdoutStr, contains('[Dry Run] Proposed changes for test-skill (SKILL.md):'));

      await process.shouldExit(1);

      // Verify file was not modified
      final String content = await File('${skillDir.path}/SKILL.md').readAsString();
      expect(content, contains('Line with 1 space \n'));
    });

    test('--fix-apply modifies file', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'test-skill')}Line with 1 space \n');

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
        '--fix-apply',
        '--check-trailing-whitespace',
      ]);

      final List<String> stdout = await process.stdout.rest.toList();
      expect(stdout.join('\n'), contains('Applied fixes for test-skill'));

      await process.shouldExit(0);

      // Verify file was modified
      final String content = await File('${skillDir.path}/SKILL.md').readAsString();
      expect(content, isNot(contains('Line with 1 space \n')));
      expect(content, contains('Line with 1 space\n'));
    });

    test('--fix-apply does not modify file if lint is ignored', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File(
        '${skillDir.path}/SKILL.md',
      ).writeAsString('${buildFrontmatter(name: 'test-skill')}Line with 1 space \n');

      final ignoreFile = File('${tempDir.path}/$defaultIgnoreFileName');
      await ignoreFile.writeAsString(
        jsonEncode({
          SkillsIgnores.skillsKey: {
            'test-skill': [
              {
                IgnoreEntry.ruleIdKey: 'check-trailing-whitespace',
                IgnoreEntry.fileNameKey: 'SKILL.md',
              },
            ],
          },
        }),
      );

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
        '--fix-apply',
        '--check-trailing-whitespace',
      ]);

      await process.shouldExit(0);

      final String content = await File('${skillDir.path}/SKILL.md').readAsString();
      expect(content, contains('Line with 1 space \n'));
    });

    test('--fix-apply does not modify file if invalid-skill-name is ignored', () async {
      final Directory skillDir = await Directory('${tempDir.path}/my_skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: wrong-name
description: A test skill
---
Body''');

      final ignoreFile = File('${tempDir.path}/$defaultIgnoreFileName');
      await ignoreFile.writeAsString(
        jsonEncode({
          SkillsIgnores.skillsKey: {
            'my_skill': [
              {IgnoreEntry.ruleIdKey: 'invalid-skill-name', IgnoreEntry.fileNameKey: 'SKILL.md'},
            ],
          },
        }),
      );

      final TestProcess process = await TestProcess.start('dart', [
        'bin/cli.dart',
        '-s',
        skillDir.path,
        '--fix-apply',
      ]);

      await process.shouldExit(0);

      final String content = await File('${skillDir.path}/SKILL.md').readAsString();
      expect(content, contains('name: wrong-name'));
    });
  });
}
