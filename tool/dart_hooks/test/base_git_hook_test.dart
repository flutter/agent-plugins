// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:dart_hooks/src/base_git_hook.dart';

import 'package:test/test.dart';
import 'test_utils.dart';

class TestHook extends BaseGitHook {
  TestHook({
    required super.processRunner,
    required super.fileExists,
    required super.printStdout,
    required super.logToFile,
    required super.onExit,
    required this.executeCommandMock,
  });

  final Future<ProcessResult> Function(List<String>) executeCommandMock;

  @override
  List<String> get allowedExtensions => ['.dart'];

  @override
  String get hookName => 'test hook';

  @override
  Future<ProcessResult> executeCommand(List<String> files) => executeCommandMock(files);
}

void main() {
  group('BaseGitHook Tests', () {
    test('Template method coordinates steps correctly on success', () async {
      String? stdoutMessage;
      int? exitCode;
      List<String>? executedFiles;

      final hook = TestHook(
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
            return ProcessResult(0, 0, 'M  lib/file.dart\x00', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
        executeCommandMock: (files) async {
          executedFiles = files;
          return ProcessResult(0, 0, 'Success', '');
        },
      );

      await hook.run(
        args: [],
        currentPath: '/repo/root',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(executedFiles, contains('/repo/root/lib/file.dart'));
      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
      expect(exitCode, equals(0));
    });

    test('Template method coordinates steps correctly on failure', () async {
      String? stdoutMessage;
      int? exitCode;

      final hook = TestHook(
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
            return ProcessResult(0, 0, 'M  lib/file.dart\x00', '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
        executeCommandMock: (files) async {
          return ProcessResult(0, 1, '', 'Error occurred');
        },
      );

      await hook.run(
        args: [],
        currentPath: '/repo/root',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(stdoutMessage, contains('"decision":"continue"'));
      expect(stdoutMessage, contains('Error occurred'));
      expect(exitCode, equals(0)); // Exits 0 so Antigravity captures stdout JSON
    });

    test('Chunking behavior works when file list is large', () async {
      String? stdoutMessage;
      int? exitCode;
      final List<List<String>> executedChunks = [];

      final hook = TestHook(
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
            // Generate a large list of files
            final String files = List.generate(150, (i) => 'M  lib/file$i.dart\x00').join();
            return ProcessResult(0, 0, files, '');
          }
          return ProcessResult(0, 0, '', '');
        }),
        fileExists: (path) => true,
        printStdout: (msg) => stdoutMessage = msg,
        logToFile: (msg) async {},
        onExit: (code) => exitCode = code,
        executeCommandMock: (files) async {
          executedChunks.add(files);
          return ProcessResult(0, 0, 'Success', '');
        },
      );

      await hook.run(
        args: [],
        currentPath: '/repo/root',
        packageRoot: '/repo/root',
        triggerSource: 'MANUAL',
      );

      expect(executedChunks.length, equals(2));
      expect(executedChunks.expand((x) => x).length, equals(150));
      expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
      expect(exitCode, equals(0));
    });
  });
}
