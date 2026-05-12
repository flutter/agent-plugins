// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:path/path.dart' as p;
import 'base_git_hook.dart';
import 'process_runner.dart';

/// Implements a hook that runs `dart_skills_lint` against any skill whose
/// `SKILL.md` was modified.
///
/// Unlike file-oriented hooks (analyze, format), this hook is skill-directory
/// oriented: it filters the modified-file list to entries whose basename is
/// exactly `SKILL.md`, then runs the linter once with each skill's containing
/// directory passed as a `-s` argument. A single pass; the agent is
/// responsible for fixing reported errors.
class SkillLintHook extends BaseGitHook {
  /// Creates a [SkillLintHook].
  SkillLintHook({
    super.processRunner = const RealProcessRunner(),
    super.fileExists = _defaultFileExists,
    super.printStdout = _defaultPrintStdout,
    required super.logToFile,
    super.onExit = exit,
  });

  static bool _defaultFileExists(String path) => File(path).existsSync();
  static void _defaultPrintStdout(String message) => stdout.writeln(message);

  /// Path to the `dart_skills_lint` package, relative to the repository root.
  static const String _lintPackageRelativePath = 'tool/dart_skills_lint';

  /// CLI entrypoint inside the `dart_skills_lint` package.
  static const String _lintBinRelativePath = 'bin/cli.dart';

  /// Filters the raw git status modified files by extension (e.g., ['.md']) before
  /// scoping and chunking.
  @override
  List<String> get allowedExtensions => ['.md'];

  @override
  String get hookName => 'dart_skills_lint';

  /// Filters the scoped file list to entries whose basename is case-insensitively
  /// `SKILL.md`, then maps each to its parent directory. Duplicates are
  /// removed and the result is sorted for deterministic command-line output.
  @override
  List<String> transformScopedFiles(List<String> scopedFiles) {
    final skillDirectories = <String>{};
    for (final file in scopedFiles) {
      if (p.basename(file).toLowerCase() == 'skill.md') {
        skillDirectories.add(p.normalize(p.dirname(file)));
      }
    }
    return skillDirectories.toList()..sort();
  }

  @override
  Future<ProcessResult> executeCommand(List<String> skillDirectories) {
    final String lintPackageDir = p.join(repoRoot, _lintPackageRelativePath);
    final args = <String>[
      'run',
      '--directory=$lintPackageDir',
      _lintBinRelativePath,
      for (final dir in skillDirectories) ...['-s', dir],
    ];
    return processRunner.run('dart', args);
  }
}
