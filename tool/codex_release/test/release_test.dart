import 'dart:convert';
import 'dart:io';

import 'package:codex_release/codex_release.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Answers commands from a table keyed by the command line, and records them.
class FakeRunner implements ProcessRunner {
  FakeRunner(this.responses);

  /// Command line prefix → stdout, or an exit code if it's an int.
  final Map<String, Object> responses;

  /// Every command run, in order.
  final commands = <String>[];

  /// Called for `gh run download`, to create the downloaded file.
  void Function(List<String> args)? onDownload;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final command = [executable, ...arguments].join(' ');
    commands.add(command);
    if (command.startsWith('gh run download')) onDownload?.call(arguments);
    for (final entry in responses.entries) {
      if (command.startsWith(entry.key)) {
        final value = entry.value;
        return value is int
            ? ProcessResult(0, value, '', 'failed')
            : ProcessResult(0, 0, value, '');
      }
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final command = [executable, ...arguments].join(' ');
    commands.add(command);
    final value = responses[command];
    return value is int ? value : 0;
  }
}

const _sha = 'abc123';

late Directory _repo;

Map<String, Object> _healthyResponses() => {
  'git remote -v':
      'origin\tgit@github.com:me/agent-plugins.git (fetch)\n'
      'upstream\tgit@github.com:flutter/agent-plugins.git (fetch)',
  'git status --porcelain': '',
  'git rev-parse --abbrev-ref HEAD': 'main',
  'git rev-parse HEAD': _sha,
  'git rev-parse upstream/main': _sha,
  'git rev-parse --quiet --verify refs/tags/': 1,
  'git ls-remote --tags': '',
  'gh run list': jsonEncode([
    {
      'databaseId': 42,
      'url': 'https://github.com/flutter/agent-plugins/actions/runs/42',
      'headBranch': 'codex-plugin-v1.0.8',
    },
  ]),
};

Future<String> _release(FakeRunner runner) => Release(
  Git(_repo.path, runner: runner),
  const ReleaseOptions(
    repo: 'flutter/agent-plugins',
    pollInterval: Duration.zero,
  ),
  log: (_) {},
  sleep: (_) async {},
).run();

void main() {
  setUp(() {
    _repo = Directory.systemTemp.createTempSync('codex_release_flow');
    File(p.join(_repo.path, '.codex-plugin', 'plugin.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({'name': 'dart-flutter', 'version': '1.0.8'}),
      );
  });

  tearDown(() => _repo.deleteSync(recursive: true));

  test('tags, waits for the workflow, and downloads the zip', () async {
    final runner = FakeRunner(_healthyResponses())
      ..onDownload = (args) {
        final dir = args[args.indexOf('--dir') + 1];
        File(p.join(dir, 'dart-flutter-codex-1.0.8.zip'))
          ..createSync(recursive: true)
          ..writeAsStringSync('zip');
      };

    final path = await _release(runner);

    expect(path, p.join(_repo.path, 'dist', 'dart-flutter-codex-1.0.8.zip'));
    expect(
      runner.commands,
      containsAllInOrder([
        'git fetch upstream main --tags',
        'git tag -a codex-plugin-v1.0.8 -m Codex plugin 1.0.8',
        'git push upstream refs/tags/codex-plugin-v1.0.8',
        startsWith(
          'gh run list --repo flutter/agent-plugins '
          '--workflow release_codex_plugin.yaml --commit $_sha',
        ),
        'gh run watch 42 --repo flutter/agent-plugins --exit-status',
        startsWith(
          'gh run download 42 --repo flutter/agent-plugins '
          '--name dart-flutter-codex-1.0.8.zip',
        ),
      ]),
    );
  });

  group('stops before tagging when', () {
    Future<void> expectStop(
      Map<String, Object> overrides,
      String message,
    ) async {
      final runner = FakeRunner({..._healthyResponses(), ...overrides});
      await expectLater(
        _release(runner),
        throwsA(
          isA<ReleaseException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
      expect(runner.commands, isNot(contains(startsWith('git tag'))));
      expect(runner.commands, isNot(contains(startsWith('git push'))));
    }

    test('the working tree is dirty', () {
      return expectStop({
        'git status --porcelain': ' M README.md',
      }, 'uncommitted changes');
    });

    test('the branch is not main', () {
      return expectStop({
        'git rev-parse --abbrev-ref HEAD': 'feature',
      }, 'current branch is feature');
    });

    test('main is behind the remote', () {
      return expectStop({
        'git rev-parse upstream/main': 'def456',
      }, 'not up to date');
    });

    test('the tag already exists on the remote', () {
      return expectStop({
        'git ls-remote --tags': '$_sha\trefs/tags/codex-plugin-v1.0.8',
      }, 'already exists');
    });

    test('no remote points at the repo', () {
      return expectStop({
        'git remote -v': 'origin\tgit@github.com:me/fork.git (fetch)',
      }, 'No git remote');
    });

    test('gh is not signed in', () {
      return expectStop({'gh auth status': 1}, 'gh auth login');
    });
  });

  test('keeps looking while gh run list fails', () async {
    var calls = 0;
    final runner = _FlakyListRunner(_healthyResponses(), () => ++calls < 3)
      ..onDownload = (args) {
        final dir = args[args.indexOf('--dir') + 1];
        File(p.join(dir, 'dart-flutter-codex-1.0.8.zip'))
          ..createSync(recursive: true)
          ..writeAsStringSync('zip');
      };
    await _release(runner);
    expect(calls, 3);
  });

  test('reports the run URL when the workflow fails', () async {
    final runner = FakeRunner({
      ..._healthyResponses(),
      'gh run watch 42 --repo flutter/agent-plugins --exit-status': 1,
    });
    await expectLater(
      _release(runner),
      throwsA(
        isA<ReleaseException>().having(
          (e) => e.message,
          'message',
          contains('actions/runs/42'),
        ),
      ),
    );
    expect(runner.commands, isNot(contains(startsWith('gh run download'))));
  });
}

/// Fails `gh run list` while [shouldFail] returns true.
class _FlakyListRunner extends FakeRunner {
  _FlakyListRunner(super.responses, this.shouldFail);

  final bool Function() shouldFail;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    if (executable == 'gh' &&
        arguments.take(2).join(' ') == 'run list' &&
        shouldFail()) {
      commands.add([executable, ...arguments].join(' '));
      return Future.value(ProcessResult(0, 1, '', 'workflow not found'));
    }
    return super.run(executable, arguments, workingDirectory: workingDirectory);
  }
}
