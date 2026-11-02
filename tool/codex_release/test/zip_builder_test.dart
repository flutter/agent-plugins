import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:codex_release/codex_release.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fixtures.dart';

late Directory _repo;

void _write(String path, String content) {
  File(p.join(_repo.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

Future<void> _git(List<String> args) async {
  final result = await Process.run('git', args, workingDirectory: _repo.path);
  if (result.exitCode != 0) fail('git ${args.join(' ')}: ${result.stderr}');
}

Future<void> _commit(String message) async {
  await _git(['add', '-A']);
  await _git(['commit', '-q', '-m', message]);
}

void _writeManifest(String version) {
  final manifest = validManifest()
    ..remove('extensions')
    ..['version'] = version
    ..['description'] = 'Installs skills and the Dart MCP server.'
    ..['keywords'] = ['dart', 'mcp']
    ..['mcpServers'] = {
      'dart-mcp-server': {'command': 'dart'},
    };
  (manifest['interface'] as Map<String, Object?>)['capabilities'] = [
    'Skills',
    'MCP',
  ];
  _write(
    '.codex-plugin/plugin.json',
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
}

void main() {
  setUp(() async {
    _repo = Directory.systemTemp.createTempSync('codex_release_test');
    await _git(['init', '-q', '-b', 'main']);
    await _git(['config', 'user.email', 'test@example.com']);
    await _git(['config', 'user.name', 'Test']);
    _writeManifest('1.0.7');
    _write('assets/icon.svg', squareSvg);
    _write('skills/dart-one/SKILL.md', skillMd('dart-one'));
    _write('skills/dart-two/SKILL.md', skillMd('dart-two'));
    await _commit('Initial');
    await _git(['tag', 'codex-plugin-v1.0.7']);
  });

  tearDown(() => _repo.deleteSync(recursive: true));

  Future<void> makeNextRelease() async {
    _write('skills/dart-three/SKILL.md', skillMd('dart-three'));
    _write(
      'skills/dart-one/SKILL.md',
      skillMd('dart-one', description: 'New.'),
    );
    File(p.join(_repo.path, 'skills/dart-two/SKILL.md')).deleteSync();
    _writeManifest('1.0.8');
    await _commit('Next');
  }

  test('builds a zip that passes validation', () async {
    await makeNextRelease();
    final build = await buildZip(Git(_repo.path), tag: 'codex-plugin-v1.0.8');
    expect(build.fileName, 'dart-flutter-codex-1.0.8.zip');
    expect(validateZip(build.bytes, expectedVersion: '1.0.8'), isEmpty);

    final archive = ZipDecoder().decodeBytes(build.bytes);
    expect(archive.map((f) => f.name), [
      '.codex-plugin/plugin.json',
      'assets/icon.svg',
      'skills/dart-one/SKILL.md',
      'skills/dart-three/SKILL.md',
    ]);
  });

  test('generates release notes from changes since the previous tag', () async {
    await makeNextRelease();
    final build = await buildZip(Git(_repo.path));
    final extensions = build.manifest['extensions'] as Map<String, Object?>;
    final openai = extensions['com.openai'] as Map<String, Object?>;
    final publication = openai['publication'] as Map<String, Object?>;
    expect(
      publication['release_notes'],
      'Added skills: dart-three.\n'
      'Updated skills: dart-one.\n'
      'Removed skills: dart-two.\n'
      'Updated plugin listing details.',
    );
  });

  test('ignores pre-release tags when finding the previous release', () async {
    await _git(['tag', 'codex-plugin-v1.0.8-rc1']);
    await makeNextRelease();
    expect(
      await findPreviousTag(Git(_repo.path), '1.0.8'),
      'codex-plugin-v1.0.7',
    );
  });

  test('describes every skill when there is no previous tag', () async {
    await _git(['tag', '-d', 'codex-plugin-v1.0.7']);
    final build = await buildZip(Git(_repo.path));
    final notes = jsonEncode(build.manifest['extensions']);
    expect(notes, contains('2 skills (dart-one, dart-two)'));
  });

  test('fails when the tag does not match the version', () async {
    expect(
      () => buildZip(Git(_repo.path), tag: 'codex-plugin-v1.0.9'),
      throwsA(isA<BuildException>()),
    );
  });

  test('leaves out untracked files', () async {
    _write('skills/dart-one/scratch.md', 'not committed');
    final build = await buildZip(Git(_repo.path));
    final names = ZipDecoder().decodeBytes(build.bytes).map((f) => f.name);
    expect(names, isNot(contains('skills/dart-one/scratch.md')));
  });

  test('rebuilding the same commit produces an identical zip', () async {
    final first = await buildZip(Git(_repo.path));
    final second = await buildZip(Git(_repo.path));
    expect(second.bytes, first.bytes);
  });
}
