// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:dart_hooks/src/dart_analyze_hook.dart';

import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  group('DartAnalyzeHook Unit Tests', () {
    test('Parse --source flag correctly', () async {
      String? loggedMessage;

      final hook = DartAnalyzeHook(
        configKey: 'agent_dart_analyze.dart',
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockAnalyzeConfig(true),
        logToFile: (msg) async => loggedMessage = "${loggedMessage ?? ''}$msg\n",
        onExit: (code) {},
      );

      await hook.run(
        args: ['--source', 'hook'],
        currentPath: '/current/path',
        packageRoot: '/package/root',
        triggerSource: 'HOOK',
      );

      expect(loggedMessage, contains('(Trigger: HOOK)'));
    });

    test('JSON decision output on success', () async {
      String? stdoutMessage;
      int? exitCode;

      final hook = DartAnalyzeHook(
        configKey: 'agent_dart_analyze.dart',
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.contains('--show-toplevel')) {
            return ProcessResult(0, 0, '/package/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  lib/file.dart\x00', '');
          }
          if (cmd == 'dart' && args.first == 'analyze') {
            return ProcessResult(0, 0, 'No issues found.', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockAnalyzeConfig(true),
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/current/path',
        packageRoot: '/package/root',
        triggerSource: 'MANUAL',
      );

      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
      expect(exitCode, equals(0));
    });

    test('JSON decision output on failure', () async {
      String? stdoutMessage;
      int? exitCode;

      final hook = DartAnalyzeHook(
        configKey: 'agent_dart_analyze.dart',
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.contains('--show-toplevel')) {
            return ProcessResult(0, 0, '/package/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  lib/file.dart\x00', '');
          }
          if (cmd == 'dart' && args.first == 'analyze') {
            return ProcessResult(0, 1, 'Issue found.', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockAnalyzeConfig(true),
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/current/path',
        packageRoot: '/package/root',
        triggerSource: 'MANUAL',
      );

      expect(stdoutMessage, contains('"decision":"continue"'));
      expect(exitCode, equals(0));
    });

    test('Handles filenames with spaces', () async {
      int? exitCode;
      List<String>? dartAnalyzeArgs;

      final hook = DartAnalyzeHook(
        configKey: 'agent_dart_analyze.dart',
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.contains('--show-toplevel')) {
            return ProcessResult(0, 0, '/package/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  lib/my file.dart\x00M  lib/other.dart\x00', '');
          }
          if (cmd == 'dart' && args.first == 'analyze') {
            dartAnalyzeArgs = args;
            return ProcessResult(0, 0, 'No issues found.', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockAnalyzeConfig(true),
        printStdout: (msg) {},
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/current/path',
        packageRoot: '/package/root',
        triggerSource: 'MANUAL',
      );

      expect(dartAnalyzeArgs, contains('/package/root/lib/my file.dart'));
      expect(dartAnalyzeArgs, contains('/package/root/lib/other.dart'));
      expect(exitCode, equals(0));
    });

    test('Exits 1 on unhandled exception', () async {
      int? exitCode;

      final hook = DartAnalyzeHook(
        configKey: 'agent_dart_analyze.dart',
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          throw Exception('Simulated crash');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockAnalyzeConfig(true),
        printStdout: (msg) {},
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/current/path',
        packageRoot: '/package/root',
        triggerSource: 'MANUAL',
      );

      expect(exitCode, equals(1));
    });
  });
}
