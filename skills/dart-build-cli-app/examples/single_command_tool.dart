// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Example template for a single-command Dart CLI script or utility.
///
/// Demonstrates argument parsing with `ArgParser`, standard I/O stream routing,
/// and non-destructive exit code assignment via `exitCode`.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart' show ExitCode;
import 'package:stack_trace/stack_trace.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show detailed stack traces on fatal error.',
    )
    ..addOption(
      'input',
      abbr: 'i',
      mandatory: true,
      help: 'Path to the input file to process.',
    );

  try {
    final results = parser.parse(args);

    if (results.flag('help')) {
      // Explicit help requested by user: write usage to stdout.
      stdout
        ..writeln('Usage: tool [options]')
        ..writeln(parser.usage);
      return;
    }

    await _runTool(results);
  } on FormatException catch (e) {
    // Argument parse error: write error message AND usage to stderr.
    stderr
      ..writeln('Error: ${e.message}')
      ..writeln(parser.usage);
    exitCode = ExitCode.usage.code;
  } on ArgumentError catch (e) {
    // Missing mandatory option error thrown by results.option():
    stderr
      ..writeln('Error: ${e.message}')
      ..writeln(parser.usage);
    exitCode = ExitCode.usage.code;
  } catch (e, st) {
    stderr.writeln('Fatal error: $e');
    if (args.contains('-v') || args.contains('--verbose')) {
      stderr.writeln(Trace.from(st).terse);
    }
    exitCode = ExitCode.software.code;
  }
}

/// Encapsulates the tool's core business logic.
///
/// In larger applications, place this logic in `lib/src/` rather than
/// directly in `bin/` so unit tests can import and test functions directly
/// without needing to spawn an OS subprocess.
Future<void> _runTool(ArgResults args) async {
  final inputPath = args.option('input')!;
  stdout.writeln('Processing $inputPath...');
}
