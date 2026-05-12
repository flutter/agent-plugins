#!/usr/bin/env dart
// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_hooks/src/hook_utils.dart';
import 'package:dart_hooks/src/skill_lint_hook.dart';

/// Runs `dart_skills_lint` against any skill whose `SKILL.md` was modified.
/// Typically invoked automatically by Antigravity via `.agents/hooks.json`.
/// To run manually, execute from the project root:
/// `dart tool/dart_hooks/bin/agent_skill_lint.dart`
Future<void> main(List<String> args) async {
  await runHookMain(
    args: args,
    logFileName: 'skill_lint.log',
    executeHook: (source, logToFile) async {
      final String packageRoot = Directory.current.parent.path;
      final hook = SkillLintHook(logToFile: logToFile);
      await hook.run(
        args: args,
        currentPath: Directory.current.path,
        packageRoot: packageRoot,
        triggerSource: source,
      );
    },
  );
}
