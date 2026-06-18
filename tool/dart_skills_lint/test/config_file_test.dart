// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/entry_point.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

void main() {
  group('Configuration File Integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('config_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('obeys disabled relative paths in config', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
[broken](missing.md)''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  rules:
    check-relative-paths: disabled
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
      ], workingDirectory: tempDir.path);

      final List<String> stdout = await process.stdout.rest.toList();
      expect(stdout.join('\n'), contains('Skill is valid.'));
      await process.shouldExit(0);
    });

    test('obeys warning absolute paths in config', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
[absolute](/absolute/path.md)''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  rules:
    check-absolute-paths: warning
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
      ], workingDirectory: tempDir.path);

      final List<String> stdout = await process.stdout.rest.toList();
      expect(stdout.join('\n'), contains('Warnings:'));
      await process.shouldExit(0);
    });

    test('obeys path-specific rules with tilde in config', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
Line with 1 space 
'''); // Trailing space

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  directories:
    - path: "~/test-skill"
      rules:
        check-trailing-whitespace: error
''');

      final TestProcess process = await TestProcess.start(
        'dart',
        [p.normalize(p.absolute('bin/cli.dart')), '-s', '~/test-skill'],
        environment: {'HOME': tempDir.path},
        workingDirectory: tempDir.path,
      );

      final List<String> stderr = await process.stderr.rest.toList();
      expect(stderr.join('\n'), contains('has 1 trailing space(s)'));
      await process.shouldExit(1);
    });

    test('CLI flags override path-specific config', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
Line with 1 space 
'''); // Trailing space

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
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
        '--no-check-trailing-whitespace',
      ], workingDirectory: tempDir.path);

      await process.shouldExit(0);
    });

    test('obeys individual_skills block in config', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
Line with 1 space 
'''); // Trailing space

      // Create a second skill not listed in the config to act as a negative test.
      // This ensures the rule is applied strictly to `test-skill` and hasn't accidentally bled globally.
      final Directory otherSkillDir = await Directory('${tempDir.path}/other-skill').create();
      await File('${otherSkillDir.path}/SKILL.md').writeAsString('''
---
name: other-skill
description: Another test skill
---
Line with 1 space 
'''); // Trailing space

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  individual_skills:
    - path: "test-skill"
      rules:
        check-trailing-whitespace: error
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
        '-s',
        'other-skill',
      ], workingDirectory: tempDir.path);

      final List<String> stderr = await process.stderr.rest.toList();
      final String output = stderr.join('\n');
      expect(output, contains('has 1 trailing space(s)'));
      expect(output, isNot(contains('other-skill')));
      await process.shouldExit(1);
    });

    test('succeeds on non-overlapping individual_skills and directories paths', () async {
      await Directory('${tempDir.path}/dir1').create();
      await File('${tempDir.path}/dir1/SKILL.md').writeAsString('''
---
name: dir1
description: A test skill
---
Body''');

      await Directory('${tempDir.path}/dir2').create();
      await File('${tempDir.path}/dir2/SKILL.md').writeAsString('''
---
name: dir2
description: A test skill
---
Body''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  directories:
    - path: "dir1"
  individual_skills:
    - path: "dir2"
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
      ], workingDirectory: tempDir.path);

      await process.shouldExit(0);
    });

    test('CLI flags override config', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
[broken](missing.md)''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  rules:
    check-relative-paths: disabled
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
        '--check-relative-paths',
      ], workingDirectory: tempDir.path);

      final List<String> stderr = await process.stderr.rest.toList();
      expect(stderr.join('\n'), contains('Skill is invalid:'));
      await process.shouldExit(1);
    });

    test('writes empty ignore-file if missing and specified in config', () async {
      await Directory('${tempDir.path}/test-skill').create();
      await File('${tempDir.path}/test-skill/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
Body''');

      const ignorePath = 'custom_ignore.json';
      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  directories:
    - path: "test-skill"
      ignore_file: "$ignorePath"
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
      ], workingDirectory: tempDir.path);

      final List<String> stdout = await process.stdout.rest.toList();
      expect(stdout.join('\n'), contains('File not found generating-baseline'));
      await process.shouldExit(0);

      final writtenFile = File('${tempDir.path}/$ignorePath');
      expect(writtenFile.existsSync(), isTrue);
      final String fileContent = await writtenFile.readAsString();
      expect(fileContent, contains('"skills":'));
    });

    test('ignores config when --ignore-config is passed', () async {
      final Directory skillDir = await Directory('${tempDir.path}/TEST-SKILL').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: TEST-SKILL
description: A test skill
license: MIT
---
Body''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  rules:
    invalid-skill-name: disabled
''');

      // 1. Run without --ignore-config. Should pass because config disables the check.
      final TestProcess passProcess = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'TEST-SKILL',
      ], workingDirectory: tempDir.path);
      await passProcess.shouldExit(0);

      // 2. Run with --ignore-config. Should fail because config is ignored and default is used.
      final TestProcess failProcess = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'TEST-SKILL',
        '--ignore-config',
      ], workingDirectory: tempDir.path);
      await failProcess.shouldExit(1);
    });

    test('ignores config when generating baseline with --ignore-config', () async {
      final Directory skillDir = await Directory('${tempDir.path}/TEST-SKILL').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: TEST-SKILL
description: A test skill
license: MIT
---
Body''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  rules:
    invalid-skill-name: disabled
''');

      // 1. Generate baseline with --ignore-config. It should ignore config (so the rule is enabled) and find violations to generate baseline for!
      final TestProcess genProcess = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'TEST-SKILL',
        '--generate-baseline',
        '--ignore-config',
      ], workingDirectory: tempDir.path);
      await genProcess.shouldExit(0); // Exits 0 if --generate-baseline passed

      final ignoreFile = File('${skillDir.path}/$defaultIgnoreFileName');
      expect(ignoreFile.existsSync(), isTrue);

      final String content = await ignoreFile.readAsString();
      expect(content, contains('invalid-skill-name')); // It should generate baseline for it!
    });

    test('fails on invalid top-level key in config by default', () async {
      await Directory('${tempDir.path}/test-skill').create();
      await File('${tempDir.path}/test-skill/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
Body''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  invalid-key: value
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
      ], workingDirectory: tempDir.path);

      final List<String> stderr = await process.stderr.rest.toList();
      expect(
        stderr.join('\n'),
        contains('Configuration error: Unrecognized top-level key "invalid-key"'),
      );
      await process.shouldExit(1);
    });

    test('bad path: type emits parsing error and lets later entries through', () async {
      // First entry has path: 123 (not a string). Second entry is well-formed.
      // The bad-type entry should produce a parsingErrors line but must not
      // prevent the second entry from being parsed.
      await Directory('${tempDir.path}/good-skill').create();
      await File('${tempDir.path}/good-skill/SKILL.md').writeAsString('''
---
name: good-skill
description: A valid skill
---
Body''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  directories:
    - path: 123
    - path: "good-skill"
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
      ], workingDirectory: tempDir.path);

      final List<String> stderr = await process.stderr.rest.toList();
      final String stderrStr = stderr.join('\n');
      expect(stderrStr, contains('Configuration error: Directory entry "path" must be a string'));
      // Without the fix, the unchecked cast would throw inside the
      // top-level try/catch and 'good-skill' would never run.
      await process.shouldExit(1); // exits 1 due to parsing error
    });

    test('fails on invalid directory key in config by default', () async {
      await Directory('${tempDir.path}/test-skill').create();
      await File('${tempDir.path}/test-skill/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
Body''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  directories:
    - path: "test-skill"
      invalid-dir-key: value
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
      ], workingDirectory: tempDir.path);

      final List<String> stderr = await process.stderr.rest.toList();
      expect(
        stderr.join('\n'),
        contains('Configuration error: Unrecognized key "invalid-dir-key"'),
      );
      await process.shouldExit(1);
    });

    test('succeeds with warning on invalid key when --allow-misconfigured-keys passed', () async {
      await Directory('${tempDir.path}/test-skill').create();
      await File('${tempDir.path}/test-skill/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
Body''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  invalid-key: value
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
        '--allow-misconfigured-keys',
      ], workingDirectory: tempDir.path);

      final List<String> stdout = await process.stdout.rest.toList();
      expect(
        stdout.join('\n'),
        contains('Configuration warning: Unrecognized top-level key "invalid-key"'),
      );
      await process.shouldExit(0);
    });

    test('obeys custom configuration file path via --config', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
[broken](missing.md)''');

      await File('${tempDir.path}/custom_config.yaml').writeAsString('''
dart_skills_lint:
  rules:
    check-relative-paths: disabled
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
        '--config',
        'custom_config.yaml',
      ], workingDirectory: tempDir.path);

      final List<String> stdout = await process.stdout.rest.toList();
      expect(stdout.join('\n'), contains('Skill is valid.'));
      await process.shouldExit(0);
    });

    test('exits with 1 and prints error message if --config points to non-existent file', () async {
      await Directory('${tempDir.path}/test-skill').create();
      await File('${tempDir.path}/test-skill/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
Body''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
        '--config',
        'non_existent_config.yaml',
      ], workingDirectory: tempDir.path);

      final List<String> stderr = await process.stderr.rest.toList();
      expect(stderr.join('\n'), contains('Configuration file not found'));
      expect(stderr.join('\n'), contains('non_existent_config.yaml'));
      await process.shouldExit(1);
    });

    test('ignores config when both --config and --ignore-config are passed', () async {
      final Directory skillDir = await Directory('${tempDir.path}/TEST-SKILL').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('''
---
name: TEST-SKILL
description: A test skill
license: MIT
---
Body''');

      await File('${tempDir.path}/custom_config.yaml').writeAsString('''
dart_skills_lint:
  rules:
    invalid-skill-name: disabled
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'TEST-SKILL',
        '--config',
        'custom_config.yaml',
        '--ignore-config',
      ], workingDirectory: tempDir.path);

      await process.shouldExit(1);
    });

    test('fails on invalid individual_skills key in config by default', () async {
      await Directory('${tempDir.path}/test-skill').create();
      await File('${tempDir.path}/test-skill/SKILL.md').writeAsString('''
---
name: test-skill
description: A test skill
---
Body''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  individual_skills:
    - path: "test-skill"
      invalid-ind-key: value
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'test-skill',
      ], workingDirectory: tempDir.path);

      final List<String> stderr = await process.stderr.rest.toList();
      expect(
        stderr.join('\n'),
        contains(
          'Configuration error: Unrecognized key "invalid-ind-key" in individual skill entry for "test-skill".',
        ),
      );
      await process.shouldExit(1);
    });

    test(
      'processes both configured directories and individual skills when no arguments are passed',
      () async {
        // 1. Create a directory target with a nested skill
        await Directory('${tempDir.path}/dir-target/dir-skill').create(recursive: true);
        await File('${tempDir.path}/dir-target/dir-skill/SKILL.md').writeAsString('''
---
name: dir-skill
description: A directory skill
---
Body''');

        // 2. Create an individual skill target
        await Directory('${tempDir.path}/ind-skill').create();
        await File('${tempDir.path}/ind-skill/SKILL.md').writeAsString('''
---
name: ind-skill
description: An individual skill
---
Body''');

        await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  directories:
    - path: "dir-target"
  individual_skills:
    - path: "ind-skill"
''');

        // Run with NO arguments (no -s or -d)
        final TestProcess process = await TestProcess.start('dart', [
          p.normalize(p.absolute('bin/cli.dart')),
        ], workingDirectory: tempDir.path);

        final List<String> stdout = await process.stdout.rest.toList();
        final String output = stdout.join('\n');

        // Should validate both exactly once
        expect('Validating skill: dir-skill'.allMatches(output).length, 1);
        expect('Validating skill: ind-skill'.allMatches(output).length, 1);
        await process.shouldExit(0);
      },
    );

    test('CLI targets override configured individual_skills', () async {
      final Directory cliSkillDir = await Directory('${tempDir.path}/cli-skill').create();
      await File('${cliSkillDir.path}/SKILL.md').writeAsString('''
---
name: cli-skill
description: A test skill passed via CLI
---
Body''');

      final Directory configSkillDir = await Directory('${tempDir.path}/config-skill').create();
      await File('${configSkillDir.path}/SKILL.md').writeAsString('''
---
name: config-skill
description: A test skill in config
---
Body''');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  individual_skills:
    - path: "config-skill"
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-s',
        'cli-skill',
      ], workingDirectory: tempDir.path);

      final List<String> stdout = await process.stdout.rest.toList();
      final String output = stdout.join('\n');

      // The CLI target should be validated
      expect(output, contains('Validating skill: cli-skill'));
      // The config target should NOT be validated because the CLI target overrides it
      expect(output, isNot(contains('Validating skill: config-skill')));

      await process.shouldExit(0);
    });

    test('later config entries override earlier ones for overlapping paths', () async {
      await Directory('${tempDir.path}/dir1').create();
      await Directory('${tempDir.path}/dir1/test-skill').create();
      // Add trailing whitespace to trigger a lint rule
      await File(
        '${tempDir.path}/dir1/test-skill/SKILL.md',
      ).writeAsString('---\nname: test-skill\ndescription: A test skill\n---\nBody \n');

      await File('${tempDir.path}/dart_skills_lint.yaml').writeAsString('''
dart_skills_lint:
  directories:
    - path: "dir1"
      rules:
        check-trailing-whitespace: error
  individual_skills:
    - path: "dir1/test-skill"
      rules:
        check-trailing-whitespace: warning
''');

      final TestProcess process = await TestProcess.start('dart', [
        p.normalize(p.absolute('bin/cli.dart')),
        '-d',
        'dir1',
      ], workingDirectory: tempDir.path);

      final List<String> stdout = await process.stdout.rest.toList();
      final String output = stdout.join('\n');

      // Should show a warning, not an error. Exit code 0 for warnings.
      expect(output, contains('Warnings:'));
      expect(output, contains('Line 5 has 1 trailing space(s)'));
      await process.shouldExit(0);
    });
  });
}
