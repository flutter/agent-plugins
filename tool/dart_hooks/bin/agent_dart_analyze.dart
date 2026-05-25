#!/usr/bin/env dart
// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_hooks/src/dart_analyze_hook.dart';
import 'package:dart_hooks/src/hook_utils.dart';

/// This script is typically run automatically by Antigravity via hooks.json.
/// To run manually, execute from the project root:
/// `dart tool/dart_hooks/bin/agent_dart_analyze.dart`
Future<void> main(List<String> args) async {
  await runHookMain(
    args: args,
    logFileName: 'dart_analyze.log',
    executeHook: (source, logToFile) async {
      final String packageRoot = Directory.current.parent.path;
      final hook = DartAnalyzeHook(
        configKey: 'agent_dart_analyze.dart',
        logToFile: logToFile,
      );
      await hook.run(
        args: args,
        currentPath: Directory.current.path,
        packageRoot: packageRoot,
        triggerSource: source,
      );
    },
  );
}
