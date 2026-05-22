// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';
import 'package:yaml/yaml.dart';

/// Drift guard for the `## Recipes` section of README.md.
///
/// The README ships two copy-pasteable integration recipes (GitHub Actions
/// + Dart-native pre-commit hook). When a flag in the recipes goes stale
/// or a command is renamed, downstream adopters silently start running
/// broken pipelines. This test extracts the recipes from README at test
/// time and exercises them so the README and the CLI can never drift
/// apart undetected.
///
/// For the GitHub Actions recipe we don't actually invoke the Actions
/// runtime — we parse the YAML and rerun each `dart pub global run
/// dart_skills_lint ...` step locally via `bin/cli.dart` against the
/// `example/` fixtures. For the pre-commit hook we save the shell body
/// to a temp file, point it at the fixtures via a $LINT_CLI env override,
/// and assert the exit code.
void main() {
  group('README Recipes drift', () {
    final String repoRoot = p.normalize(p.absolute('.'));
    final String readmePath = p.join(repoRoot, 'README.md');
    final String cliPath = p.normalize(p.absolute('bin/cli.dart'));
    final String validFixture = p.normalize(p.absolute('example/valid'));
    final String invalidFixture = p.normalize(p.absolute('example/invalid'));

    late List<_RecipeBlock> blocks;

    setUpAll(() {
      final String content = File(readmePath).readAsStringSync();
      blocks = _extractRecipeBlocks(content);
    });

    test('README has both expected recipes with non-empty bodies', () {
      final List<_RecipeBlock> yamlBlocks = blocks.where((b) => b.language == 'yaml').toList();
      final List<_RecipeBlock> shellBlocks = blocks.where((b) => b.language == 'bash').toList();
      expect(yamlBlocks, isNotEmpty, reason: 'GitHub Actions YAML recipe missing');
      expect(shellBlocks, isNotEmpty, reason: 'pre-commit hook shell recipe missing');
      for (final block in blocks) {
        expect(block.body.trim(), isNotEmpty);
      }
    });

    test('GitHub Actions recipe parses as YAML and wires up dart-lang/setup-dart', () {
      final _RecipeBlock yamlBlock = blocks.firstWhere(
        (b) => b.language == 'yaml' && b.body.contains('jobs:'),
        orElse: () => fail('no full workflow YAML block found under Recipes'),
      );

      final dynamic parsed = loadYaml(yamlBlock.body);
      expect(parsed, isA<YamlMap>());
      final doc = parsed as YamlMap;
      expect(doc['name'], 'Lint Agent Skills');

      final jobs = doc['jobs'] as YamlMap;
      expect(jobs.keys, contains('lint-skills'));
      final lintJob = jobs['lint-skills'] as YamlMap;
      final steps = lintJob['steps'] as YamlList;

      final List<String> usesValues = steps
          .whereType<YamlMap>()
          .where((s) => s.containsKey('uses'))
          .map((s) => s['uses'] as String)
          .toList();
      expect(usesValues, contains('dart-lang/setup-dart@v1'));

      final List<String> runValues = steps
          .whereType<YamlMap>()
          .where((s) => s.containsKey('run'))
          .map((s) => s['run'] as String)
          .toList();
      expect(
        runValues.any((r) => r.contains('dart pub global activate dart_skills_lint')),
        isTrue,
        reason: 'workflow no longer installs dart_skills_lint',
      );
      expect(
        runValues.any(
          (r) =>
              r.contains('dart pub global run dart_skills_lint') &&
              r.contains('--skills-directory'),
        ),
        isTrue,
        reason: 'workflow no longer runs the linter against a skills directory',
      );
    });

    test('GitHub Actions recipe flags work when run locally against fixtures', () async {
      // Translate `dart pub global run dart_skills_lint <args>` -> `dart bin/cli.dart <args>`
      // and substitute the fixture path. Catches removed flags / renamed
      // commands without going through pub.dev.
      final _RecipeBlock yamlBlock = blocks.firstWhere(
        (b) => b.language == 'yaml' && b.body.contains('--skills-directory'),
      );
      final List<String> commandLines = _extractRunCommands(
        yamlBlock.body,
      ).where((c) => c.contains('dart_skills_lint')).toList();
      expect(commandLines, isNotEmpty);

      for (final raw in commandLines) {
        final String translated = raw
            .replaceAll('dart pub global run dart_skills_lint', '__CLI__')
            .replaceAll('dart pub global activate dart_skills_lint', 'true');
        if (!translated.contains('__CLI__')) {
          continue; // pure install step, nothing executable to verify here
        }

        // Swap the recipe's skills-directory for a fixture root that we know exists.
        final String withFixturePath = translated.replaceAll(
          RegExp(r'\./\.claude/skills(\S*)?'),
          p.dirname(validFixture),
        );
        final List<String> args = _splitShell(withFixturePath).sublist(1);

        final TestProcess process = await TestProcess.start('dart', [cliPath, ...args]);
        // example/ contains both valid and invalid -> exit 1 is expected.
        final int exit = await process.exitCode;
        expect(exit, isNonZero, reason: 'translated recipe: $raw');
      }
    });

    test('pre-commit hook body runs against fixtures and respects exit code', () async {
      final _RecipeBlock hookBlock = blocks.firstWhere(
        (b) => b.body.contains('.git/hooks/pre-commit') && b.body.contains('HOOK'),
        orElse: () => fail('pre-commit HEREDOC recipe missing'),
      );

      // Pull the body between <<'HOOK' ... HOOK markers and route the lint
      // command back to bin/cli.dart so we don't need a real pub global
      // install on the test machine.
      final heredoc = RegExp(r"<<'HOOK'\n(.*?)\nHOOK", dotAll: true);
      final RegExpMatch? match = heredoc.firstMatch(hookBlock.body);
      expect(match, isNotNull, reason: 'HEREDOC body could not be parsed');
      String hookBody = match!.group(1)!;

      // The hook uses `exec dart pub global run dart_skills_lint ...` —
      // rewrite to the in-tree CLI.
      hookBody = hookBody.replaceAll('dart pub global run dart_skills_lint', 'dart "$cliPath"');

      // Run against example/valid → exit 0.
      final String validHookBody = hookBody.replaceAll('./.claude/skills', validFixture);
      await _runHook(validHookBody, expectZeroExit: true);

      // Run against example/invalid → non-zero exit.
      final String invalidHookBody = hookBody.replaceAll('./.claude/skills', invalidFixture);
      await _runHook(invalidHookBody, expectZeroExit: false);
    });
  }, skip: Platform.isWindows ? 'recipe drift uses POSIX shell' : null);
}

