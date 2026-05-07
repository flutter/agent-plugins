// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:dart_hooks/src/dart_analyze_hook.dart';
import 'package:test/test.dart';

void main() {
  group('DartAnalyzeHook Unit Tests', () {
    test('Parse --source flag correctly', () async {
      String? loggedMessage;

      final hook = DartAnalyzeHook(
        runProcess: (cmd, args, {bool runInShell = false, String? workingDirectory}) async {
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        },
        fileExists: (path) => true,
        logToFile: (msg) async => loggedMessage = "${loggedMessage ?? ''}$msg\n",
        onExit: (code) {},
      );

      await hook.run(['--source', 'hook'], '/current/path', '/package/root');

      expect(loggedMessage, contains('(Trigger: HOOK)'));
    });

    test('JSON decision output on success', () async {
      String? stdoutMessage;
      int? exitCode;

      final hook = DartAnalyzeHook(
        runProcess: (cmd, args, {bool runInShell = false, String? workingDirectory}) async {
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  lib/file.dart\x00', '');
          }
          if (cmd == 'dart' && args.first == 'analyze') {
            return ProcessResult(0, 0, 'No issues found.', '');
          }
          return ProcessResult(0, 0, '', '');
        },
        fileExists: (path) => true,
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run([], '/current/path', '/package/root');

      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
      expect(exitCode, equals(0));
    });

    test('JSON decision output on failure', () async {
      String? stdoutMessage;
      int? exitCode;

      final hook = DartAnalyzeHook(
        runProcess: (cmd, args, {bool runInShell = false, String? workingDirectory}) async {
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  lib/file.dart\x00', '');
          }
          if (cmd == 'dart' && args.first == 'analyze') {
            return ProcessResult(0, 1, 'Issue found.', '');
          }
          return ProcessResult(0, 0, '', '');
        },
        fileExists: (path) => true,
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run([], '/current/path', '/package/root');

      expect(stdoutMessage, contains('"decision":"continue"'));
      expect(exitCode, equals(0));
    });

    test('Handles filenames with spaces', () async {
      int? exitCode;
      List<String>? dartAnalyzeArgs;

      final hook = DartAnalyzeHook(
        runProcess: (cmd, args, {bool runInShell = false, String? workingDirectory}) async {
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  lib/my file.dart\x00M  lib/other.dart\x00', '');
          }
          if (cmd == 'dart' && args.first == 'analyze') {
            dartAnalyzeArgs = args;
            return ProcessResult(0, 0, 'No issues found.', '');
          }
          return ProcessResult(0, 0, '', '');
        },
        fileExists: (path) => true,
        printStdout: (msg) {},
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run([], '/current/path', '/package/root');

      expect(dartAnalyzeArgs, contains('/package/root/lib/my file.dart'));
      expect(dartAnalyzeArgs, contains('/package/root/lib/other.dart'));
      expect(exitCode, equals(0));
    });

    test('Exits 1 on unhandled exception', () async {
      int? exitCode;

      final hook = DartAnalyzeHook(
        runProcess: (cmd, args, {bool runInShell = false, String? workingDirectory}) async {
          throw Exception('Simulated crash');
        },
        fileExists: (path) => true,
        printStdout: (msg) {},
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run([], '/current/path', '/package/root');

      expect(exitCode, equals(1));
    });
  });
}
