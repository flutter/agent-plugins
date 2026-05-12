// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:dart_hooks/src/skill_lint_hook.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('SkillLintHook Unit Tests', () {
    test('runs dart_skills_lint with -s for each modified SKILL.md', () async {
      List<String>? dartArgs;
      int? exitCode;

      final hook = SkillLintHook(
        processRunner: MockProcessRunner((cmd, args, {runInShell = false, workingDirectory}) async {
          if (cmd == 'git' && args.contains('--show-toplevel')) {
            return ProcessResult(0, 0, '/repo/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  skills/foo/SKILL.md\x00M  skills/bar/SKILL.md\x00', '');
          }
          if (cmd == 'dart' && args.first == 'run') {
            dartArgs = args;
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        printStdout: (msg) {},
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/repo/root',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(exitCode, equals(0));
      expect(dartArgs, isNotNull);
      expect(dartArgs!.first, equals('run'));
      expect(dartArgs, contains('--directory=/repo/root/tool/dart_skills_lint'));
      expect(dartArgs, contains('bin/cli.dart'));
      // Each skill dir is preceded by -s.
      expect(dartArgs, containsAllInOrder(<String>['-s', '/repo/root/skills/bar']));
      expect(dartArgs, containsAllInOrder(<String>['-s', '/repo/root/skills/foo']));
    });

    test('ignores .md files that are not SKILL.md', () async {
      List<String>? dartArgs;
      String? stdoutMessage;
      int? exitCode;

      final hook = SkillLintHook(
        processRunner: MockProcessRunner((cmd, args, {runInShell = false, workingDirectory}) async {
          if (cmd == 'git' && args.contains('--show-toplevel')) {
            return ProcessResult(0, 0, '/repo/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(
              0,
              0,
              'M  skills/foo/README.md\x00M  skills/foo/skill.md\x00M  docs/CONTRIBUTING.md\x00',
              '',
            );
          }
          if (cmd == 'dart' && args.first == 'run') {
            dartArgs = args;
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/repo/root',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(dartArgs, isNull, reason: 'dart_skills_lint must not run when no SKILL.md changed');
      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
      expect(exitCode, equals(0));
    });

    test('deduplicates skill directory when nested files also match', () async {
      List<String>? dartArgs;

      final hook = SkillLintHook(
        processRunner: MockProcessRunner((cmd, args, {runInShell = false, workingDirectory}) async {
          if (cmd == 'git' && args.contains('--show-toplevel')) {
            return ProcessResult(0, 0, '/repo/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            // Two SKILL.md modifications in different skill dirs, both should
            // appear once (no accidental duplication from path normalization).
            return ProcessResult(0, 0, 'M  skills/foo/SKILL.md\x00M  skills/foo/SKILL.md\x00', '');
          }
          if (cmd == 'dart' && args.first == 'run') {
            dartArgs = args;
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        printStdout: (msg) {},
        logToFile: (msg) async {},
        onExit: (code) {},
      );

      await hook.run(
        args: [],
        currentPath: '/repo/root',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(dartArgs, isNotNull);
      // Count -s occurrences: should be exactly 1.
      final int sFlagCount = dartArgs!.where((a) => a == '-s').length;
      expect(sFlagCount, equals(1));
    });

    test('returns continue decision on lint failure', () async {
      String? stdoutMessage;
      int? exitCode;

      final hook = SkillLintHook(
        processRunner: MockProcessRunner((cmd, args, {runInShell = false, workingDirectory}) async {
          if (cmd == 'git' && args.contains('--show-toplevel')) {
            return ProcessResult(0, 0, '/repo/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  skills/foo/SKILL.md\x00', '');
          }
          if (cmd == 'dart' && args.first == 'run') {
            return ProcessResult(0, 1, 'foo: trailing whitespace on line 3', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/repo/root',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(stdoutMessage, contains('"decision":"continue"'));
      expect(stdoutMessage, contains('trailing whitespace on line 3'));
      // Antigravity captures stdout JSON only when the hook exits 0.
      expect(exitCode, equals(0));
    });

    test('returns stop decision when SKILL.md modifications all pass lint', () async {
      String? stdoutMessage;
      int? exitCode;

      final hook = SkillLintHook(
        processRunner: MockProcessRunner((cmd, args, {runInShell = false, workingDirectory}) async {
          if (cmd == 'git' && args.contains('--show-toplevel')) {
            return ProcessResult(0, 0, '/repo/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  skills/foo/SKILL.md\x00', '');
          }
          if (cmd == 'dart' && args.first == 'run') {
            return ProcessResult(0, 0, 'All skills passed.', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/repo/root',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
      expect(exitCode, equals(0));
    });
  });
}
