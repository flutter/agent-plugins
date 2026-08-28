---
description: Proactively connect to running Dart/Flutter apps and trigger hot reload or hot restart upon editing .dart files.
trigger: glob
globs: "**/*.dart"
---

# Proactive Flutter Hot Reload Rule

Whenever you edit or modify any `.dart` file in this project:

1. **When to Skip**:
   - **Tests**: Do not trigger hot reload or hot restart when modifying test files (e.g., `test/**`, `*_test.dart`). Run tests using `flutter test` instead.
   - **Comments & Documentation**: Do not trigger hot reload or hot restart when changes only affect comments, docstrings, or whitespace.

2. **Discover & Connect**:
   - Discover active running application instances using the `dtd` tool (or `list_running_apps` / `vm_service`).

3. **Trigger Hot Reload / Hot Restart**:
   - Execute `hot_reload` immediately after making changes to UI widgets or simple methods.
   - Execute `hot_restart` if fundamental logic, stateful widgets or logic affecting variables that stateful widgets use, state initialization, or `main()` was modified.
