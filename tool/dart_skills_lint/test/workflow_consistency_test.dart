// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('CI workflow consistency', () {
    test('CI workflow cognitive complexity fail-threshold does not exceed 20', () {
      final File workflowFile = _getWorkflowFile();
      expect(workflowFile.existsSync(), isTrue, reason: 'CI workflow file missing');
      final String content = workflowFile.readAsStringSync();
      final regex = RegExp(
        r'dart\s+run\s+cognitive_complexity\s+--fail-threshold\s+(\d+)\s+tool/dart_skills_lint/lib\s+tool/dart_skills_lint/test',
      );
      final RegExpMatch? match = regex.firstMatch(content);
      expect(
        match,
        isNotNull,
        reason: 'CI workflow must run cognitive_complexity with --fail-threshold <N>',
      );
      final int threshold = int.parse(match!.group(1)!);
      expect(
        threshold,
        lessThanOrEqualTo(20),
        reason: 'cognitive complexity fail-threshold in CI ($threshold) should not exceed 20',
      );
    });
  });
}

File _getWorkflowFile() {
  Directory dir = Directory.current;
  while (dir.path != '/' && dir.path.isNotEmpty) {
    final workflowFile = File(
      p.join(dir.path, '.github', 'workflows', 'dart_skills_lint_workflow.yaml'),
    );
    if (workflowFile.existsSync()) {
      return workflowFile;
    }
    dir = dir.parent;
  }
  return File(p.normalize(p.absolute('../../.github/workflows/dart_skills_lint_workflow.yaml')));
}
