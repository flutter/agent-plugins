// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:dart_hooks/src/dart_format_hook.dart';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  group('DartFormatHook Integration Tests', () {
    late Directory tempDir;
    late String repoRoot;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dart_format_test_');
      repoRoot = tempDir.path;

      // Initialize a git repo in the temp directory
      await Process.run('git', ['init'], workingDirectory: repoRoot, runInShell: true);

      // Git requires user name and email to be set in some environments
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

      // Create dummy dart_hooks.yaml to enable the format hook
      await File(path.join(repoRoot, 'dart_hooks.yaml')).writeAsString(mockFormatConfig(true));
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('Formats modified file', () async {
      final fileToFormat = File(path.join(repoRoot, 'test.dart'));
      await fileToFormat.writeAsString('void main() {  print("hello");}'); // Poorly formatted

      // Stage the file so git status sees it or leave it untracked?
      // The hook checks `git status --porcelain` which sees both modified and untracked files (if not ignored).

      String? stdoutMessage;
      int? exitCode;

      final hook = DartFormatHook(
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) {
          // Delegate to real Process.run but force workingDirectory to repoRoot
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

      // Stage the file so git status sees it as added
      await Process.run('git', ['add', 'test.dart'], workingDirectory: repoRoot, runInShell: true);

      // Run the hook
      await hook.run(
        args: [],
        currentPath: repoRoot,
        packageRoot: repoRoot,
        triggerSource: 'MANUAL',
      );

      // Verify JSON output
      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
      expect(exitCode, equals(0));

      // Verify file was formatted
      final String content = await fileToFormat.readAsString();
      expect(
        content,
        equals('void main() {\n  print("hello");\n}\n'),
      ); // Assuming standard dart format
    });

    test('Creates log file and appends to it', () async {
      final logFile = File(path.join(repoRoot, 'test.log'));

      Future<void> testLog(String message) async {
        await logFile.writeAsString('$message\n', mode: FileMode.append);
      }

      final hook = DartFormatHook(
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.first == 'rev-parse') {
            return ProcessResult(0, 0, repoRoot, '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (p) => true,
        printStdout: (msg) {},
        logToFile: testLog,
        onExit: (code) {},
      );

      // Run it first time
      await hook.run(
        args: [],
        currentPath: repoRoot,
        packageRoot: repoRoot,
        triggerSource: 'MANUAL',
      );

      expect(logFile.existsSync(), isTrue);
      final String contentFirstRun = await logFile.readAsString();
      expect(contentFirstRun, contains('Hook dart format is enabled in configuration.'));
      expect(contentFirstRun, contains('dart format started in'));
      expect(contentFirstRun, contains('No matching files found to process in scope:'));

      // Run it second time to verify append
      await hook.run(
        args: [],
        currentPath: repoRoot,
        packageRoot: repoRoot,
        triggerSource: 'MANUAL',
      );

      final String contentSecondRun = await logFile.readAsString();
      final int startOccurrences = 'dart format started in'.allMatches(contentSecondRun).length;
      expect(startOccurrences, equals(2));
    });

    test('Only formats modified files', () async {
      final modifiedFile = File(path.join(repoRoot, 'modified.dart'));
      await modifiedFile.writeAsString('void main() {  print("modified");}'); // Poorly formatted

      final untouchedFile = File(path.join(repoRoot, 'untouched.dart'));
      await untouchedFile.writeAsString('void main() {  print("untouched");}'); // Poorly formatted

      // Commit both files to make them "untouched"
      await Process.run('git', ['add', '.'], workingDirectory: repoRoot, runInShell: true);
      await Process.run(
        'git',
        ['commit', '-m', 'Add initial files'],
        workingDirectory: repoRoot,
        runInShell: true,
      );

      // Now modify only one file (keep it poorly formatted or change content)
      await modifiedFile.writeAsString(
        'void main() {  print("modified-edited");}',
      ); // Poorly formatted

      String? stdoutMessage;
      int? exitCode;

      final hook = DartFormatHook(
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
            workingDirectory: workingDirectory ?? repoRoot,
          );
        }),
        fileExists: (p) => File(p).existsSync(),
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      // Run the hook
      await hook.run(
        args: [],
        currentPath: repoRoot,
        packageRoot: repoRoot,
        triggerSource: 'MANUAL',
      );

      // Verify JSON output
      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
      expect(exitCode, equals(0));

      // Verify modified file was formatted
      final String modifiedContent = await modifiedFile.readAsString();
      expect(modifiedContent, equals('void main() {\n  print("modified-edited");\n}\n'));

      // Verify untouched file was NOT formatted
      final String untouchedContent = await untouchedFile.readAsString();
      expect(
        untouchedContent,
        equals('void main() {  print("untouched");}'),
      ); // Still poorly formatted
    });
  });
}
