---
name: author-agent-hook
description: Helps scaffold deterministic script execution triggered by agent lifecycle events (jetski/antigravity hooks) against a minimal set of changes. Make sure to invoke this skill eagerly whenever a user mentions they want to author a hook, automate tasks/scripts on every change, integrate custom scripts/linters into the agent loop, or set up event handlers inside hooks.json, even if they don't explicitly ask for 'hook scaffolding.'
---

# Authoring Agent Lifecycle Hooks (`author-agent-hook`)

This skill establishes standard, deterministic scaffolding to execute a user-provided script or command during specific agent lifecycle events within the `dart_hooks` repository.

## 1. Initial Context Gathering
Before authoring code, confirm with the user:
- **Target Script/Command**: The exact path or command string the user wants to execute.
- **Lifecycle Event Type**: The target event type (`PreToolUse`, `PostToolUse`, `PreInvocation`, `PostInvocation`, or `Stop`). If the user does not specify or does not know the event type, **assume `"Stop"`** by default.

## 2. Scaffolding Implementation Details
Implement the hook functionality by generating the following standard file structure:

### A. Executable Runner Script (`bin/agent_<hook_name>.dart`)
Create a thin entry point script inside the `bin/` directory delegating execution to the shared `runHookMain` utility.
- **CRITICAL**: Ensure the script contains a proper shebang (`#!/usr/bin/env dart`).
- **CRITICAL**: Ensure the script file has POSIX executable permissions enabled (`chmod +x`). Without execution bits, the shell will reject execution with `Permission denied` (exit code 126) when triggered via `hooks.json`.
- **Implementation Pattern**:
```dart
#!/usr/bin/env dart
// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_hooks/src/<hook_name>_hook.dart';
import 'package:dart_hooks/src/hook_utils.dart';

Future<void> main(List<String> args) async {
  await runHookMain(
    args: args,
    logFileName: '<hook_name>.log',
    executeHook: (String source, Future<void> Function(String) logToFile) async {
      final String packageRoot = Directory.current.parent.path;
      final <HookClassName> hook = <HookClassName>(logToFile: logToFile);
      await hook.run(
        args: args,
        currentPath: Directory.current.path,
        packageRoot: packageRoot,
        triggerSource: source,
      );
    },
  );
}
```

### B. Core Hook Subclass (`lib/src/<hook_name>_hook.dart`)
Implement the custom hook logic by extending `BaseGitHook`.
- Provide standard overrides for `allowedExtensions`, `hookName`, and `executeCommand`.
- If the target script needs to process specific filtered paths or directories, override `transformScopedFiles` to map scoped files to the target command arguments.

### C. Configuration Registration (`.agents/hooks.json`)
Register the hook under the user-specified (or defaulted `"Stop"`) event type key inside `.agents/hooks.json`.
- **Command String Details**: Format the command string exactly as required for direct execution via `sh -c`.
```json
"<hook_name>": {
  "<EventType>": [
    {
      "type": "command",
      "command": "../bin/agent_<hook_name>.dart --source hook --log",
      "timeout": 120
    }
  ]
}
```
*(Note: For `Stop` events, handlers use a flat array structure directly under the event key without `matcher` or nested `hooks` wrappers).*

## 3. Static Analysis & Testing Hygiene
Ensure all generated code strictly adheres to repository static analysis standards:
- **Typing Rules**: Run `dart analyze` to ensure complete absence of info, warning, or error messages.
- **Unit & Integration Tests**: Author comprehensive test coverage in `test/agent_<hook_name>_test.dart` and `test/agent_<hook_name>_integration_test.dart` verifying behavior via mock process runners and actual temp Git repositories. Verify success using the `run_tests` tool.
