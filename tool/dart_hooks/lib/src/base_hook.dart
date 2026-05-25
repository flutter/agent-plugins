// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'hook_utils.dart';
import 'process_runner.dart';

/// Base class for hooks using the Template Method pattern.
abstract class BaseHook {
  BaseHook({
    required this.processRunner,
    required this.fileExists,
    required this.printStdout,
    required this.logToFile,
    required this.onExit,
    FutureOr<String> Function(String)? readFile,
  }) : readFile = readFile ?? ((path) => File(path).readAsString());

  final ProcessRunner processRunner;
  final bool Function(String) fileExists;
  final void Function(String) printStdout;
  final Future<void> Function(String) logToFile;
  final void Function(int) onExit;
  final FutureOr<String> Function(String) readFile;

  /// The allowed file extensions for this hook (e.g., ['.dart']).
  List<String> get allowedExtensions;

  /// The name of the hook for logging purposes.
  String get hookName;

  /// The configuration key in `dart_hooks.yaml` that determines if this hook is enabled.
  String get configKey;

  /// Runs the specific command on the files (e.g., `dart analyze`).
  @protected
  Future<ProcessResult> executeCommand(List<String> files);

  /// Runs the hook logic.
  Future<void> run({
    required List<String> args,
    required String currentPath,
    required String packageRoot,
    required String triggerSource,
  }) async {
    // 0. Resolve configuration setting.
    final String configPath = path.join(packageRoot, 'dart_hooks.yaml');
    if (!fileExists(configPath)) {
      // Do NOT log anything for a missing config file.
      printStdout(jsonEncode({'decision': 'stop'}));
      onExit(0);
      return;
    }

    try {
      final String configContent = await readFile(configPath);
      final dynamic yaml = loadYaml(configContent);
      if (yaml is Map) {
        if (!yaml.containsKey(configKey)) {
          final String foundKeys = yaml.keys.join(', ');
          await logToFile(
            'Hook $hookName is disabled (key "$configKey" is missing in configuration). '
            'Found keys: [$foundKeys]. Did you mean to enable it with "$configKey: true"?',
          );
          printStdout(jsonEncode({'decision': 'stop'}));
          onExit(0);
          return;
        }

        final dynamic isEnabled = yaml[configKey];
        if (isEnabled == true) {
          await logToFile('Hook $hookName is enabled in configuration.');
        } else {
          await logToFile('Hook $hookName is disabled.');
          printStdout(jsonEncode({'decision': 'stop'}));
          onExit(0);
          return;
        }
      } else {
        await logToFile('Hook $hookName is disabled (invalid configuration format).');
        printStdout(jsonEncode({'decision': 'stop'}));
        onExit(0);
        return;
      }
    } catch (e) {
      await logToFile('Hook $hookName is disabled (failed to parse configuration: $e).');
      printStdout(jsonEncode({'decision': 'stop'}));
      onExit(0);
      return;
    }

    await logToFile('$hookName started in $currentPath (Trigger: $triggerSource)');

    try {
      // 1. Get repo root
      final ProcessResult repoRootResult = await processRunner.run('git', [
        'rev-parse',
        '--show-toplevel',
      ]);

      if (repoRootResult.exitCode != 0) {
        await logToFile('ERROR: Failed to get repo root.');
        printStdout(jsonEncode({'decision': 'continue', 'reason': 'Failed to get repo root.'}));
        onExit(0);
        return;
      }
      final String repoRootRaw = (repoRootResult.stdout as String).trim();
      final repoDir = Directory(repoRootRaw);
      final String repoRoot = repoDir.existsSync()
          ? repoDir.resolveSymbolicLinksSync()
          : repoRootRaw;

      // 2. Get modified files
      final List<String> files;
      try {
        // ignore: invalid_use_of_visible_for_testing_member
        files = await getModifiedFilesInternal(
          runProcess: processRunner.run,
          packageRoot: packageRoot,
          repoRoot: repoRoot,
          fileExists: fileExists,
          allowedExtensions: allowedExtensions,
        );
      } catch (e) {
        await logToFile('ERROR: Failed to get modified files: $e');
        printStdout(jsonEncode({'decision': 'continue', 'reason': 'Failed to get status.'}));
        onExit(0);
        return;
      }

      // 3. Filter files (Hierarchical scoping)
      // The scope is the directory containing the .agents folder.
      // packageRoot is passed as the directory containing .agents.
      final scopeDirEntity = Directory(packageRoot);
      final String scopeDir = scopeDirEntity.existsSync()
          ? scopeDirEntity.resolveSymbolicLinksSync()
          : packageRoot;

      final List<String> scopedFiles = files.where((file) {
        var canonicalFile = file;
        try {
          final fileEntity = File(file);
          if (fileEntity.existsSync()) {
            canonicalFile = fileEntity.resolveSymbolicLinksSync();
          }
        } on FileSystemException {
          // Intentionally ignored to fall back.
        }
        return path.isWithin(scopeDir, canonicalFile);
      }).toList();

      if (scopedFiles.isEmpty) {
        await logToFile('No matching files found to process in scope: $scopeDir.');
        printStdout(jsonEncode({'decision': 'stop'}));
        onExit(0);
        return;
      }

      await logToFile('Running command on ${scopedFiles.length} files...');

      // 4. Execute the specific command in chunks to avoid ARG_MAX limits.
      // Determining the exact ARG_MAX is hard as it varies by OS and depends on environment size.
      const maxCharsPerChunk = 4000;
      var combinedExitCode = 0;
      final combinedStdout = StringBuffer();
      final combinedStderr = StringBuffer();

      var currentChunk = <String>[];
      var currentChunkLength = 0;

      for (final file in scopedFiles) {
        // Add 1 for the space separator between arguments
        final int fileLen = file.length + 1;

        if (currentChunkLength + fileLen > maxCharsPerChunk && currentChunk.isNotEmpty) {
          await logToFile('Running command on chunk of ${currentChunk.length} files...');
          final ProcessResult result = await executeCommand(currentChunk);

          if (result.exitCode != 0) {
            combinedExitCode = result.exitCode;
          }
          combinedStdout.write(result.stdout);
          combinedStderr.write(result.stderr);

          currentChunk = <String>[];
          currentChunkLength = 0;
        }

        currentChunk.add(file);
        currentChunkLength += fileLen;
      }

      // Run the last chunk if not empty
      if (currentChunk.isNotEmpty) {
        await logToFile('Running command on chunk of ${currentChunk.length} files...');
        final ProcessResult result = await executeCommand(currentChunk);

        if (result.exitCode != 0) {
          combinedExitCode = result.exitCode;
        }
        combinedStdout.write(result.stdout);
        combinedStderr.write(result.stderr);
      }

      final exitCode = combinedExitCode;
      final String output = combinedStdout.toString().trim();
      final String error = combinedStderr.toString().trim();

      await logToFile('Command finished with code $exitCode');

      // 5. Handle result
      if (exitCode == 0) {
        await logToFile('Command passed');
        printStdout(jsonEncode({'decision': 'stop'}));
        onExit(0);
        return;
      }

      await logToFile('Command failed');
      final separator = (output.isNotEmpty && error.isNotEmpty) ? '\n' : '';
      final reason =
          '$hookName issues found. Please fix these before finishing:\n\n$output$separator$error';
      printStdout(jsonEncode({'decision': 'continue', 'reason': reason.trim()}));
      onExit(0);
      return;
    } catch (e, stackTrace) {
      await logToFile('UNHANDLED EXCEPTION: $e');
      await logToFile(stackTrace.toString());
      printStdout(
        jsonEncode({'decision': 'continue', 'reason': 'Unhandled exception in $hookName hook.'}),
      );
      onExit(1);
      return;
    }
  }
}
