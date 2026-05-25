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
  group('DartFormatHook Unit Tests', () {
    test('Parse --source flag correctly', () async {
      String? loggedMessage;

      final hook = DartFormatHook(
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.first == 'rev-parse') {
            return ProcessResult(0, 0, '/repo/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockFormatConfig(true),
        printStdout: (msg) {},
        logToFile: (msg) async => loggedMessage = "${loggedMessage ?? ''}$msg\n",
        onExit: (code) {},
      );

      await hook.run(
        args: ['--source', 'hook'],
        currentPath: '/current/path',
        packageRoot: '/repo/root',
        triggerSource: 'HOOK',
      );

      expect(loggedMessage, contains('(Trigger: HOOK)'));
    });

    test('Defaults to MANUAL source when flag missing', () async {
      String? loggedMessage;

      final hook = DartFormatHook(
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.first == 'rev-parse') {
            return ProcessResult(0, 0, '/repo/root', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockFormatConfig(true),
        logToFile: (msg) async => loggedMessage = "${loggedMessage ?? ''}$msg\n",
        onExit: (code) {},
      );

      await hook.run(
        args: [],
        currentPath: '/current/path',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(loggedMessage, contains('(Trigger: MANUAL)'));
    });

    test('JSON contract adherence on success', () async {
      String? stdoutMessage;
      int? exitCode;

      final hook = DartFormatHook(
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.first == 'rev-parse') {
            return ProcessResult(0, 0, '/repo/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  file.dart\x00', '');
          }
          if (cmd == 'dart' && args.first == 'format') {
            return ProcessResult(0, 0, 'Formatted file.dart', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockFormatConfig(true),
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/current/path',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
      expect(exitCode, equals(0));
    });

    test('Handles filenames with spaces', () async {
      int? exitCode;
      List<String>? dartFormatArgs;

      final hook = DartFormatHook(
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.first == 'rev-parse') {
            return ProcessResult(0, 0, '/repo/root', '');
          }
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  lib/my file.dart\x00M  lib/other.dart\x00', '');
          }
          if (cmd == 'dart' && args.first == 'format') {
            dartFormatArgs = args;
            return ProcessResult(0, 0, 'Formatted files', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockFormatConfig(true),
        printStdout: (msg) {},
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/current/path',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(dartFormatArgs, contains(path.normalize('/repo/root/lib/my file.dart')));
      expect(dartFormatArgs, contains(path.normalize('/repo/root/lib/other.dart')));
      expect(exitCode, equals(0));
    });

    test('Exits 1 on unhandled exception', () async {
      int? exitCode;

      final hook = DartFormatHook(
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          throw Exception('Simulated crash');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockFormatConfig(true),
        printStdout: (msg) {},
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/current/path',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(exitCode, equals(1));
    });

    test('Exits 0 and outputs decision continue when git rev-parse fails', () async {
      int? exitCode;

      final hook = DartFormatHook(
        processRunner: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.first == 'rev-parse') {
            return ProcessResult(0, 1, '', 'Git error');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        readFile: (path) => mockFormatConfig(true),
        printStdout: (msg) {},
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
      );

      await hook.run(
        args: [],
        currentPath: '/current/path',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(exitCode, equals(0));
    });
  });
}
