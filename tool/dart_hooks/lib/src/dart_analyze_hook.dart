// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'base_git_hook.dart';
import 'process_runner.dart';

/// Implements the dart analyze hook logic.
class DartAnalyzeHook extends BaseGitHook {
  /// Creates a [DartAnalyzeHook].
  DartAnalyzeHook({
    super.processRunner = const RealProcessRunner(),
    super.fileExists = _defaultFileExists,
    super.printStdout = _defaultPrintStdout,
    required super.logToFile,
    super.onExit = exit,
  });

  static bool _defaultFileExists(String path) => File(path).existsSync();
  static void _defaultPrintStdout(String message) => stdout.writeln(message);

  @override
  List<String> get allowedExtensions => ['.dart'];

  @override
  String get hookName => 'dart analyze';

  @override
  Future<ProcessResult> executeCommand(List<String> files) {
    return processRunner.run('dart', ['analyze', '--fatal-infos', ...files]);
  }
}
