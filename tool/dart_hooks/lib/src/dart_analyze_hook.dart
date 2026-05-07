// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'hook_utils.dart';

/// Implements the dart analyze hook logic.
class DartAnalyzeHook {
  /// Creates a [DartAnalyzeHook].
  DartAnalyzeHook({
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

  /// Runs the analysis hook.
  Future<void> run(List<String> args, String currentPath, String packageRoot) async {
    final int sourceIdx = args.indexOf('--source');
    final String triggerSource = (sourceIdx != -1 && sourceIdx + 1 < args.length)
        ? args[sourceIdx + 1].toUpperCase()
        : 'MANUAL';

    await logToFile('dart_analyze.dart started in $currentPath (Trigger: $triggerSource)');

    try {
      // Get the repo root to resolve paths in monorepo.
      final ProcessResult repoRootResult = await runProcess('git', [
        'rev-parse',
        '--show-toplevel',
      ], runInShell: false);

      if (repoRootResult.exitCode != 0) {
        await logToFile('ERROR: Failed to get git repo root.');
        printStdout(jsonEncode({'decision': 'continue', 'reason': 'Failed to get git repo root.'}));
        onExit(0);
        return;
      }
      final String repoRoot = (repoRootResult.stdout as String).trim();

      // Get list of all Dart files in the package not ignored by git
      final ProcessResult gitResult = await runProcess(
        'git',
        ['status', '--porcelain', '-z', '.'],
        runInShell: false,
        workingDirectory: packageRoot,
      );

      if (gitResult.exitCode != 0) {
        await logToFile('ERROR: git status failed with exit code ${gitResult.exitCode}');
        await logToFile(gitResult.stderr as String);
        printStdout(jsonEncode({'decision': 'continue', 'reason': 'Failed to get git status.'}));
        onExit(0); // Exit 0 so Antigravity captures the stdout JSON
        return;
      }

      final List<String> files = [];
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
            files.add(fullPath);
          }
        }
      }

      if (files.isEmpty) {
        await logToFile('No dart files found to analyze.');
        printStdout(jsonEncode({'decision': 'stop'}));
        onExit(0);
        return;
      }

      await logToFile('Running dart analyze on ${files.length} files...');

      // Run dart analyze on those files.
      final ProcessResult result = await runProcess('dart', [
        'analyze',
        '--fatal-infos',
        ...files,
      ], runInShell: false);

      final int exitCode = result.exitCode;
      final output = result.stdout as String;
      final error = result.stderr as String;

      await logToFile('Analysis finished with code $exitCode');

      // If exit code is 0 (no issues), allow the agent to stop.
      if (exitCode == 0) {
        await logToFile('Analysis passed');
        printStdout(jsonEncode({'decision': 'stop'}));
        onExit(0);
        return;
      }

      // If there are issues, tell Antigravity to CONTINUE and provide the reason.
      await logToFile('Analysis failed');

      final reason = 'Analyzer issues found. Please fix these before finishing:\n\n$output$error';
      printStdout(jsonEncode({'decision': 'continue', 'reason': reason}));
      onExit(0); // Exit 0 so Antigravity captures the stdout JSON.
      return;
    } catch (e, stackTrace) {
      await logToFile('UNHANDLED EXCEPTION: $e');
      await logToFile(stackTrace.toString());
      printStdout(
        jsonEncode({'decision': 'continue', 'reason': 'Unhandled exception in dart_analyze hook.'}),
      );
      onExit(1);
      return;
    }
  }
}
