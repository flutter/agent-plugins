// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_hooks/src/process_runner.dart';
import 'package:path/path.dart' as path;

/// Initializes a temporary git repository with config email/name and a dummy initial commit.
Future<void> setUpGitRepo(Directory tempDir) async {
  final String repoRoot = tempDir.resolveSymbolicLinksSync();

  Future<void> git(List<String> args) async {
    final ProcessResult r = await Process.run(
      'git',
      args,
      workingDirectory: repoRoot,
      runInShell: true,
    );
    if (r.exitCode != 0) {
      throw Exception('git ${args.join(' ')} failed: ${r.stderr}');
    }
  }

  await git(['init']);
  await git(['config', 'user.email', 'test@example.com']);
  await git(['config', 'user.name', 'Test User']);

  await File(path.join(repoRoot, 'README.md')).writeAsString('initial');
  await git(['add', '.']);
  await git(['commit', '-m', 'initial']);
}

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
