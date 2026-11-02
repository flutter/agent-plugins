import 'dart:io';

import 'package:args/args.dart';
import 'package:codex_release/codex_release.dart';

/// Releases the Codex plugin: tags main, waits for the release workflow, and
/// downloads the zip to upload to the OpenAI plugin portal.
///
/// Usage: dart run tool/codex_release/bin/release.dart [--dry-run]
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'dry-run',
      negatable: false,
      help:
          'Check the checkout and build and validate the zip locally, '
          'without creating a tag.',
    )
    ..addOption(
      'repo',
      defaultsTo: 'flutter/agent-plugins',
      help: 'The GitHub repository to release from.',
    )
    ..addOption(
      'remote',
      help: 'The git remote for --repo. Detected from remote URLs by default.',
    )
    ..addOption(
      'branch',
      defaultsTo: 'main',
      help:
          'The branch releases are cut from. Change it only for test runs '
          'on a fork.',
    )
    ..addOption(
      'output-dir',
      defaultsTo: 'dist',
      help: 'Where to save the zip.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults options;
  try {
    options = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exit(64);
  }
  if (options.flag('help')) {
    stdout.writeln('Releases the Codex plugin.\n\n${parser.usage}');
    return;
  }

  final root = await Process.run('git', ['rev-parse', '--show-toplevel']);
  if (root.exitCode != 0) {
    stderr.writeln('Error: run this from inside the agent-plugins repository.');
    exit(1);
  }

  final release = Release(
    Git((root.stdout as String).trim()),
    ReleaseOptions(
      repo: options.option('repo')!,
      remote: options.option('remote'),
      branch: options.option('branch')!,
      outputDirectory: options.option('output-dir')!,
      dryRun: options.flag('dry-run'),
    ),
  );
  try {
    await release.run();
  } on ReleaseException catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  } on BuildException catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  } on CommandException catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
