// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

const String manifestPath = '.codex-plugin/plugin.json';
const String tagPrefix = 'codex-plugin-v';
const String releaseWorkflow = 'release_codex_plugin.yaml';
const String releaseRepo = 'flutter/agent-plugins';

/// `description` for the skills-only release, without the MCP server.
const String releaseDescription =
    'Official Codex plugin for Dart and Flutter that installs Flutter/Dart '
    'Skills for building natively compiled, visually stunning applications '
    'for mobile, web, desktop, and embedded devices from a single codebase.';

/// `interface.longDescription` for the skills-only release.
const String releaseLongDescription =
    'Use official Dart and Flutter skills to develop apps, run workflows, and '
    'manage code from Codex.';

const List<String> _assetFields = [
  'composerIcon',
  'composerIconDark',
  'logo',
  'logoDark',
];

final RegExp _semverPattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(-[^+]+)?(\+.*)?$');

/// Builds and optionally releases the Codex plugin zip for the OpenAI portal.
///
/// Usage:
///   dart tool/build_codex_plugin.dart [--tag=<tag>] [--output-dir=dist]
///   dart tool/build_codex_plugin.dart --release [--dry-run]
Future<void> main(List<String> args) async {
  var release = false;
  var dryRun = false;
  var outputDir = 'dist';
  String? tag;
  String? releaseNotes;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String nextValue() {
      if (i + 1 >= args.length) _fail('Missing value for $arg');
      return args[++i];
    }

    if (arg == '--help' || arg == '-h') {
      _printUsage();
      return;
    } else if (arg == '--release') {
      release = true;
    } else if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--tag') {
      tag = nextValue();
    } else if (arg.startsWith('--tag=')) {
      tag = arg.substring('--tag='.length);
    } else if (arg == '--output-dir') {
      outputDir = nextValue();
    } else if (arg.startsWith('--output-dir=')) {
      outputDir = arg.substring('--output-dir='.length);
    } else if (arg == '--release-notes') {
      releaseNotes = nextValue();
    } else if (arg.startsWith('--release-notes=')) {
      releaseNotes = arg.substring('--release-notes='.length);
    } else {
      _fail('Unknown option: $arg\nRun with --help for usage.');
    }
  }

  final root = _git(['rev-parse', '--show-toplevel']);
  if (release) {
    await _runRelease(root: root, outputDir: outputDir, dryRun: dryRun);
  } else {
    _buildAndVerify(
      root: root,
      outputDir: outputDir,
      tag: tag,
      releaseNotesOverride: releaseNotes,
    );
  }
}

void _printUsage() {
  stdout.writeln('''
Builds and optionally releases the Dart and Flutter Codex plugin zip.

Usage:
  dart tool/build_codex_plugin.dart [options]

Options:
  --tag=<tag>              Verify the manifest version matches <tag>.
  --output-dir=<dir>       Directory to write the zip (default: dist).
  --release-notes=<text>   Override the generated release notes.
  --release                Cut a release: check main, push tag, wait for CI,
                           and download the built artifact to --output-dir.
  --dry-run                With --release, run all preflight checks and build
                           locally without creating or pushing a tag.
  -h, --help               Show this usage information.''');
}

