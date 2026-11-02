import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'finding.dart';
import 'process.dart';
import 'release_notes.dart';
import 'validator.dart';
import 'zip_builder.dart';

/// The workflow that builds and validates the zip for a release tag.
const releaseWorkflow = 'release_codex_plugin.yaml';

/// Options for [Release.run].
class ReleaseOptions {
  const ReleaseOptions({
    required this.repo,
    this.remote,
    this.branch = 'main',
    this.outputDirectory = 'dist',
    this.dryRun = false,
    this.pollInterval = const Duration(seconds: 5),
    this.findRunTimeout = const Duration(minutes: 3),
  });

  /// The GitHub repository, e.g. `flutter/agent-plugins`.
  final String repo;

  /// The git remote for [repo]. Detected from the remote URLs if null.
  final String? remote;

  /// The branch releases are cut from.
  final String branch;

  /// Where the downloaded zip is saved, relative to the repo root.
  final String outputDirectory;

  /// If true, checks the checkout and builds and validates the zip locally,
  /// without tagging or pushing.
  final bool dryRun;

  /// How often to look for the workflow run after pushing the tag.
  final Duration pollInterval;

  /// How long to wait for the workflow run to appear.
  final Duration findRunTimeout;
}

/// Thrown when the release stops before completing.
class ReleaseException implements Exception {
  ReleaseException(this.message);

  /// Why the release stopped.
  final String message;

  @override
  String toString() => message;
}

