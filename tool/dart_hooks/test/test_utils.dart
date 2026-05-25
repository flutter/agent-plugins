// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_hooks/src/dart_analyze_hook.dart';
import 'package:dart_hooks/src/dart_format_hook.dart';
import 'package:dart_hooks/src/process_runner.dart';

/// A mock implementation of [ProcessRunner] that delegates to a function.
class MockProcessRunner implements ProcessRunner {
  /// Creates a [MockProcessRunner] with a delegate function.
  MockProcessRunner(this.onRun);

  /// The function to delegate to.
  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    bool runInShell,
    String? workingDirectory,
  })
  onRun;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
    String? workingDirectory,
  }) {
    return onRun(executable, arguments, runInShell: runInShell, workingDirectory: workingDirectory);
  }
}

/// Returns a YAML configuration string enabling or disabling the analyze hook.
String mockAnalyzeConfig(bool enabled) => '${DartAnalyzeHook.configKeyName}: $enabled\n';

/// Returns a YAML configuration string enabling or disabling the format hook.
String mockFormatConfig(bool enabled) => '${DartFormatHook.configKeyName}: $enabled\n';
