// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Evals structure consistency', () {
    // Ensures all evals.json files dynamically share the exact same JSON schema.
    // Keys are not hardcoded to ensure enforcement remains schema-agnostic and flexible.
    test('all evals.json files across skills share consistent structure and keys', () {
      final List<File> evalsFiles = [
        ..._findEvalsFiles(Directory(p.join(Directory.current.path, 'skills'))),
        ..._findEvalsFiles(Directory(p.join(Directory.current.path, '.agents', 'skills'))),
      ]..sort((a, b) => a.path.compareTo(b.path));

      expect(
        evalsFiles,
        isNotEmpty,
        reason: 'Should find at least one evals.json file in skills or .agents/skills.',
      );

      _verifyStructuralConsistency(evalsFiles, 'evals');
    });

    // Note: We intentionally only require an evals.json file for published skills.
    // Contributor skills in .agents/skills/ are not currently required to have one.
    test('all published skills have an evals.json file', () {
      final skillsDir = Directory(p.join(Directory.current.path, 'skills'));
      if (!skillsDir.existsSync()) {
        return;
      }

      final List<Directory> skillDirs = skillsDir.listSync().whereType<Directory>().toList();

      for (final skillDir in skillDirs) {
        final evalsFile = File(p.join(skillDir.path, 'evals', 'evals.json'));
        expect(
          evalsFile.existsSync(),
          isTrue,
          reason:
              'Published skill "${p.basename(skillDir.path)}" is missing an evals.json file at ${evalsFile.path}',
        );
      }
    });

    test('all rubric JSON files in evals/ share consistent structure and keys', () {
      final rubricsDir = Directory(p.join(Directory.current.path, 'evals'));
      if (!rubricsDir.existsSync()) {
        return;
      }

      final List<File> rubricFiles =
          rubricsDir
              .listSync()
              .whereType<File>()
              .where((File f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      if (rubricFiles.isEmpty) {
        return;
      }

      _verifyStructuralConsistency(rubricFiles, 'evals');
    });
  });
}

void _verifyStructuralConsistency(List<File> files, String itemsKey) {
  Set<String>? expectedRootKeys;
  String? expectedRootKeysFilePath;
  Set<String>? expectedItemKeys;
  String? expectedItemFilePath;

  for (final file in files) {
    final Object? decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>(), reason: '${file.path} must be a JSON map.');

    final decodedMap = decoded! as Map<String, dynamic>;
    final Set<String> rootKeys = decodedMap.keys.toSet();
    if (expectedRootKeys == null) {
      expectedRootKeys = rootKeys;
      expectedRootKeysFilePath = file.path;
    } else {
      expect(
        rootKeys,
        equals(expectedRootKeys),
        reason:
            '${file.path} root keys do not match consistency pattern. '
            'Expected keys to match the first processed file ($expectedRootKeysFilePath).',
      );
    }

    final Object? itemsRaw = decodedMap[itemsKey];
    expect(itemsRaw, isA<List<dynamic>>(), reason: '$itemsKey key in ${file.path} must be a List.');

    final itemsList = itemsRaw! as List<dynamic>;
    for (final Object? item in itemsList) {
      expect(
        item,
        isA<Map<String, dynamic>>(),
        reason: 'Item in $itemsKey list in ${file.path} must be a JSON map.',
      );

      final itemMap = item! as Map<String, dynamic>;
      final Set<String> itemKeys = itemMap.keys.toSet();
      if (expectedItemKeys == null) {
        expectedItemKeys = itemKeys;
        expectedItemFilePath = file.path;
      } else {
        expect(
          itemKeys,
          equals(expectedItemKeys),
          reason:
              'Item in ${file.path} keys do not match consistency pattern. '
              'Expected item keys to match the first processed file ($expectedItemFilePath).',
        );
      }
    }
  }
}

List<File> _findEvalsFiles(Directory baseDir) {
  if (!baseDir.existsSync()) {
    return [];
  }
  return baseDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => p.basename(f.path) == 'evals.json')
      .toList();
}