/// Builds the release zip from [root], verifies its contents, and writes it to
/// [outputDir]. Returns the path to the written zip file.
String _buildAndVerify({
  required String root,
  required String outputDir,
  String? tag,
  String? releaseNotesOverride,
}) {
  final repoManifest = _readManifest(root);
  final name = repoManifest['name'];
  final version = repoManifest['version'];
  if (name is! String || name.isEmpty) {
    _fail('$manifestPath "name" must be a non-empty string.');
  }
  if (version is! String || !_semverPattern.hasMatch(version)) {
    _fail('$manifestPath "version" must be a semantic version.');
  }
  final expectedTag = '$tagPrefix$version';
  if (tag != null && tag.isNotEmpty && tag != expectedTag) {
    _fail(
      'Tag $tag does not match $manifestPath version $version '
      '(expected $expectedTag).',
    );
  }

  final notes =
      releaseNotesOverride ?? _generateReleaseNotes(root, version: version);
  final manifest = _createReleaseManifest(repoManifest, releaseNotes: notes);
  final assetPaths = _collectAssetPaths(root, manifest);
  final skillFiles = _gitLines(root, ['ls-files', '--', 'skills']);
  if (skillFiles.isEmpty) {
    _fail('No git-tracked files found under skills/.');
  }

  _verifyReleaseInputs(manifest: manifest, skillFiles: skillFiles);

  final outDir = Directory('$root/$outputDir')..createSync(recursive: true);
  final zipName = '$name-codex-$version.zip';
  final zipPath = '${outDir.path}/$zipName';
  final existingZip = File(zipPath);
  if (existingZip.existsSync()) {
    existingZip.deleteSync();
  }

  final stagingDir = Directory.systemTemp.createTempSync('codex_plugin_');
  try {
    final stagedManifest = File('${stagingDir.path}/$manifestPath')
      ..parent.createSync(recursive: true);
    stagedManifest.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );

    for (final relPath in [...assetPaths, ...skillFiles]) {
      final dest = File('${stagingDir.path}/$relPath')
        ..parent.createSync(recursive: true);
      File('$root/$relPath').copySync(dest.path);
    }

    final zipResult = _runSync('zip', [
      '-r',
      '-q',
      '-X',
      zipPath,
      '.codex-plugin',
      'assets',
      'skills',
    ], workingDirectory: stagingDir.path);
    if (zipResult.exitCode != 0) {
      _fail('zip failed: ${zipResult.stderr}');
    }
  } finally {
    stagingDir.deleteSync(recursive: true);
  }

  final size = File(zipPath).lengthSync();
  stdout
    ..writeln('Built $zipPath ($size bytes)')
    ..writeln('Release notes:\n$notes');
  _writeGitHubOutput({
    'zip_path': zipPath,
    'zip_name': zipName,
    'version': version,
  });
  return zipPath;
}

/// Creates a skills-only copy of [repoManifest] with MCP references removed
/// and `extensions.com.openai.publication.release_notes` set to [releaseNotes].
Map<String, Object?> _createReleaseManifest(
  Map<String, Object?> repoManifest, {
  required String releaseNotes,
}) {
  final manifest = jsonDecode(jsonEncode(repoManifest)) as Map<String, Object?>;
  manifest.remove('mcpServers');
  manifest['description'] = releaseDescription;

  final keywords = manifest['keywords'];
  if (keywords is List) {
    keywords.removeWhere((k) => k is String && k.toLowerCase() == 'mcp');
  }

  final interface = manifest['interface'];
  if (interface is Map<String, Object?>) {
    interface['longDescription'] = releaseLongDescription;
    final capabilities = interface['capabilities'];
    if (capabilities is List) {
      capabilities.removeWhere((c) => c is String && c.toLowerCase() == 'mcp');
    }
  }

  final extensions =
      (manifest['extensions'] ??= <String, Object?>{}) as Map<String, Object?>;
  final openai =
      (extensions['com.openai'] ??= <String, Object?>{})
          as Map<String, Object?>;
  final publication =
      (openai['publication'] ??= <String, Object?>{}) as Map<String, Object?>;
  publication['release_notes'] = releaseNotes;

  return manifest;
}

List<String> _collectAssetPaths(String root, Map<String, Object?> manifest) {
  final paths = <String>{};
  final interface = manifest['interface'];
  if (interface is Map<String, Object?>) {
    for (final field in _assetFields) {
      final value = interface[field];
      if (value is! String || value.isEmpty) continue;
      if (!value.startsWith('./')) {
        _fail('interface.$field must start with "./" (got "$value").');
      }
      final relPath = value.substring(2);
      if (!File('$root/$relPath').existsSync()) {
        _fail('interface.$field references $value, which does not exist.');
      }
      paths.add(relPath);
    }
  }
  if (paths.isEmpty) {
    _fail('Manifest must reference at least one existing branding asset.');
  }
  return paths.toList()..sort();
}

