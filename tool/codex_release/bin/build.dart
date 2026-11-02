import 'dart:io';

import 'package:args/args.dart';
import 'package:codex_release/codex_release.dart';
import 'package:path/path.dart' as p;

/// Builds the Codex plugin release zip from the current checkout.
///
/// Usage: dart run tool/codex_release/bin/build.dart [--tag codex-plugin-v1.0.8]
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'tag',
      help:
          'The release tag. The build fails if it does not match the '
          'plugin.json version.',
    )
    ..addOption(
      'output-dir',
      defaultsTo: 'dist',
      help: 'Where to write the zip.',
    )
    ..addOption('release-notes', help: 'Overrides the generated release notes.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults options;
  try {
    options = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exit(64);
  }
  if (options.flag('help')) {
    stdout.writeln('Builds the Codex plugin release zip.\n\n${parser.usage}');
    return;
  }

  try {
    final git = Git(await findRepoRoot());
    final tag = options.option('tag');
    final build = await buildZip(
      git,
      tag: tag == null || tag.isEmpty ? null : tag,
      releaseNotes: options.option('release-notes'),
    );
    final outputDir = Directory(p.join(git.root, options.option('output-dir')!))
      ..createSync(recursive: true);
    final zipPath = p.join(outputDir.path, build.fileName);
    File(zipPath).writeAsBytesSync(build.bytes);
    stdout
      ..writeln('Built $zipPath (${build.bytes.length} bytes)')
      ..writeln('Release notes:')
      ..writeln(releaseNotesOf(build.manifest));
    writeGitHubOutput({
      'zip_path': zipPath,
      'zip_name': build.fileName,
      'version': build.version,
    });
  } on BuildException catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  } on CommandException catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

/// The repository root containing the current directory.
Future<String> findRepoRoot() async {
  final result = await Process.run('git', ['rev-parse', '--show-toplevel']);
  if (result.exitCode != 0) {
    stderr.writeln('Error: run this from inside the agent-plugins repository.');
    exit(1);
  }
  return (result.stdout as String).trim();
}

/// The release notes in a release manifest.
String releaseNotesOf(Map<String, Object?> manifest) {
  final extensions = manifest['extensions'] as Map<String, Object?>;
  final openai = extensions['com.openai'] as Map<String, Object?>;
  final publication = openai['publication'] as Map<String, Object?>;
  return publication['release_notes'] as String;
}

/// Writes step outputs when running in GitHub Actions.
void writeGitHubOutput(Map<String, String> outputs) {
  final path = Platform.environment['GITHUB_OUTPUT'];
  if (path == null) return;
  File(path).writeAsStringSync(
    outputs.entries.map((e) => '${e.key}=${e.value}\n').join(),
    mode: FileMode.append,
  );
}