/// Cuts a release: checks the checkout, tags it, waits for CI, and downloads
/// the zip.
class Release {
  Release(
    this.git,
    this.options, {
    this.log = _print,
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? Future<void>.delayed;

  /// Git for the repository being released.
  final Git git;

  /// Release settings.
  final ReleaseOptions options;

  /// Where progress messages go.
  final void Function(String) log;

  final Future<void> Function(Duration) _sleep;

  ProcessRunner get _runner => git.runner;

  /// Runs the release and returns the path of the downloaded zip (or, for a
  /// dry run, the locally built zip).
  Future<String> run() async {
    await _checkGh();
    final remote = options.remote ?? await _findRemote();
    log('Using remote "$remote" for ${options.repo}.');

    await git(['fetch', remote, options.branch, '--tags']);
    await _checkCheckout(remote);

    final manifest = readRepoManifest(git.root);
    final version = _versionOf(manifest);
    final zipName = '${_nameOf(manifest)}-codex-$version.zip';
    final tag = tagFor(version);
    await _checkTagIsNew(remote, tag);
    final sha = await git(['rev-parse', 'HEAD']);
    log('Releasing version $version from $sha.');

    if (options.dryRun) return _dryRun(tag);

    await git(['tag', '-a', tag, '-m', 'Codex plugin $version']);
    await git(['push', remote, 'refs/tags/$tag']);
    log('Pushed tag $tag.');

    final run = await _findRun(sha, tag);
    log('Waiting for ${run.url}');
    final exitCode = await _runner.runInteractive('gh', [
      'run',
      'watch',
      '${run.id}',
      '--repo',
      options.repo,
      '--exit-status',
    ], workingDirectory: git.root);
    if (exitCode != 0) {
      throw ReleaseException(
        'The release workflow failed: ${run.url}\n'
        'Fix the problem on ${options.branch}, bump the version, and release '
        'again. Tags are never moved or reused.',
      );
    }

    final outputDirectory = p.join(git.root, options.outputDirectory);
    await _gh([
      'run',
      'download',
      '${run.id}',
      '--repo',
      options.repo,
      '--name',
      zipName,
      '--dir',
      outputDirectory,
    ]);
    final zipPath = p.join(outputDirectory, zipName);
    if (!File(zipPath).existsSync()) {
      throw ReleaseException(
        'Downloaded the artifact, but $zipPath is missing.',
      );
    }
    log('');
    log('Downloaded $zipPath');
    log(
      'Next: upload it in the OpenAI plugin portal '
      '(https://platform.openai.com/plugins), resolve any findings, submit '
      'for review, and publish after approval.',
    );
    return zipPath;
  }

  Future<void> _checkGh() async {
    try {
      final result = await _runner.run('gh', ['auth', 'status']);
      if (result.exitCode != 0) {
        throw ReleaseException(
          'The GitHub CLI is not signed in. Run `gh auth login`.',
        );
      }
    } on ProcessException {
      throw ReleaseException(
        'The GitHub CLI (gh) is required: https://cli.github.com',
      );
    }
  }

  Future<String> _findRemote() async {
    final output = await git(['remote', '-v']);
    for (final line in output.split('\n')) {
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final url = parts[1].replaceFirst(RegExp(r'\.git$'), '');
      if (url.endsWith('/${options.repo}') ||
          url.endsWith(':${options.repo}')) {
        return parts[0];
      }
    }
    throw ReleaseException(
      'No git remote points at ${options.repo}. Add one, or pass --remote.',
    );
  }

  Future<void> _checkCheckout(String remote) async {
    final status = await git(['status', '--porcelain', '--untracked-files=no']);
    if (status.isNotEmpty) {
      throw ReleaseException(
        'The working tree has uncommitted changes:\n$status',
      );
    }
    final branch = await git(['rev-parse', '--abbrev-ref', 'HEAD']);
    if (branch != options.branch) {
      throw ReleaseException(
        'Releases are cut from ${options.branch}, but the current branch is $branch.',
      );
    }
    final head = await git(['rev-parse', 'HEAD']);
    final upstream = await git(['rev-parse', '$remote/${options.branch}']);
    if (head != upstream) {
      throw ReleaseException(
        '${options.branch} is not up to date with $remote/${options.branch}. '
        'Run `git pull $remote ${options.branch}`.',
      );
    }
  }

  Future<void> _checkTagIsNew(String remote, String tag) async {
    final local = await git.succeeds([
      'rev-parse',
      '--quiet',
      '--verify',
      'refs/tags/$tag',
    ]);
    final onRemote = (await git([
      'ls-remote',
      '--tags',
      remote,
      'refs/tags/$tag',
    ])).isNotEmpty;
    if (local || onRemote) {
      throw ReleaseException(
        '$tag already exists, so this version has already been released. '
        'Bump "version" in .codex-plugin/plugin.json in a PR, merge it, and '
        'release again.',
      );
    }
  }

  Future<String> _dryRun(String tag) async {
    log('Dry run: building and validating the zip locally. No tag is created.');
    final build = await buildZip(git, tag: tag);
    final findings = validateZip(build.bytes, expectedVersion: build.version);
    final outputDirectory = Directory(p.join(git.root, options.outputDirectory))
      ..createSync(recursive: true);
    final zipPath = p.join(outputDirectory.path, build.fileName);
    File(zipPath).writeAsBytesSync(build.bytes);
    _reportFindings(findings);
    log('Built $zipPath');
    log('Release notes:\n${_releaseNotes(build.manifest)}');
    if (findings.isNotEmpty) {
      throw ReleaseException(
        'The zip has ${findings.length} validation problem(s).',
      );
    }
    return zipPath;
  }

  Future<({int id, String url})> _findRun(String sha, String tag) async {
    final deadline = DateTime.now().add(options.findRunTimeout);
    log('Looking for the $releaseWorkflow run for $tag...');
    while (true) {
      // Right after the tag is pushed, `gh run list --workflow` can fail
      // until GitHub registers the workflow, so treat errors as "not yet".
      final result = await _runner.run('gh', [
        'run',
        'list',
        '--repo',
        options.repo,
        '--workflow',
        releaseWorkflow,
        '--commit',
        sha,
        '--event',
        'push',
        '--json',
        'databaseId,url,headBranch',
      ], workingDirectory: git.root);
      final runs = result.exitCode == 0
          ? (jsonDecode(result.stdout as String) as List<Object?>)
                .cast<Map<String, Object?>>()
          : const <Map<String, Object?>>[];
      for (final run in runs) {
        if (run['headBranch'] == tag) {
          return (id: run['databaseId'] as int, url: run['url'] as String);
        }
      }
      if (DateTime.now().isAfter(deadline)) {
        throw ReleaseException(
          'No $releaseWorkflow run started for $tag. Check '
          'https://github.com/${options.repo}/actions/workflows/$releaseWorkflow',
        );
      }
      await _sleep(options.pollInterval);
    }
  }

  Future<String> _gh(List<String> args) async {
    final result = await _runner.run('gh', args, workingDirectory: git.root);
    if (result.exitCode != 0) {
      throw CommandException('gh ${args.join(' ')}', result);
    }
    return (result.stdout as String).trim();
  }

  static String _versionOf(Map<String, Object?> manifest) {
    final version = manifest['version'];
    if (version is! String || ReleaseVersion.tryParse(version) == null) {
      throw ReleaseException(
        '.codex-plugin/plugin.json "version" must be a semantic version.',
      );
    }
    return version;
  }

  static String _nameOf(Map<String, Object?> manifest) {
    final name = manifest['name'];
    if (name is! String || name.isEmpty) {
      throw ReleaseException(
        '.codex-plugin/plugin.json "name" must be a non-empty string.',
      );
    }
    return name;
  }

  void _reportFindings(List<Finding> findings) {
    for (final finding in findings) {
      log('  ✗ $finding');
    }
  }

  static String _releaseNotes(Map<String, Object?> manifest) {
    final extensions = manifest['extensions'] as Map<String, Object?>;
    final openai = extensions['com.openai'] as Map<String, Object?>;
    final publication = openai['publication'] as Map<String, Object?>;
    return publication['release_notes'] as String;
  }
}

void _print(String message) => stdout.writeln(message);
