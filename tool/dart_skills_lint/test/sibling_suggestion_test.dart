// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_skills_lint/src/rules/relative_paths_rule.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Unit tests for findSiblingSuggestion. The full path-rule integration is
/// covered in relative_paths_test.dart; these tests exercise the
/// suggestion logic directly so failure messages point at the algorithm
/// rather than at the rule plumbing.
void main() {
  group('findSiblingSuggestion', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sibling_suggestion_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns just the basename when the link had no directory prefix', () async {
      // Missing target: DETAILS.md; actual file on disk: DETAILS.md (typo).
      await File(p.join(tempDir.path, 'DETAILS.md')).writeAsString('details');
      // Original link was just `DEATILS.md` — no parent dir to preserve.
      final String? result = findSiblingSuggestion(
        originalLink: 'DEATILS.md',
        resolvedPath: p.join(tempDir.path, 'DEATILS.md'),
      );
      expect(result, 'DETAILS.md');
    });

    test('preserves the directory prefix when the link had one', () async {
      final Directory refs = await Directory(p.join(tempDir.path, 'references')).create();
      await File(p.join(refs.path, 'DETAILS.md')).writeAsString('details');

      // Original link was `references/DEATILS.md` — the suggestion should
      // include the same prefix so the user can paste it back verbatim.
      final String? result = findSiblingSuggestion(
        originalLink: 'references/DEATILS.md',
        resolvedPath: p.join(refs.path, 'DEATILS.md'),
      );
      expect(result, 'references/DETAILS.md');
    });

    test('returns null when no candidate is close to the missing basename', () async {
      await File(p.join(tempDir.path, 'COMPLETELY_UNRELATED.txt')).writeAsString('nope');
      final String? result = findSiblingSuggestion(
        originalLink: 'MISSING.md',
        resolvedPath: p.join(tempDir.path, 'MISSING.md'),
      );
      expect(result, isNull);
    });

    test('returns null when the parent directory does not exist', () {
      final String? result = findSiblingSuggestion(
        originalLink: 'nonexistent/X.md',
        resolvedPath: p.join(tempDir.path, 'nonexistent', 'X.md'),
      );
      expect(result, isNull);
    });

    test('ignores directories — only files are candidates', () async {
      // Create a *directory* whose name is close to the missing file's
      // basename. It should not be offered as a suggestion.
      await Directory(p.join(tempDir.path, 'DETAILS.md')).create();
      final String? result = findSiblingSuggestion(
        originalLink: 'DEATILS.md',
        resolvedPath: p.join(tempDir.path, 'DEATILS.md'),
      );
      expect(result, isNull);
    });
  });
}
