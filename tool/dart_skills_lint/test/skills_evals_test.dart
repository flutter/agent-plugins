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
      ];

      expect(
        evalsFiles,
        isNotEmpty,
        reason: 'Should find at least one evals.json file in skills or .agents/skills.',
      );

      Set<String>? expectedRootKeys;
      String? expectedRootKeysFilePath;
      Set<String>? expectedEvalItemKeys;
      String? expectedEvalItemFilePath;

      for (final evalsFile in evalsFiles) {
        final Directory skillDir = evalsFile.parent.parent;
        final String skillName = p.basename(skillDir.path);

        final Object? decoded = jsonDecode(evalsFile.readAsStringSync());
        expect(
          decoded,
          isA<Map<String, dynamic>>(),
          reason: '${evalsFile.path} must be a JSON map.',
        );

        if (decoded is! Map<String, dynamic>) {
          fail('${evalsFile.path} must be a JSON map.');
        }

        expect(
          decoded['skill_name'],
          equals(skillName),
          reason: 'skill_name in ${evalsFile.path} must match skill directory name "$skillName".',
        );

        final Set<String> rootKeys = decoded.keys.toSet();
        if (expectedRootKeys == null) {
          expectedRootKeys = rootKeys;
          expectedRootKeysFilePath = evalsFile.path;
        } else {
          expect(
            rootKeys,
            equals(expectedRootKeys),
            reason:
                '${evalsFile.path} root keys do not match consistency pattern. '
                'Expected keys to match the first processed file ($expectedRootKeysFilePath). '
                'All evals.json files must share the exact same root keys.',
          );
        }

        final Object? evalsRaw = decoded['evals'];
        expect(
          evalsRaw,
          isA<List<dynamic>>(),
          reason: 'evals key in ${evalsFile.path} must be a List.',
        );

        if (evalsRaw is! List<dynamic>) {
          fail('evals key in ${evalsFile.path} must be a List.');
        }

        for (final Object? evalItem in evalsRaw) {
          expect(
            evalItem,
            isA<Map<String, dynamic>>(),
            reason: 'Item in evals list in ${evalsFile.path} must be a JSON map.',
          );
          if (evalItem is! Map<String, dynamic>) {
            fail('Item in evals list in ${evalsFile.path} must be a JSON map.');
          }

          final Set<String> itemKeys = evalItem.keys.toSet();
          if (expectedEvalItemKeys == null) {
            expectedEvalItemKeys = itemKeys;
            expectedEvalItemFilePath = evalsFile.path;
          } else {
            expect(
              itemKeys,
              equals(expectedEvalItemKeys),
              reason:
                  'Eval item in ${evalsFile.path} keys do not match consistency pattern. '
                  'Expected eval item keys to match the first processed file ($expectedEvalItemFilePath). '
                  'All eval items must share the exact same keys.',
            );
          }
        }
      }
    });

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
  });
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
