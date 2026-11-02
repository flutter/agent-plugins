import 'dart:typed_data';

import 'package:codex_release/codex_release.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

Map<String, Object?> _interface(Map<String, Object?> manifest) =>
    manifest['interface'] as Map<String, Object?>;

/// Validates the valid package after applying [change] to its manifest.
List<String> _withManifest(void Function(Map<String, Object?>) change) {
  final manifest = validManifest();
  change(manifest);
  return codesFor(validFiles(manifest: manifest));
}

void main() {
  test('a valid package has no findings', () {
    expect(validateZip(zip(validFiles())), isEmpty);
  });

  group('archive', () {
    test('rejects bytes that are not a zip', () {
      final codes = validateZip(Uint8List.fromList([1, 2, 3]));
      expect(codes.map((f) => f.code), ['archive_format_not_zip']);
    });

    test('rejects a .. path segment', () {
      expect(
        codesFor({...validFiles(), 'skills/../evil.md': 'x'}),
        contains('archive_member_path_has_parent_segment'),
      );
    });

    test('rejects paths that collide after case normalization', () {
      expect(
        codesFor({...validFiles(), 'skills/dart-one/skill.md': 'x'}),
        contains('archive_member_path_normalization_collision'),
      );
    });

    test('rejects paths deeper than 20 segments', () {
      final deep = 'skills/dart-one/${List.filled(19, 'd').join('/')}/f.md';
      expect(
        codesFor({...validFiles(), deep: 'x'}),
        contains('archive_member_path_too_deep'),
      );
    });

    test('rejects a plugin wrapped in a top-level directory', () {
      final wrapped = {
        for (final e in validFiles().entries) 'plugin/${e.key}': e.value,
      };
      expect(codesFor(wrapped), ['plugin_manifest_missing']);
    });
  });

  group('manifest identity', () {
    test('rejects malformed JSON', () {
      expect(
        codesFor({...validFiles(), manifestPath: '{"name": '}),
        contains('plugin_manifest_json_malformed'),
      );
    });

    test('rejects an invalid name', () {
      expect(
        _withManifest((m) => m['name'] = '-bad name'),
        contains('plugin_name_format'),
      );
    });

    test('rejects a non-semver version', () {
      expect(
        _withManifest((m) => m['version'] = '1.0'),
        contains('plugin_version_not_semver'),
      );
    });

    test('rejects a version that does not match the tag', () {
      expect(codesFor(validFiles(), expectedVersion: '1.0.9'), [
        'release_version_mismatch',
      ]);
    });

    test('rejects a description over 1,024 characters', () {
      expect(
        _withManifest((m) => m['description'] = 'a' * 1025),
        contains('plugin_description_too_long'),
      );
    });

    test('requires author.name', () {
      expect(
        _withManifest((m) => m['author'] = <String, Object?>{}),
        contains('plugin_developer_missing'),
      );
    });

    test('requires an HTTPS author URL', () {
      expect(
        _withManifest(
          (m) => (m['author'] as Map<String, Object?>)['url'] = 'http://a.dev',
        ),
        contains('plugin_author_url_not_https'),
      );
    });
  });

  group('listing', () {
    test('rejects a 31-character short description', () {
      expect(
        _withManifest((m) => _interface(m)['shortDescription'] = 'a' * 31),
        ['plugin_short_description_too_long'],
      );
    });

    test('rejects the old 50-character short description', () {
      expect(
        _withManifest(
          (m) => _interface(m)['shortDescription'] =
              'Build and manage Dart and Flutter apps from Codex.',
        ),
        contains('plugin_short_description_too_long'),
      );
    });

    test('rejects a multi-line display name', () {
      expect(
        _withManifest((m) => _interface(m)['displayName'] = 'Dart\nFlutter'),
        contains('plugin_display_name_character_unsupported'),
      );
    });

    test('rejects an unknown category', () {
      expect(
        _withManifest((m) => _interface(m)['category'] = 'Tools'),
        contains('plugin_category_unknown'),
      );
    });

    test('requires capabilities', () {
      expect(
        _withManifest((m) => _interface(m).remove('capabilities')),
        contains('plugin_capabilities_wrong_type'),
      );
    });

    test('rejects a non-HTTPS listing URL', () {
      expect(
        _withManifest((m) => _interface(m)['supportURL'] = 'http://a.dev'),
        contains('plugin_support_url_format'),
      );
    });

    test('rejects more than three starter prompts', () {
      expect(
        _withManifest(
          (m) => _interface(m)['defaultPrompt'] = ['a', 'b', 'c', 'd'],
        ),
        contains('plugin_default_prompt_too_many'),
      );
    });

    test('rejects duplicate starter prompts', () {
      expect(
        _withManifest(
          (m) => _interface(m)['defaultPrompt'] = ['Add a test', 'add  a TEST'],
        ),
        contains('plugin_default_prompt_duplicate'),
      );
    });

    test('rejects a low-contrast brand color', () {
      expect(
        _withManifest((m) => _interface(m)['brandColor'] = '#EEEEEE'),
        contains('plugin_brand_color_contrast'),
      );
    });

    test('accepts the Flutter blue brand color', () {
      expect(
        _withManifest((m) => _interface(m)['brandColor'] = '#027DFD'),
        isEmpty,
      );
    });
  });

  group('excluded content', () {
    test('rejects inline mcpServers', () {
      expect(
        _withManifest(
          (m) => m['mcpServers'] = {
            'dart-mcp-server': {'command': 'dart'},
          },
        ),
        contains('mcp_configuration_excluded'),
      );
    });

    test('rejects a .mcp.json file', () {
      expect(
        codesFor({...validFiles(), '.mcp.json': '{}'}),
        contains('mcp_configuration_excluded'),
      );
    });

    test('rejects MCP in capabilities, keywords, and descriptions', () {
      final codes = _withManifest((m) {
        _interface(m)['capabilities'] = ['Skills', 'MCP'];
        _interface(m)['longDescription'] = 'Skills and the MCP server.';
        m['keywords'] = ['dart', 'mcp'];
        m['description'] = 'Installs the Dart MCP server.';
      });
      expect(codes.where((c) => c == 'release_mcp_reference'), hasLength(4));
    });

    test('rejects screenshots', () {
      expect(
        _withManifest((m) => _interface(m)['screenshots'] = ['./a.png']),
        contains('screenshot_configuration_excluded'),
      );
    });

    test('rejects hooks', () {
      expect(
        codesFor({...validFiles(), 'hooks/hooks.json': '{}'}),
        contains('release_hooks_excluded'),
      );
    });

    test('rejects reviewer credentials', () {
      expect(
        _withManifest((m) {
          final openai =
              (m['extensions'] as Map<String, Object?>)['com.openai']
                  as Map<String, Object?>;
          openai['review'] = {'test_credentials': 'secret'};
        }),
        contains('release_review_field_rejected'),
      );
    });
  });

  group('assets', () {
    test('rejects a non-square PNG logo', () {
      final manifest = validManifest();
      _interface(manifest)['logo'] = './assets/logo.png';
      expect(
        codesFor({
          ...validFiles(manifest: manifest),
          'assets/logo.png': pngHeader(953, 272),
        }),
        ['raster_image_not_square'],
      );
    });

    test('accepts a square PNG', () {
      final manifest = validManifest();
      _interface(manifest)['logo'] = './assets/logo.png';
      expect(
        codesFor({
          ...validFiles(manifest: manifest),
          'assets/logo.png': pngHeader(512, 512),
        }),
        isEmpty,
      );
    });

    test('rejects a PNG over 4096 pixels', () {
      final manifest = validManifest();
      _interface(manifest)['logo'] = './assets/logo.png';
      expect(
        codesFor({
          ...validFiles(manifest: manifest),
          'assets/logo.png': pngHeader(5000, 5000),
        }),
        ['raster_image_dimensions_too_large'],
      );
    });

    test('rejects a non-square SVG', () {
      expect(
        codesFor({
          ...validFiles(),
          'assets/icon.svg':
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 953 272"/>',
        }),
        contains('svg_dimensions_not_square'),
      );
    });

    test('rejects an SVG smaller than 48×48', () {
      expect(
        codesFor({
          ...validFiles(),
          'assets/icon.svg':
              '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"/>',
        }),
        contains('svg_dimensions_too_small'),
      );
    });

    test('rejects SVG dimensions with units', () {
      expect(
        codesFor({
          ...validFiles(),
          'assets/icon.svg':
              '<svg xmlns="http://www.w3.org/2000/svg" width="64px" height="64px"/>',
        }),
        contains('svg_dimensions_not_numeric'),
      );
    });

    test('rejects malformed SVG', () {
      expect(
        codesFor({...validFiles(), 'assets/icon.svg': '<svg'}),
        contains('svg_xml_malformed'),
      );
    });

    test('rejects a missing asset', () {
      final files = validFiles()..remove('assets/icon.svg');
      expect(codesFor(files), contains('declared_asset_file_missing'));
    });

    test('requires ./ on asset paths', () {
      expect(
        _withManifest((m) => _interface(m)['logo'] = 'assets/icon.svg'),
        contains('branding_asset_path_missing_root_prefix'),
      );
    });

    test('requires a logo', () {
      expect(
        _withManifest((m) => _interface(m).remove('logo')),
        contains('plugin_logo_path_missing'),
      );
    });

    test('rejects an extension that does not match the content', () {
      final manifest = validManifest();
      _interface(manifest)['logo'] = './assets/logo.jpg';
      expect(
        codesFor({
          ...validFiles(manifest: manifest),
          'assets/logo.jpg': pngHeader(64, 64),
        }),
        contains('raster_image_extension_content_mismatch'),
      );
    });
  });

  group('skills', () {
    test('rejects a skill without frontmatter', () {
      expect(
        codesFor({...validFiles(), 'skills/dart-one/SKILL.md': '# No header'}),
        contains('skill_frontmatter_missing'),
      );
    });

    test('rejects unclosed frontmatter', () {
      expect(
        codesFor({
          ...validFiles(),
          'skills/dart-one/SKILL.md': '---\nname: dart-one\n',
        }),
        contains('skill_frontmatter_unclosed'),
      );
    });

    test('rejects a missing description', () {
      expect(
        codesFor({
          ...validFiles(),
          'skills/dart-one/SKILL.md': '---\nname: dart-one\n---\nBody\n',
        }),
        contains('skill_description_missing'),
      );
    });

    test('accepts a folded multi-line description', () {
      expect(
        codesFor({
          ...validFiles(),
          'skills/dart-one/SKILL.md':
              '---\nname: dart-one\ndescription: >-\n  Line one\n  line two.\n'
              '---\nBody\n',
        }),
        isEmpty,
      );
    });

    test('rejects a description over 1,024 characters', () {
      expect(
        codesFor({
          ...validFiles(),
          'skills/dart-one/SKILL.md': skillMd(
            'dart-one',
            description: 'a' * 1025,
          ),
        }),
        contains('skill_description_too_long'),
      );
    });

    test('rejects an empty body', () {
      expect(
        codesFor({
          ...validFiles(),
          'skills/dart-one/SKILL.md':
              '---\nname: dart-one\ndescription: x\n---\n',
        }),
        contains('skill_body_empty'),
      );
    });

    test('rejects duplicate skill names', () {
      expect(
        codesFor({
          ...validFiles(),
          'skills/dart-two/SKILL.md': skillMd('dart-one'),
        }),
        contains('skill_identity_duplicate'),
      );
    });

    test('rejects a plugin:skill identity over 64 characters', () {
      final name = 'a' * 60;
      expect(
        codesFor({...validFiles(), 'skills/$name/SKILL.md': skillMd(name)}),
        contains('skill_identity_too_long'),
      );
    });

    test('rejects a skill directory without SKILL.md', () {
      expect(
        codesFor({...validFiles(), 'skills/empty/README.md': 'x'}),
        contains('skill_manifest_missing'),
      );
    });

    test('rejects a file directly under skills/', () {
      expect(
        codesFor({...validFiles(), 'skills/README.md': 'x'}),
        contains('skill_file_ignored'),
      );
    });

    test('rejects a hidden skill directory', () {
      expect(
        codesFor({...validFiles(), 'skills/.hidden/SKILL.md': skillMd('h')}),
        contains('skill_directory_hidden'),
      );
    });

    test('rejects a nested SKILL.md', () {
      expect(
        codesFor({
          ...validFiles(),
          'skills/dart-one/sub/SKILL.md': skillMd('sub'),
        }),
        contains('skill_manifest_nested'),
      );
    });

    test('rejects an agents/openai.yaml without interface', () {
      expect(
        codesFor({
          ...validFiles(),
          'skills/dart-one/agents/openai.yaml': 'policy: {}\n',
        }),
        contains('skill_agent_interface_missing'),
      );
    });

    test('requires at least one skill', () {
      final files = {
        manifestPath: validManifest(),
        'assets/icon.svg': squareSvg,
      };
      expect(codesFor(files), contains('plugin_runtime_surface_missing'));
    });
  });

  test('requires release notes', () {
    expect(_withManifest((m) => m.remove('extensions')), [
      'release_notes_missing',
    ]);
  });
}
