// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:dart_hooks/src/skill_lint_hook.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('SkillLintHook Integration Tests', () {
    late Directory tempDir;
    late String repoRoot;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('skill_lint_test_');
      repoRoot = tempDir.resolveSymbolicLinksSync();
      await setUpGitRepo(tempDir);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('runs lint on modified SKILL.md, ignoring other .md files', () async {
      // Two skills with SKILL.md, plus a sibling README.md that should be
      // ignored.
      final foo = File(path.join(repoRoot, 'skills', 'foo', 'SKILL.md'));
      await foo.create(recursive: true);
      await foo.writeAsString('foo');

      final bar = File(path.join(repoRoot, 'skills', 'bar', 'SKILL.md'));
      await bar.create(recursive: true);
      await bar.writeAsString('bar');

      final readme = File(path.join(repoRoot, 'skills', 'foo', 'README.md'));
      await readme.writeAsString('readme');

      await Process.run('git', ['add', '.'], workingDirectory: repoRoot, runInShell: true);

      List<String>? dartArgs;
      String? stdoutMessage;
      int? exitCode;

      final hook = SkillLintHook(
        processRunner: MockProcessRunner((cmd, args, {runInShell = false, workingDirectory}) async {
          if (cmd == 'dart' && args.first == 'run') {
            dartArgs = args;
            return ProcessResult(0, 0, 'All skills passed.', '');
          }
          return Process.run(
            cmd,
            args,
            runInShell: runInShell,
            workingDirectory: workingDirectory ?? repoRoot,
          );
        }),
        fileExists: (p) => File(p).existsSync(),
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: repoRoot,
        packageRoot: repoRoot,
        triggerSource: 'MANUAL',
      );

      expect(dartArgs, isNotNull, reason: 'dart_skills_lint must run');
      expect(dartArgs, contains('--directory=${path.join(repoRoot, 'tool/dart_skills_lint')}'));
      // -s should appear for foo and bar only (not for README.md's dir).
      final sTargets = <String>[];
      for (var i = 0; i < dartArgs!.length - 1; i++) {
        if (dartArgs![i] == '-s') {
          sTargets.add(dartArgs![i + 1]);
        }
      }
      expect(sTargets, hasLength(2));
      expect(sTargets, contains(path.join(repoRoot, 'skills', 'foo')));
      expect(sTargets, contains(path.join(repoRoot, 'skills', 'bar')));
      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
      expect(exitCode, equals(0));
    });

    test('reports lint errors via continue decision', () async {
      final foo = File(path.join(repoRoot, 'skills', 'foo', 'SKILL.md'));
      await foo.create(recursive: true);
      await foo.writeAsString('trailing whitespace   ');

      await Process.run('git', ['add', '.'], workingDirectory: repoRoot, runInShell: true);

      String? stdoutMessage;
      int? exitCode;

      final hook = SkillLintHook(
        processRunner: MockProcessRunner((cmd, args, {runInShell = false, workingDirectory}) async {
          if (cmd == 'dart' && args.first == 'run') {
            return ProcessResult(0, 1, 'skills/foo: trailing whitespace on line 1', '');
          }
          return Process.run(
            cmd,
            args,
            runInShell: runInShell,
            workingDirectory: workingDirectory ?? repoRoot,
          );
        }),
        fileExists: (p) => File(p).existsSync(),
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: repoRoot,
        packageRoot: repoRoot,
        triggerSource: 'MANUAL',
      );

      expect(stdoutMessage, contains('"decision":"continue"'));
      expect(stdoutMessage, contains('trailing whitespace on line 1'));
      expect(exitCode, equals(0));
    });
  });
}
