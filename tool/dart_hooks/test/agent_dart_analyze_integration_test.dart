// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:dart_hooks/src/dart_analyze_hook.dart';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  group('DartAnalyzeHook Integration Tests', () {
    late Directory tempDir;
    late String repoRoot;
    late String packageRoot;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dart_analyze_test_');
      repoRoot = tempDir.path;
      packageRoot = path.join(repoRoot, 'packages', 'camera_package');

      await Directory(packageRoot).create(recursive: true);

      // Create dummy pubspec.yaml to give analyzer context
      await File(path.join(packageRoot, 'pubspec.yaml')).writeAsString('''
name: test_package
environment:
  sdk: '>=3.0.0 <4.0.0'
''');

      // Create dummy dart_hooks.yaml to enable the analyze hook
      await File(path.join(packageRoot, 'dart_hooks.yaml')).writeAsString(mockAnalyzeConfig(true));

      // Initialize a git repo in the temp directory
      final ProcessResult initResult = await Process.run(
        'git',
        ['init'],
        workingDirectory: repoRoot,
        runInShell: true,
      );
      if (initResult.exitCode != 0) {
        throw Exception('git init failed: ${initResult.stderr}');
      }

      // Git requires user name and email
      await Process.run(
        'git',
        ['config', 'user.email', 'test@example.com'],
        workingDirectory: repoRoot,
        runInShell: true,
      );
      await Process.run(
        'git',
        ['config', 'user.name', 'Test User'],
        workingDirectory: repoRoot,
        runInShell: true,
      );

      // Create an initial commit to make the repo fully operational
      await File(path.join(repoRoot, 'README.md')).writeAsString('Initial file');
      await Process.run('git', ['add', '.'], workingDirectory: repoRoot, runInShell: true);
      await Process.run(
        'git',
        ['commit', '-m', 'Initial commit'],
        workingDirectory: repoRoot,
        runInShell: true,
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('Finds and analyzes file in package', () async {
      final fileToAnalyze = File(path.join(packageRoot, 'lib', 'test.dart'));
      await fileToAnalyze.create(recursive: true);
      await fileToAnalyze.writeAsString('void main() {}'); // Valid file

      // Stage the file
      await Process.run('git', ['add', '.'], workingDirectory: repoRoot, runInShell: true);

      String? stdoutMessage;
      int? exitCode;
      final List<String> logs = [];

      final hook = DartAnalyzeHook(
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) {
          return Process.run(
            cmd,
            args,
            runInShell: runInShell,
            workingDirectory: workingDirectory ?? packageRoot,
          );
        }),
        fileExists: (p) => File(p).existsSync(),
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async => logs.add(msg),
        onExit: (code) => exitCode = code,
      );

      // Run the hook from a simulated .agents directory inside packageRoot
      final String agentsDir = path.join(packageRoot, '.agents');

      await hook.run(
        args: [],
        currentPath: agentsDir,
        packageRoot: packageRoot,
        triggerSource: 'MANUAL',
      );

      // Verify JSON output
      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'}))); // Success decision
      expect(exitCode, equals(0));

      // Verify files were actually found and analyzed
      expect(logs.any((l) => l.contains('Running command on')), isTrue);
    });

    test('Only analyzes modified files', () async {
      final modifiedFile = File(path.join(packageRoot, 'lib', 'modified.dart'));
      await modifiedFile.create(recursive: true);
      await modifiedFile.writeAsString('void main() {}');

      final untouchedFile = File(path.join(packageRoot, 'lib', 'untouched.dart'));
      await untouchedFile.create(recursive: true);
      await untouchedFile.writeAsString('void main() {}');

      // Commit both files to make them "untouched"
      await Process.run('git', ['add', '.'], workingDirectory: repoRoot, runInShell: true);
      await Process.run(
        'git',
        ['commit', '-m', 'Add initial files'],
        workingDirectory: repoRoot,
        runInShell: true,
      );

      // Now modify only one file
      await modifiedFile.writeAsString('void main() { print("modified"); }');

      int? exitCode;
      List<String>? dartAnalyzeArgs;

      final hook = DartAnalyzeHook(
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'dart' && args.first == 'analyze') {
            dartAnalyzeArgs = args;
            return ProcessResult(0, 0, 'No issues found.', '');
          }
          // For git commands, run them for real
          return Process.run(
            cmd,
            args,
            runInShell: runInShell,
            workingDirectory: workingDirectory ?? packageRoot,
          );
        }),
        fileExists: (p) => File(p).existsSync(),
        printStdout: (msg) {},
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      final String agentsDir = path.join(packageRoot, '.agents');
      await hook.run(
        args: [],
        currentPath: agentsDir,
        packageRoot: packageRoot,
        triggerSource: 'MANUAL',
      );

      expect(dartAnalyzeArgs, isNotNull);
      expect(
        dartAnalyzeArgs!.any((arg) => arg.endsWith(path.join('lib', 'modified.dart'))),
        isTrue,
      );
      expect(
        dartAnalyzeArgs!.any((arg) => arg.endsWith(path.join('lib', 'untouched.dart'))),
        isFalse,
      );
      expect(exitCode, equals(0));
    });
  });
}
