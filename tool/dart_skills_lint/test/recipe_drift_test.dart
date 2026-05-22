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
/// The README ships copy-pasteable integration recipes. When a flag or
/// command in them goes stale, downstream adopters silently run a
/// broken pipeline. This test reads the README at test time and
/// asserts each recipe is still well-formed.
///
/// Three checks, deliberately small:
/// 1. The README still has recipe code blocks with non-empty bodies.
/// 2. The GitHub Actions YAML still parses and still wires up the
///    expected setup-dart + install + invocation steps.
/// 3. The pre-commit hook body actually runs end-to-end against the
///    valid and invalid example fixtures and exits with the right code.
///
/// Everything that used to translate `dart pub global run` lines into
/// `dart bin/cli.dart` lines and replay them is gone — it was fragile
/// and didn't catch anything the structural assertion above doesn't.
void main() {
  group('README Recipes drift', () {
    late _RecipeReader reader;
    final String cliPath = p.normalize(p.absolute('bin/cli.dart'));
    final String validFixture = p.normalize(p.absolute('example/valid'));
    final String invalidFixture = p.normalize(p.absolute('example/invalid'));

    setUpAll(() {
      reader = _RecipeReader.fromFile(p.normalize(p.absolute('README.md')));
    });

    test('README has both expected recipes with non-empty bodies', () {
      expect(reader.yamlBlocks, isNotEmpty, reason: 'GitHub Actions YAML recipe missing');
      expect(reader.shellBlocks, isNotEmpty, reason: 'pre-commit hook shell recipe missing');
      for (final _RecipeBlock block in reader.allBlocks) {
        expect(block.body.trim(), isNotEmpty);
      }
    });

    test('GitHub Actions recipe parses and wires up setup-dart + install + invocation', () {
      final YamlMap doc = reader.workflowYaml;
      expect(doc['name'], 'Lint Agent Skills');

      final jobs = doc['jobs'] as YamlMap;
      expect(jobs.keys, contains('lint-skills'));
      final lintJob = jobs['lint-skills'] as YamlMap;
      final steps = lintJob['steps'] as YamlList;

      expect(reader.stepsUsing(steps), contains('dart-lang/setup-dart@v1'));

      final List<String> runs = reader.stepsRunning(steps);
      expect(
        runs.any((r) => r.contains('dart pub global activate dart_skills_lint')),
        isTrue,
        reason: 'workflow no longer installs dart_skills_lint',
      );
      expect(
        runs.any(
          (r) =>
              r.contains('dart pub global run dart_skills_lint') &&
              r.contains('--skills-directory'),
        ),
        isTrue,
        reason: 'workflow no longer runs the linter against a skills directory',
      );
    });

    test('pre-commit hook body exits 0 on a valid fixture, non-zero on an invalid one', () async {
      // Run the actual hook (rewritten to call bin/cli.dart instead of a
      // globally-activated linter) against both example fixtures. This
      // catches drift in the hook's exec line, exit-code propagation, and
      // the linter's response to a known-good vs known-bad skill — all in
      // one place.
      final String hookBody = reader.preCommitHookBody.replaceAll(
        'dart pub global run dart_skills_lint',
        'dart "$cliPath"',
      );

      await _runHookAgainst(hookBody, validFixture, expectZeroExit: true);
      await _runHookAgainst(hookBody, invalidFixture, expectZeroExit: false);
    });
  }, skip: Platform.isWindows ? 'recipe drift uses POSIX shell' : null);
}

Future<void> _runHookAgainst(
  String hookBody,
  String fixturePath, {
  required bool expectZeroExit,
}) async {
  // The recipe targets a roots-directory (--skills-directory); fixtures
  // are individual skills, so swap the flag to --skill and substitute
  // the fixture path in for the placeholder ./.claude/skills.
  final String runnable = hookBody
      .replaceAll('--skills-directory', '--skill')
      .replaceAll('./.claude/skills', fixturePath);

  final Directory tmp = await Directory.systemTemp.createTemp('recipe_hook.');
  try {
    final hookFile = File(p.join(tmp.path, 'pre-commit'));
    await hookFile.writeAsString(runnable);
    final ProcessResult chmod = await Process.run('chmod', ['+x', hookFile.path]);
    expect(chmod.exitCode, 0);

    final TestProcess process = await TestProcess.start(hookFile.path, const []);
    final int exit = await process.exitCode;
    if (expectZeroExit) {
      expect(exit, 0, reason: 'hook should exit 0 against fixture $fixturePath');
    } else {
      expect(exit, isNonZero, reason: 'hook should exit non-zero against fixture $fixturePath');
    }
  } finally {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  }
}

/// Small parser-and-accessor for the recipe section of README.md. The
/// tests above read like a list of assertions; the parsing lives here.
class _RecipeReader {
  _RecipeReader._(this.allBlocks);

  factory _RecipeReader.fromFile(String readmePath) {
    final String content = File(readmePath).readAsStringSync();
    return _RecipeReader._(_extractBlocks(content));
  }

  final List<_RecipeBlock> allBlocks;

  List<_RecipeBlock> get yamlBlocks =>
      allBlocks.where((b) => b.language == 'yaml').toList(growable: false);

  List<_RecipeBlock> get shellBlocks =>
      allBlocks.where((b) => b.language == 'bash').toList(growable: false);

  /// The first YAML block that contains a `jobs:` key — the actual
  /// workflow file the recipe documents (vs. small snippet variants).
  YamlMap get workflowYaml {
    final _RecipeBlock block = yamlBlocks.firstWhere(
      (b) => b.body.contains('jobs:'),
      orElse: () => fail('no full workflow YAML block found under Recipes'),
    );
    final Object? doc = loadYaml(block.body);
    expect(doc, isA<YamlMap>(), reason: 'workflow YAML failed to parse as a map');
    return doc! as YamlMap;
  }

  /// The body between `<<'HOOK'` and `HOOK` markers in the pre-commit
  /// shell recipe — the executable hook itself, sans wrapping `cat >` /
  /// `chmod +x` plumbing.
  String get preCommitHookBody {
    final _RecipeBlock block = shellBlocks.firstWhere(
      (b) => b.body.contains('.git/hooks/pre-commit') && b.body.contains('HOOK'),
      orElse: () => fail('pre-commit HEREDOC recipe missing'),
    );
    final heredoc = RegExp(r"<<'HOOK'\n(.*?)\nHOOK", dotAll: true);
    final RegExpMatch? match = heredoc.firstMatch(block.body);
    expect(match, isNotNull, reason: 'HEREDOC body could not be parsed');
    return match!.group(1)!;
  }

  List<String> stepsUsing(YamlList steps) => steps
      .whereType<YamlMap>()
      .where((s) => s.containsKey('uses'))
      .map((s) => s['uses'] as String)
      .toList(growable: false);

  List<String> stepsRunning(YamlList steps) => steps
      .whereType<YamlMap>()
      .where((s) => s.containsKey('run'))
      .map((s) => s['run'] as String)
      .toList(growable: false);

  static List<_RecipeBlock> _extractBlocks(String readme) {
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
}

class _RecipeBlock {
  _RecipeBlock(this.language, this.body);
  final String language;
  final String body;
}
