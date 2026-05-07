// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'hook_utils.dart';

/// Implements the dart format hook logic.
class DartFormatHook {
  /// Creates a [DartFormatHook].
  DartFormatHook({
    this.runProcess = Process.run,
    this.fileExists = _defaultFileExists,
    this.printStdout = _defaultPrintStdout,
    required this.logToFile,
    this.onExit = exit,
  });

  /// The function used to run processes.
  final Future<ProcessResult> Function(
    String,
    List<String>, {
    bool runInShell,
    String? workingDirectory,
  })
  runProcess;

  /// The function used to check if a file exists.
  final bool Function(String) fileExists;

  /// The function used to print to stdout.
  final void Function(String) printStdout;

  /// The function used to log to a file.
  final Future<void> Function(String) logToFile;

  /// The function used to exit the process.
  final void Function(int) onExit;

  static bool _defaultFileExists(String path) => File(path).existsSync();
  static void _defaultPrintStdout(String message) => stdout.writeln(message);

  /// Runs the format hook.
  Future<void> run(List<String> args, String currentPath) async {
    void emitEmptyResult() {
      printStdout(jsonEncode({}));
    }

    final int sourceIdx = args.indexOf('--source');
    final String triggerSource = (sourceIdx != -1 && sourceIdx + 1 < args.length)
        ? args[sourceIdx + 1].toUpperCase()
        : 'MANUAL';

    await logToFile('dart_format.dart started in $currentPath (Trigger: $triggerSource)');

    try {
      // Get the repo root to resolve paths in monorepo.
      final ProcessResult repoRootResult = await runProcess('git', [
        'rev-parse',
        '--show-toplevel',
      ], runInShell: false);

      if (repoRootResult.exitCode != 0) {
        await logToFile('ERROR: Failed to get git repo root.');
        emitEmptyResult();
        onExit(1);
        return;
      }
      final String repoRoot = (repoRootResult.stdout as String).trim();

      // 1. Check if there are modified .dart files.
      final ProcessResult gitResult = await runProcess('git', [
        'status',
        '--porcelain',
        '-z',
      ], runInShell: false);

      if (gitResult.exitCode != 0) {
        await logToFile('ERROR: git status failed with exit code ${gitResult.exitCode}');
        await logToFile(gitResult.stderr as String);
        emitEmptyResult();
        onExit(1);
        return;
      }

      final List<String> modifiedDartFiles = [];
      final List<String> entries = (gitResult.stdout as String).split('\x00');
      for (var i = 0; i < entries.length; i++) {
        final String entry = entries[i];
        if (entry.length < 4) {
          continue;
        }
        final String status = entry.substring(0, 2);
        String filePath = entry.substring(3);
        if (status.startsWith('R') || status.startsWith('C')) {
          if (i + 1 < entries.length) {
            filePath = entries[++i];
          }
        }
        if (filterGeneratedFiles(filePath)) {
          final String fullPath = path.join(repoRoot, filePath);
          if (fileExists(fullPath)) {
            modifiedDartFiles.add(fullPath);
          }
        }
      }

      if (modifiedDartFiles.isEmpty) {
        await logToFile('No modified dart files, exiting.');
        emitEmptyResult();
        onExit(0);
        return;
      }

      await logToFile('Running dart format on ${modifiedDartFiles.length} files...');

      // 2. Run dart format ONLY on the modified files.
      final ProcessResult result = await runProcess('dart', [
        'format',
        '--output=write',
        ...modifiedDartFiles,
      ], runInShell: false);

      await logToFile('dart format finished with exit code ${result.exitCode}');
      await logToFile('STDOUT:\n${result.stdout}');
      await logToFile('STDERR:\n${result.stderr}');

      if (result.exitCode != 0) {
        emitEmptyResult();
        onExit(result.exitCode);
        return;
      }

      emitEmptyResult();
      onExit(0);
      return;
    } catch (e, stackTrace) {
      await logToFile('UNHANDLED EXCEPTION: $e');
      await logToFile(stackTrace.toString());
      emitEmptyResult();
      onExit(1);
      return;
    }
  }
}
