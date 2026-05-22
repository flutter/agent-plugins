// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/models/skills_ignores.dart';
import 'package:dart_skills_lint/src/skills_ignores_storage.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  final storage = SkillsIgnoresStorage();
  // Reassigned in setUp; the placeholder keeps the field non-`late`.
  Directory tempDir = Directory.systemTemp;

  setUp(() async {
    tempDir = await createTempDir('storage_test.');
  });

  group('SkillsIgnoresStorage.load Integration', () {
    test('inflates empty JSON into empty skills map', () async {
      final file = File('${tempDir.path}/empty.json');
      await file.writeAsString('{}');

      final SkillsIgnores ignores = await storage.load(file.path);
      expect(ignores.skills.isEmpty, isTrue);
    });

    test('inflates single skill with 1 ignore', () async {
      final file = File('${tempDir.path}/one_ignore.json');
      await file.writeAsString('''
{
  "skills": {
    "skill-a": [
      {"rule_id": "rule1", "file_name": "file1.md"}
    ]
  }
}
''');

      final SkillsIgnores ignores = await storage.load(file.path);
      expect(ignores.skills.containsKey('skill-a'), isTrue);
      expect(ignores.skills['skill-a']!.length, equals(1));
    });

    test('inflates single skill with 2 ignores', () async {
      final file = File('${tempDir.path}/two_ignores.json');
      await file.writeAsString('''
{
  "skills": {
    "skill-a": [
      {"rule_id": "rule1", "file_name": "file1.md"},
      {"rule_id": "rule2", "file_name": "file1.md"}
    ]
  }
}
''');

      final SkillsIgnores ignores = await storage.load(file.path);
      expect(ignores.skills.containsKey('skill-a'), isTrue);
      expect(ignores.skills['skill-a']!.length, equals(2));
    });

    test('inflates three skills with varied ignores', () async {
      final file = File('${tempDir.path}/three_skills.json');
      await file.writeAsString('''
{
  "skills": {
    "skill-a": [{"rule_id": "rule1", "file_name": "file1.md"}],
    "skill-b": [{"rule_id": "rule1", "file_name": "file1.md"}, {"rule_id": "rule2", "file_name": "file1.md"}],
    "skill-c": [{"rule_id": "rule1", "file_name": "file1.md"}, {"rule_id": "rule2", "file_name": "file1.md"}, {"rule_id": "rule3", "file_name": "file1.md"}]
  }
}
''');

      final SkillsIgnores ignores = await storage.load(file.path);
      expect(ignores.skills.containsKey('skill-a'), isTrue);
      expect(ignores.skills.containsKey('skill-b'), isTrue);
      expect(ignores.skills.containsKey('skill-c'), isTrue);
      expect(ignores.skills['skill-a']!.length, equals(1));
      expect(ignores.skills['skill-b']!.length, equals(2));
      expect(ignores.skills['skill-c']!.length, equals(3));
    });
  });
}
