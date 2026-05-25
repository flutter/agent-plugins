// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Walks up from [start] until it finds the directory that contains
/// `.claude-plugin/marketplace.json`, which marks the repository root.
///
/// This lets the test run both from the repository root and from the
/// `tool/marketplace_check` working directory used by CI.
Directory _findRepoRoot(Directory start) {
  var dir = start;
  while (true) {
    final marker = File(p.join(dir.path, '.claude-plugin', 'marketplace.json'));
    if (marker.existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (p.equals(parent.path, dir.path)) {
      throw StateError(
        'Could not find .claude-plugin/marketplace.json walking up from '
        '${start.path}',
      );
    }
    dir = parent;
  }
}

Map<String, dynamic> _readJson(File file) {
  expect(file.existsSync(), isTrue, reason: '${file.path} should exist');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final repoRoot = _findRepoRoot(Directory.current);
  final marketplaceFile = File(
    p.join(repoRoot.path, '.claude-plugin', 'marketplace.json'),
  );
  final pluginLink = p.join(
    repoRoot.path,
    'plugins',
    'flutter-skills',
    'skills',
  );

  group('Claude plugin marketplace', () {
    test('marketplace.json declares the flutter-skills plugin', () {
      final marketplace = _readJson(marketplaceFile);

      expect(marketplace['name'], 'flutter');
      expect(marketplace['owner'], isA<Map<String, dynamic>>());

      final plugins = marketplace['plugins'] as List<dynamic>;
      expect(plugins, hasLength(1));

      final plugin = plugins.single as Map<String, dynamic>;
      expect(plugin['name'], 'flutter-skills');

      // Guards against regressing to `source: "./"`, which would copy the
      // entire repo (tool/, resources/, .agents/) into every user's cache.
      expect(plugin['source'], './plugins/flutter-skills');
    });

    test('plugin source resolves to a directory with a plugin manifest', () {
      final marketplace = _readJson(marketplaceFile);
      final plugin =
          (marketplace['plugins'] as List<dynamic>).single
              as Map<String, dynamic>;
      final source = plugin['source'] as String;

      expect(source, startsWith('./'));
      expect(source, isNot(contains('..')));

      final pluginDir = Directory(p.join(repoRoot.path, source));
      expect(
        pluginDir.existsSync(),
        isTrue,
        reason: 'plugin source "$source" should exist',
      );

      final manifest = _readJson(
        File(p.join(pluginDir.path, '.claude-plugin', 'plugin.json')),
      );
      expect(manifest['name'], plugin['name']);
    });

    test('skills symlink resolves to the top-level skills/ directory', () {
      expect(
        FileSystemEntity.isLinkSync(pluginLink),
        isTrue,
        reason:
            '"$pluginLink" must be a symlink. On Windows, ensure git checks '
            'out symlinks (core.symlinks=true / Developer Mode).',
      );

      final resolvedLink = Link(pluginLink).resolveSymbolicLinksSync();
      final canonicalSkills = Directory(
        p.join(repoRoot.path, 'skills'),
      ).resolveSymbolicLinksSync();

      expect(
        p.equals(resolvedLink, canonicalSkills),
        isTrue,
        reason:
            'symlink should resolve to "$canonicalSkills", '
            'got "$resolvedLink"',
      );
    });

    test('every top-level skill is reachable through the plugin symlink', () {
      final canonicalSkills = Directory(p.join(repoRoot.path, 'skills'));
      final skillNames = canonicalSkills
          .listSync()
          .whereType<Directory>()
          .map((entity) => p.basename(entity.path))
          .where(
            (name) => File(
              p.join(canonicalSkills.path, name, 'SKILL.md'),
            ).existsSync(),
          )
          .toList();

      expect(
        skillNames,
        isNotEmpty,
        reason: 'expected at least one skill in skills/',
      );

      for (final name in skillNames) {
        final viaLink = File(p.join(pluginLink, name, 'SKILL.md'));
        expect(
          viaLink.existsSync(),
          isTrue,
          reason: 'skill "$name" should be reachable via the plugin symlink',
        );
      }
    });
  });
}