/// Essential sanity checks on the release manifest and skill layout.
void _verifyReleaseInputs({
  required Map<String, Object?> manifest,
  required List<String> skillFiles,
}) {
  if (manifest.containsKey('mcpServers')) {
    _fail('Release manifest must not contain mcpServers.');
  }
  final encoded = jsonEncode(manifest);
  if (RegExp(r'\bmcp\b', caseSensitive: false).hasMatch(encoded)) {
    _fail('Release manifest still contains an MCP reference.');
  }

  final interface = manifest['interface'];
  if (interface is! Map<String, Object?>) {
    _fail('Manifest is missing "interface".');
  }
  final shortDescription = interface['shortDescription'];
  if (shortDescription is! String ||
      shortDescription.isEmpty ||
      shortDescription.length > 30) {
    _fail('interface.shortDescription must be 1–30 characters.');
  }

  final skillDirs = <String>{};
  for (final path in skillFiles) {
    final parts = path.split('/');
    if (parts.length < 2) {
      _fail('Unexpected file directly under skills/: $path');
    }
    skillDirs.add(parts[1]);
  }
  for (final skill in skillDirs) {
    if (!skillFiles.contains('skills/$skill/SKILL.md')) {
      _fail('Skill directory skills/$skill is missing SKILL.md.');
    }
  }
}

/// Generates release notes summarizing skill and manifest changes since the
/// previous `codex-plugin-v*` release tag.
String _generateReleaseNotes(String root, {required String version}) {
  final currentSkills = _skillDirsAtRef(root, 'HEAD');
  final previousTag = _findPreviousTag(root, version);
  if (previousTag == null) {
    return 'Dart and Flutter skills for Codex: ${currentSkills.length} skills '
        '(${currentSkills.join(', ')}).';
  }

  final previousSkills = _skillDirsAtRef(root, previousTag);
  final changedPaths = _gitLines(root, [
    'diff',
    '--name-only',
    previousTag,
    'HEAD',
    '--',
    'skills',
    '.codex-plugin',
    'assets',
  ]);

  final changedSkills = <String>{
    for (final path in changedPaths)
      if (path.startsWith('skills/') && path.split('/').length > 2)
        path.split('/')[1],
  };
  final added = currentSkills
      .where((s) => !previousSkills.contains(s))
      .toList();
  final removed = previousSkills
      .where((s) => !currentSkills.contains(s))
      .toList();
  final updated = currentSkills
      .where((s) => previousSkills.contains(s) && changedSkills.contains(s))
      .toList();
  final metadataChanged = changedPaths.any(
    (p) => p.startsWith('.codex-plugin/') || p.startsWith('assets/'),
  );

  final lines = <String>[
    if (added.isNotEmpty) 'Added skills: ${added.join(', ')}.',
    if (updated.isNotEmpty) 'Updated skills: ${updated.join(', ')}.',
    if (removed.isNotEmpty) 'Removed skills: ${removed.join(', ')}.',
    if (metadataChanged) 'Updated plugin listing details.',
  ];
  return lines.isEmpty ? 'Maintenance release.' : lines.join('\n');
}

String? _findPreviousTag(String root, String currentVersion) {
  final current = _parseSemver(currentVersion);
  if (current == null) return null;
  final tags = _gitLines(root, [
    'tag',
    '--list',
    '$tagPrefix*',
    '--merged',
    'HEAD',
  ]);
  String? bestTag;
  List<int>? bestVersion;
  for (final tag in tags) {
    if (!tag.startsWith(tagPrefix)) continue;
    final verText = tag.substring(tagPrefix.length);
    final match = _semverPattern.firstMatch(verText);
    if (match == null || match[4] != null) continue; // Skip pre-release tags.
    final candidate = [
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    ];
    if (_compareSemver(candidate, current) >= 0) continue;
    if (bestVersion == null || _compareSemver(candidate, bestVersion) > 0) {
      bestTag = tag;
      bestVersion = candidate;
    }
  }
  return bestTag;
}

List<int>? _parseSemver(String version) {
  final match = _semverPattern.firstMatch(version);
  if (match == null) return null;
  return [int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!)];
}

