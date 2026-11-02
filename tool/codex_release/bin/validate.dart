import 'dart:io';

import 'package:args/args.dart';
import 'package:codex_release/codex_release.dart';

/// Validates a Codex plugin zip against OpenAI's documented package rules.
///
/// Usage: `dart run tool/codex_release/bin/validate.dart ZIP [--version 1.0.8]`
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('version', help: 'The version the manifest must have.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults options;
  try {
    options = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exit(64);
  }
  if (options.flag('help') || options.rest.length != 1) {
    stdout.writeln(
      'Usage: validate.dart <zip> [--version <version>]\n\n${parser.usage}',
    );
    exit(options.flag('help') ? 0 : 64);
  }

  final file = File(options.rest.single);
  if (!file.existsSync()) {
    stderr.writeln('Error: ${file.path} does not exist.');
    exit(1);
  }
  final version = options.option('version');
  final findings = validateZip(
    file.readAsBytesSync(),
    expectedVersion: version == null || version.isEmpty ? null : version,
  );
  if (findings.isEmpty) {
    stdout.writeln('✓ ${file.path} passed all checks.');
    return;
  }

  final inActions = Platform.environment['GITHUB_ACTIONS'] == 'true';
  stderr.writeln('✗ ${file.path} has ${findings.length} problem(s):');
  for (final finding in findings) {
    stderr.writeln(
      inActions ? '::error title=${finding.code}::$finding' : '  $finding',
    );
  }
  exit(1);
}
