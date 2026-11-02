import 'package:codex_release/codex_release.dart';
import 'package:test/test.dart';

Map<String, Object?> _repoManifest() => {
  'name': 'dart-flutter',
  'version': '1.0.8',
  'description': 'Installs skills and the Dart MCP server.',
  'keywords': ['flutter', 'mcp', 'MCP', 'skills'],
  'interface': {
    'longDescription': 'Skills and the MCP server.',
    'capabilities': ['Skills', 'MCP'],
    'logo': './assets/flutter-icon.svg',
  },
  'mcpServers': {
    'dart-mcp-server': {'command': 'dart'},
  },
};

void main() {
  test('removes every MCP reference and adds release notes', () {
    final release = createReleaseManifest(
      _repoManifest(),
      releaseNotes: 'Notes.',
    );
    expect(release.containsKey('mcpServers'), isFalse);
    expect(release['description'], releaseDescription);
    expect(release['keywords'], ['flutter', 'skills']);
    final interface = release['interface'] as Map<String, Object?>;
    expect(interface['capabilities'], ['Skills']);
    expect(interface['longDescription'], releaseLongDescription);
    expect(interface['logo'], './assets/flutter-icon.svg');
    expect(release['extensions'], {
      'com.openai': {
        'publication': {'release_notes': 'Notes.'},
      },
    });
  });

  test('copies other fields and leaves the input unchanged', () {
    final repo = _repoManifest();
    final release = createReleaseManifest(repo, releaseNotes: 'Notes.');
    expect(release['name'], 'dart-flutter');
    expect(release['version'], '1.0.8');
    expect(repo, _repoManifest());
  });

  test('keeps existing OpenAI extension fields', () {
    final repo = _repoManifest()
      ..['extensions'] = {
        'com.openai': {
          'publication': {'countries': <String>[], 'release_notes': 'Old.'},
        },
      };
    final release = createReleaseManifest(repo, releaseNotes: 'New.');
    expect(release['extensions'], {
      'com.openai': {
        'publication': {'countries': <String>[], 'release_notes': 'New.'},
      },
    });
  });

  test('the release descriptions do not mention MCP', () {
    expect(releaseDescription, isNot(contains('MCP')));
    expect(releaseLongDescription, isNot(contains('MCP')));
  });
}
