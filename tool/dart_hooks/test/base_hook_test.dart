// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:dart_hooks/src/base_hook.dart';
import 'package:path/path.dart' as path;

import 'package:test/test.dart';
import 'test_utils.dart';

class TestHook extends BaseHook {
  TestHook({
    required super.processRunner,
    required super.fileExists,
    required super.printStdout,
    required super.logToFile,
    required super.onExit,
    super.readFile,
    required this.executeCommandMock,
  });

  final Future<ProcessResult> Function(List<String>) executeCommandMock;

  @override
  List<String> get allowedExtensions => ['.dart'];

  @override
  String get hookName => 'test hook';

  @override
  String get configKey => 'test_hook';

  @override
  Future<ProcessResult> executeCommand(List<String> files) => executeCommandMock(files);
}

String _mockConfig(bool enabled) => 'test_hook: $enabled\n';

void main() {
  group('BaseHook Tests', () {
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
        readFile: (path) => _mockConfig(true),
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

      expect(executedFiles, contains(path.normalize('/repo/root/lib/file.dart')));
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
        readFile: (path) => _mockConfig(true),
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
      expect(exitCode, equals(0)); // Exits 0 so Antigravity/Jetski captures stdout JSON
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
        readFile: (path) => _mockConfig(true),
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

    group('Configuration Check Logic', () {
      test('Missing config file defaults to doing no work silently', () async {
        String? stdoutMessage;
        int? exitCode;
        final loggedMessages = <String>[];

        final hook = TestHook(
          processRunner: MockProcessRunner((
            cmd,
            args, {
            runInShell = false,
            workingDirectory,
          }) async {
            return ProcessResult(0, 0, '', '');
          }),
          fileExists: (path) => false, // config file does not exist
          printStdout: (msg) => stdoutMessage = msg,
          logToFile: (msg) async => loggedMessages.add(msg),
          onExit: (code) => exitCode = code,
          executeCommandMock: (files) async => ProcessResult(0, 0, '', ''),
        );

        await hook.run(
          args: [],
          currentPath: '/repo/root',
          packageRoot: '/repo/root',
          triggerSource: 'MANUAL',
        );

        expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
        expect(exitCode, equals(0));
        // Verify absolutely nothing is logged
        expect(loggedMessages, isEmpty);
      });

      test('Missing config key logs key missing warning', () async {
        String? stdoutMessage;
        int? exitCode;
        final loggedMessages = <String>[];

        final hook = TestHook(
          processRunner: MockProcessRunner((
            cmd,
            args, {
            runInShell = false,
            workingDirectory,
          }) async {
            return ProcessResult(0, 0, '', '');
          }),
          fileExists: (path) => true,
          readFile: (path) => 'other_hook: true\n', // missing key: test_hook
          printStdout: (msg) => stdoutMessage = msg,
          logToFile: (msg) async => loggedMessages.add(msg),
          onExit: (code) => exitCode = code,
          executeCommandMock: (files) async => ProcessResult(0, 0, '', ''),
        );

        await hook.run(
          args: [],
          currentPath: '/repo/root',
          packageRoot: '/repo/root',
          triggerSource: 'MANUAL',
        );

        expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
        expect(exitCode, equals(0));
        expect(loggedMessages.length, equals(1));
        // Verify log contains the specific warning message
        expect(
          loggedMessages.first,
          contains('is disabled (key "test_hook" is missing in configuration)'),
        );
      });

      test('Disabled setting logs disabled', () async {
        String? stdoutMessage;
        int? exitCode;
        final loggedMessages = <String>[];

        final hook = TestHook(
          processRunner: MockProcessRunner((
            cmd,
            args, {
            runInShell = false,
            workingDirectory,
          }) async {
            return ProcessResult(0, 0, '', '');
          }),
          fileExists: (path) => true,
          readFile: (path) => _mockConfig(false),
          printStdout: (msg) => stdoutMessage = msg,
          logToFile: (msg) async => loggedMessages.add(msg),
          onExit: (code) => exitCode = code,
          executeCommandMock: (files) async => ProcessResult(0, 0, '', ''),
        );

        await hook.run(
          args: [],
          currentPath: '/repo/root',
          packageRoot: '/repo/root',
          triggerSource: 'MANUAL',
        );

        expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
        expect(exitCode, equals(0));
        expect(loggedMessages.length, equals(1));
        expect(loggedMessages.first, contains('Hook test hook is disabled.'));
      });

      test('Enabled setting logs enabled and continues execution', () async {
        String? stdoutMessage;
        int? exitCode;
        final loggedMessages = <String>[];
        var commandExecuted = false;

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
          readFile: (path) => _mockConfig(true),
          printStdout: (msg) => stdoutMessage = msg,
          logToFile: (msg) async => loggedMessages.add(msg),
          onExit: (code) => exitCode = code,
          executeCommandMock: (files) async {
            commandExecuted = true;
            return ProcessResult(0, 0, 'Success', '');
          },
        );

        await hook.run(
          args: [],
          currentPath: '/repo/root',
          packageRoot: '/repo/root',
          triggerSource: 'MANUAL',
        );

        expect(commandExecuted, isTrue);
        expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
        expect(exitCode, equals(0));
        expect(loggedMessages, contains('Hook test hook is enabled in configuration.'));
      });

      test('Invalid configuration format logs parse failure', () async {
        String? stdoutMessage;
        int? exitCode;
        final loggedMessages = <String>[];

        final hook = TestHook(
          processRunner: MockProcessRunner((
            cmd,
            args, {
            runInShell = false,
            workingDirectory,
          }) async {
            return ProcessResult(0, 0, '', '');
          }),
          fileExists: (path) => true,
          readFile: (path) => 'not-a-map-just-a-string',
          printStdout: (msg) => stdoutMessage = msg,
          logToFile: (msg) async => loggedMessages.add(msg),
          onExit: (code) => exitCode = code,
          executeCommandMock: (files) async => ProcessResult(0, 0, '', ''),
        );

        await hook.run(
          args: [],
          currentPath: '/repo/root',
          packageRoot: '/repo/root',
          triggerSource: 'MANUAL',
        );

        expect(stdoutMessage, equals(jsonEncode({'decision': 'stop'})));
        expect(exitCode, equals(0));
        expect(loggedMessages.length, equals(1));
        expect(loggedMessages.first, contains('is disabled (invalid configuration format)'));
      });
    });
  });
}
