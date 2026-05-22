// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

String buildFrontmatter({
  String name = 'Skill-Name',
  String description = 'A test skill',
  String? compatibility,
}) {
  final sb = StringBuffer();
  sb.writeln('---');
  sb.writeln('name: $name');
  sb.writeln('description: $description');
  if (compatibility != null) {
    sb.writeln('compatibility: $compatibility');
  }
  sb.writeln('---');
  return sb.toString();
}

/// Creates a temporary directory for testing and automatically cleans it up.
Future<void> withTempDir(FutureOr<void> Function(Directory tempDir) action) async {
  final Directory tempDir = await Directory.systemTemp.createTemp('api_test.');
  try {
    await action(tempDir);
  } finally {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}

/// Helper to create a dummy skill with specific SKILL.md contents.
Future<Directory> createDummySkill(
  Directory parentDir, {
  required String name,
  required String skillContent,
}) async {
  final Directory skillDir = await Directory(p.join(parentDir.path, name)).create(recursive: true);
  await File(p.join(skillDir.path, 'SKILL.md')).writeAsString(skillContent);
  return skillDir;
}