int _compareSemver(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

List<String> _skillDirsAtRef(String root, String ref) {
  final lines = _gitLines(root, [
    'ls-tree',
    '-d',
    '--name-only',
    ref,
    'skills/',
  ]);
  return lines
      .where((p) => p.startsWith('skills/'))
      .map((p) => p.substring('skills/'.length))
      .toList()
    ..sort();
}

/// Runs the maintainer release flow: checks `main`, creates and pushes the
/// release tag, waits for the GitHub Actions workflow, and downloads the zip.
Future<void> _runRelease({
  required String root,
  required String outputDir,
  required bool dryRun,
}) async {
  final ghCheck = _runSync('gh', ['auth', 'status']);
  if (ghCheck.exitCode != 0) {
    _fail('GitHub CLI (gh) is not authenticated. Run `gh auth login`.');
  }

  final target = _resolveTargetRemote(root);
  stdout.writeln('Using remote "${target.remote}" (${target.repo}).');
  _git(['fetch', target.remote, 'main', '--tags'], root: root);

  final status = _git([
    'status',
    '--porcelain',
    '--untracked-files=no',
  ], root: root);
  if (status.isNotEmpty) {
    _fail('Working tree has uncommitted changes:\n$status');
  }
  final currentBranch = _git(['rev-parse', '--abbrev-ref', 'HEAD'], root: root);
  if (!dryRun && currentBranch != 'main') {
    _fail('Releases are cut from main, but current branch is $currentBranch.');
  }
  final head = _git(['rev-parse', 'HEAD'], root: root);
  final upstream = _git(['rev-parse', '${target.remote}/main'], root: root);
  if (!dryRun && head != upstream) {
    _fail(
      'main is not up to date with ${target.remote}/main. '
      'Run `git pull ${target.remote} main`.',
    );
  }

  final manifest = _readManifest(root);
  final version = manifest['version'] as String;
  final name = manifest['name'] as String;
  final tag = '$tagPrefix$version';
  final zipName = '$name-codex-$version.zip';

  final localTag = _runSync('git', [
    'rev-parse',
    '--quiet',
    '--verify',
    'refs/tags/$tag',
  ], workingDirectory: root);
  final remoteTag = _git([
    'ls-remote',
    '--tags',
    target.remote,
    'refs/tags/$tag',
  ], root: root);
  if (localTag.exitCode == 0 || remoteTag.isNotEmpty) {
    _fail(
      'Tag $tag already exists. Bump "version" in $manifestPath in a PR first.',
    );
  }

  if (dryRun) {
    stdout.writeln('Dry run: building and verifying locally without tagging.');
    _buildAndVerify(root: root, outputDir: outputDir, tag: tag);
    return;
  }

  _git(['tag', '-a', tag, '-m', 'Codex plugin $version'], root: root);
  _git(['push', target.remote, 'refs/tags/$tag'], root: root);
  stdout.writeln('Pushed tag $tag ($head). Waiting for workflow run...');

  final run = await _waitForRun(
    root: root,
    repo: target.repo,
    sha: head,
    tag: tag,
  );
  stdout.writeln('Watching ${run.url}');
  final Process watchProcess;
  try {
    watchProcess = await Process.start(
      'gh',
      ['run', 'watch', '${run.id}', '--repo', target.repo, '--exit-status'],
      workingDirectory: root,
      mode: ProcessStartMode.inheritStdio,
    );
  } on ProcessException catch (e) {
    _failMissingTool('gh', e);
  }
  if (await watchProcess.exitCode != 0) {
    _fail('Release workflow failed: ${run.url}');
  }

  final destDir = '$root/$outputDir';
  final dl = _runSync('gh', [
    'run',
    'download',
    '${run.id}',
    '--repo',
    target.repo,
    '--name',
    zipName,
    '--dir',
    destDir,
  ], workingDirectory: root);
  if (dl.exitCode != 0) {
    _fail('gh run download failed: ${dl.stderr}');
  }
  stdout.writeln('\nDownloaded $destDir/$zipName');
}

/// Finds the git remote pointing to `flutter/agent-plugins`, falling back to
/// `origin` (for fork testing).
({String remote, String repo}) _resolveTargetRemote(String root) {
  final remotes = <String, String>{};
  for (final line in _gitLines(root, ['remote', '-v'])) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final match = RegExp(
      r'github\.com[:/]([^/\s]+/[^/\s]+?)(?:\.git)?$',
    ).firstMatch(parts[1]);
    if (match != null) {
      remotes[parts[0]] = match[1]!;
    }
  }
  for (final entry in remotes.entries) {
    if (entry.value == releaseRepo) {
      return (remote: entry.key, repo: entry.value);
    }
  }
  if (remotes.containsKey('origin')) {
    return (remote: 'origin', repo: remotes['origin']!);
  }
  _fail('No GitHub remote found in git remotes.');
}

