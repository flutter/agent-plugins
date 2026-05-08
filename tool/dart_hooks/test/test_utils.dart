// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
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
