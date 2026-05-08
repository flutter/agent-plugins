// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

/// Abstraction for running processes, enabling mocking in tests.
abstract class ProcessRunner {
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
    String? workingDirectory,
  });
}

/// Default implementation using [Process.run].
class RealProcessRunner implements ProcessRunner {
  const RealProcessRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      runInShell: runInShell,
      workingDirectory: workingDirectory,
    );
  }
}