Future<({int id, String url})> _waitForRun({
  required String root,
  required String repo,
  required String sha,
  required String tag,
}) async {
  final deadline = DateTime.now().add(const Duration(minutes: 2));
  while (DateTime.now().isBefore(deadline)) {
    final result = await _run('gh', [
      'run',
      'list',
      '--repo',
      repo,
      '--workflow',
      releaseWorkflow,
      '--commit',
      sha,
      '--event',
      'push',
      '--json',
      'databaseId,url,headBranch',
    ], workingDirectory: root);
    if (result.exitCode == 0) {
      final runs = (jsonDecode(result.stdout as String) as List<Object?>)
          .cast<Map<String, Object?>>();
      for (final run in runs) {
        if (run['headBranch'] == tag) {
          return (id: run['databaseId'] as int, url: run['url'] as String);
        }
      }
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
  _fail('Timed out waiting for $releaseWorkflow run for $tag.');
}

Map<String, Object?> _readManifest(String root) {
  final file = File('$root/$manifestPath');
  if (!file.existsSync()) {
    _fail('$manifestPath does not exist.');
  }
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, Object?>) return decoded;
  } on FormatException catch (e) {
    _fail('$manifestPath is not valid JSON: ${e.message}');
  }
  _fail('$manifestPath must contain a JSON object.');
}

String _git(List<String> args, {String? root}) {
  final result = _runSync('git', args, workingDirectory: root);
  if (result.exitCode != 0) {
    _fail('git ${args.join(' ')} failed: ${(result.stderr as String).trim()}');
  }
  return (result.stdout as String).trim();
}

List<String> _gitLines(String root, List<String> args) =>
    _git(args, root: root).split('\n').where((l) => l.isNotEmpty).toList();

void _writeGitHubOutput(Map<String, String> outputs) {
  final path = Platform.environment['GITHUB_OUTPUT'];
  if (path == null || path.isEmpty) return;
  File(path).writeAsStringSync(
    outputs.entries.map((e) => '${e.key}=${e.value}\n').join(),
    mode: FileMode.append,
  );
}

/// Runs [executable] synchronously, failing with a helpful message if it is
/// not installed or not on `PATH`.
ProcessResult _runSync(
  String executable,
  List<String> args, {
  String? workingDirectory,
}) {
  try {
    return Process.runSync(
      executable,
      args,
      workingDirectory: workingDirectory,
    );
  } on ProcessException catch (e) {
    _failMissingTool(executable, e);
  }
}

/// Async variant of [_runSync] for use in polling loops so the event loop is
/// not blocked.
Future<ProcessResult> _run(
  String executable,
  List<String> args, {
  String? workingDirectory,
}) async {
  try {
    return await Process.run(
      executable,
      args,
      workingDirectory: workingDirectory,
    );
  } on ProcessException catch (e) {
    _failMissingTool(executable, e);
  }
}

const _toolNames = {'gh': 'GitHub CLI (gh)', 'git': 'Git', 'zip': 'zip'};

Never _failMissingTool(String executable, ProcessException e) {
  final name = _toolNames[executable] ?? executable;
  _fail(
    'Failed to run "$executable". Please ensure $name is installed and '
    'available in your PATH.\nDetails: ${e.message}',
  );
}

Never _fail(String message) {
  stderr.writeln('Error: $message');
  exit(1);
}
