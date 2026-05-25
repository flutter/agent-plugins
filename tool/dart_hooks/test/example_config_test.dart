// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_hooks/src/dart_analyze_hook.dart';
import 'package:dart_hooks/src/dart_format_hook.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Verifies that the `dart_hooks.yaml` files committed to the repository
/// actually enable the hooks. The committed files are the examples users copy,
/// and a key that does not match a hook's `configKey` leaves that hook silently
/// disabled (see https://github.com/flutter/skills/issues/150).
///
/// This mirrors the enablement gate in `BaseHook.run()`
/// (`yaml.containsKey(configKey)` && `yaml[configKey] == true`) and reads the
/// keys from the same `configKeyName` constants the hooks use, so the shipped
/// files, the code, and this test cannot drift apart.
void main() {
  group('Shipped dart_hooks.yaml examples', () {
    // `dart test` runs with the package root as the current directory. The
    // committed example files live there and at the surrounding monorepo
    // locations.
    final String packageRoot = Directory.current.path;
    final candidatePaths = <String>[
      path.join(packageRoot, 'dart_hooks.yaml'),
      path.join(packageRoot, '..', 'dart_hooks.yaml'),
      path.join(packageRoot, '..', '..', 'dart_hooks.yaml'),
      path.join(packageRoot, '..', 'dart_skills_lint', 'dart_hooks.yaml'),
    ];

    final List<String> existingPaths = candidatePaths.where((p) => File(p).existsSync()).toList();

    test('at least one shipped example was found to verify', () {
      // Guards against a wrong working directory silently passing the suite.
      expect(
        existingPaths,
        isNotEmpty,
        reason:
            'No committed dart_hooks.yaml files were found relative to '
            '$packageRoot. Checked: $candidatePaths',
      );
    });

    for (final filePath in existingPaths) {
      test('$filePath enables both hooks', () {
        final dynamic yaml = loadYaml(File(filePath).readAsStringSync());
        expect(yaml, isA<Map<dynamic, dynamic>>(), reason: '$filePath is not a YAML map.');
        final yamlMap = yaml as Map<dynamic, dynamic>;

        expect(
          yamlMap[DartFormatHook.configKeyName],
          isTrue,
          reason:
              '$filePath must enable the format hook with '
              '"${DartFormatHook.configKeyName}: true".',
        );
        expect(
          yamlMap[DartAnalyzeHook.configKeyName],
          isTrue,
          reason:
              '$filePath must enable the analyze hook with '
              '"${DartAnalyzeHook.configKeyName}: true".',
        );
      });
    }
  });
}
