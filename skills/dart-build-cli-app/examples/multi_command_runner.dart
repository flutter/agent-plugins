// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Example template for a production multi-command Dart CLI application.
///
/// Demonstrates structured subcommands using `CommandRunner<int>`, standard POSIX
/// exit code constants from `package:io`, and proper `stderr` usage formatting.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:io/io.dart' show ExitCode;
import 'package:stack_trace/stack_trace.dart';

Future<void> main(List<String> args) async {
  final runner = ToolCommandRunner();

  try {
    final status = await runner.run(args);
    exitCode = status ?? ExitCode.success.code;
  } on UsageException catch (e) {
    // Usage errors (invalid flags/arguments) must write to stderr.
    stderr
      ..writeln(e.message)
      ..writeln(e.usage);
    exitCode = ExitCode.usage.code;
  } catch (e, st) {
    stderr.writeln('Fatal error: $e');
    if (args.contains('-v') || args.contains('--verbose')) {
      stderr.writeln(Trace.from(st).terse);
    }
    exitCode = ExitCode.software.code;
  }
}

class ToolCommandRunner extends CommandRunner<int> {
  ToolCommandRunner() : super('tool', 'Multi-command production CLI utility.') {
    argParser
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Show verbose stack traces on failure.',
      )
      ..addFlag('version', negatable: false, help: 'Print tool version.');

    addCommand(ProcessCommand());
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.flag('version')) {
      // In production, reference packageVersion from generated lib/src/version.dart (via package:build_version).
      stdout.writeln('tool version 1.0.0');
      return ExitCode.success.code;
    }
    return super.runCommand(topLevelResults);
  }
}

class ProcessCommand extends Command<int> {
  @override
  final String name = 'process';

  @override
  final String description = 'Process input files.';

  ProcessCommand() {
    argParser.addOption(
      'input',
      abbr: 'i',
      mandatory: true,
      help: 'Path to input file.',
    );
  }

  @override
  Future<int> run() async {
    final input = argResults!.option('input')!;
    stdout.writeln('Processing $input...');
    return ExitCode.success.code;
  }
}
