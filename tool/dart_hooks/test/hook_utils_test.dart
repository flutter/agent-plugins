// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_hooks/src/hook_utils.dart';

import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  group('hook_utils Tests', () {
    test('getModifiedFilesInternal finds files outside working directory', () async {
      const packageRoot = '/repo/tool/dart_hooks';
      const repoRoot = '/repo';

      final List<String> files = await getModifiedFilesInternal(
        runProcess: (cmd, args, {bool runInShell = false, String? workingDirectory}) async {
          if (cmd == 'git' && args.first == 'status') {
            final allFiles = [
              'tool/dart_hooks/lib/src/hook_utils.dart',
              'lib/main.dart', // Outside tool/dart_hooks
            ];

            // Simulate Git behavior when '.' is passed:
            // Only return files within the working directory.
            if (args.contains('.')) {
              // In this mock, workingDirectory is '/repo/tool/dart_hooks'.
              // Repo root is '/repo'.
              // So files within working directory must start with 'tool/dart_hooks/'.
              final List<String> filtered = allFiles
                  .where((f) => f.startsWith('tool/dart_hooks/'))
                  .toList();
              return ProcessResult(0, 0, filtered.map((f) => 'M  $f\x00').join(), '');
            }

            // If no '.' is passed, return all modified files in repo.
            return ProcessResult(0, 0, allFiles.map((f) => 'M  $f\x00').join(), '');
          }
          return ProcessResult(0, 0, '', '');
        },
        packageRoot: packageRoot,
        repoRoot: repoRoot,
        fileExists: (path) => true,
        allowedExtensions: ['.dart'],
      );

      // We expect to find both files, even the one outside tool/dart_hooks.
      expect(files, contains('/repo/tool/dart_hooks/lib/src/hook_utils.dart'));
      expect(files, contains('/repo/lib/main.dart'));
    });

    test('getModifiedFilesInternal handles renames correctly', () async {
      const packageRoot = '/repo/tool/dart_hooks';
      const repoRoot = '/repo';

      final List<String> files = await getModifiedFilesInternal(
        runProcess: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'R  lib/old.dart\x00lib/new.dart\x00', '');
          }
          return ProcessResult(0, 0, '', '');
        }).run,
        packageRoot: packageRoot,
        repoRoot: repoRoot,
        fileExists: (path) => true,
        allowedExtensions: ['.dart'],
      );

      expect(files, contains('/repo/lib/new.dart'));
      expect(files, isNot(contains('/repo/lib/old.dart')));
    });

    test('getModifiedFilesInternal handles spaces in filenames', () async {
      const packageRoot = '/repo/tool/dart_hooks';
      const repoRoot = '/repo';

      final List<String> files = await getModifiedFilesInternal(
        runProcess: MockProcessRunner((
          String cmd,
          List<String> args, {
          bool runInShell = false,
          String? workingDirectory,
        }) async {
          if (cmd == 'git' && args.first == 'status') {
            return ProcessResult(0, 0, 'M  lib/my file.dart\x00', '');
          }
          return ProcessResult(0, 0, '', '');
        }).run,
        packageRoot: packageRoot,
        repoRoot: repoRoot,
        fileExists: (path) => true,
        allowedExtensions: ['.dart'],
      );

      expect(files, contains('/repo/lib/my file.dart'));
    });
  });
}