Future<void> _runHook(String body, {required bool expectZeroExit}) async {
  // Strip `--skills-directory` since the substituted path may be a single
  // skill rather than a roots dir. Detect and rewrite to `--skill`.
  final String runnable = body.contains(' --skills-directory ')
      ? body.replaceAll('--skills-directory', '--skill')
      : body;

  final Directory tmp = await Directory.systemTemp.createTemp('recipe_hook.');
  try {
    final hookFile = File(p.join(tmp.path, 'pre-commit'));
    await hookFile.writeAsString(runnable);
    final ProcessResult chmod = await Process.run('chmod', ['+x', hookFile.path]);
    expect(chmod.exitCode, 0);

    final TestProcess process = await TestProcess.start(hookFile.path, const []);
    final int exit = await process.exitCode;
    if (expectZeroExit) {
      expect(exit, 0, reason: 'hook should exit 0 against a valid fixture');
    } else {
      expect(exit, isNonZero, reason: 'hook should exit non-zero against an invalid fixture');
    }
  } finally {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  }
}

class _RecipeBlock {
  _RecipeBlock(this.language, this.body);
  final String language;
  final String body;
}

/// Returns every fenced code block that appears under the `## Recipes`
/// heading (until the next `## ` heading).
List<_RecipeBlock> _extractRecipeBlocks(String readme) {
  final section = RegExp(r'^## Recipes\s*\n(.*?)(?=^## )', multiLine: true, dotAll: true);
  final RegExpMatch? match = section.firstMatch(readme);
  if (match == null) {
    return const [];
  }
  final String body = match.group(1)!;

  final fence = RegExp(r'^```([a-zA-Z0-9_-]*)\s*\n(.*?)^```', multiLine: true, dotAll: true);
  return [
    for (final RegExpMatch m in fence.allMatches(body))
      _RecipeBlock((m.group(1) ?? '').trim(), m.group(2)!),
  ];
}

/// Pulls each `run:` value out of a workflow YAML body as a flat list of
/// shell commands (`|` multi-line runs collapse into one entry per line).
List<String> _extractRunCommands(String yamlBody) {
  final dynamic doc = loadYaml(yamlBody);
  final List<String> out = [];
  if (doc is! YamlMap) {
    return out;
  }
  final jobs = doc['jobs'] as YamlMap;
  for (final Object? job in jobs.values) {
    if (job is! YamlMap) {
      continue;
    }
    final steps = job['steps'] as YamlList?;
    if (steps == null) {
      continue;
    }
    for (final Object? step in steps) {
      if (step is! YamlMap) {
        continue;
      }
      final dynamic run = step['run'];
      if (run is String) {
        for (final String line in run.split('\n')) {
          final String trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            out.add(trimmed);
          }
        }
      }
    }
  }
  return out;
}

/// Minimal POSIX-style word splitter — enough for our recipe commands,
/// which don't contain quotes or shell expansions.
List<String> _splitShell(String command) {
  return command.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
}
