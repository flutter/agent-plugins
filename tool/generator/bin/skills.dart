// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:skills/src/commands/generate_skill_command.dart';
import 'package:skills/src/commands/update_readme_command.dart';
import 'package:skills/src/commands/update_skill_command.dart';
import 'package:skills/src/commands/validate_skill_command.dart';

const String version = '0.1.0';

Future<void> main(List<String> arguments) async {
  final httpClient = http.Client();

  final runner =
      CommandRunner<void>(
          'skills',
          'CLI tool for generating, updating, and validating Agent Skills.',
        )
        ..addCommand(GenerateSkillCommand(httpClient: httpClient))
        ..addCommand(UpdateSkillCommand(httpClient: httpClient))
        ..addCommand(ValidateSkillCommand(httpClient: httpClient))
        ..addCommand(UpdateReadmeCommand());

  runner.argParser.addFlag(
    'version',
    negatable: false,
    help: 'Print the tool version.',
  );
  runner.argParser.addFlag(
    'verbose',
    abbr: 'v',
    negatable: false,
    help: 'Show additional command output.',
  );

  StreamSubscription<LogRecord>? logSubscription;
  try {
    final results = runner.parse(arguments);
    if (results.flag('version')) {
      stdout.writeln('skills version: $version');
      return;
    }

    logSubscription = _configureLogging(results.flag('verbose'));

    if (results.flag('verbose')) {
      Logger.root.fine('All arguments: ${results.arguments}');
    }

    await runner.run(arguments);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  } on Exception catch (e) {
    stderr.writeln('An error occurred: $e');
    exitCode = 1;
  } finally {
    await logSubscription?.cancel();
    httpClient.close();
  }
}

StreamSubscription<LogRecord> _configureLogging(bool verbose) {
  Logger.root.level = verbose ? Level.ALL : Level.INFO;
  return Logger.root.onRecord.listen((record) {
    if (record.level >= Level.SEVERE) {
      stderr.writeln(record.message);
      exitCode = 1;
    } else {
      stdout.writeln(record.message);
    }
  });
}
