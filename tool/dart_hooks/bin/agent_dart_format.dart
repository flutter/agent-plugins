#!/usr/bin/env dart
// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_hooks/src/dart_format_hook.dart';
import 'package:dart_hooks/src/hook_utils.dart';

Future<void> main(List<String> args) async {
  await runHookMain(
    args: args,
    logFileName: 'dart_format.log',
    executeHook: (source, logToFile) async {
      final hook = DartFormatHook(configKey: 'agent_dart_format.dart', logToFile: logToFile);
      await hook.run(
        args: args,
        currentPath: Directory.current.path,
        packageRoot: Directory.current.parent.path,
        triggerSource: source,
      );
    },
  );
}
