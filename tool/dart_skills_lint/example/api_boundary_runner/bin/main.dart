// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) => print(record.message));

  print('Running API boundary validation runner...');

  final String scriptDir = p.dirname(Platform.script.toFilePath());
  final String validSkillPath = p.normalize(
    p.absolute(p.join(scriptDir, '..', '..', 'skills', 'valid')),
  );
  final String invalidSkillPath = p.normalize(
    p.absolute(p.join(scriptDir, '..', '..', 'skills', 'invalid')),
  );

  print('Validating valid skill at: $validSkillPath');
  final bool validResult = await validateSkills(
    individualSkillPaths: [validSkillPath],
    resolvedRuleConfigs: {
      'check-absolute-paths': const RuleConfigPatch(severity: AnalysisSeverity.disabled),
    },
  );

  if (!validResult) {
    print('Error: Valid skill fixture failed validation!');
    exit(1);
  }
  print('Success: Valid skill fixture validated cleanly.');

  print('Validating invalid skill at: $invalidSkillPath');
  // Since this is invalid, we expect it to fail under standard rules.
  final bool invalidResult = await validateSkills(
    individualSkillPaths: [invalidSkillPath],
    printWarnings: false,
    quiet: true,
  );

  if (invalidResult) {
    print('Error: Invalid skill fixture unexpectedly passed validation!');
    exit(1);
  }
  print('Success: Invalid skill fixture failed validation as expected.');

  print('API boundary verification completed successfully.');
}
