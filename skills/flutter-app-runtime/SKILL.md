---
name: flutter-app-runtime
description: Interacts with running Dart and Flutter applications via the Dart MCP server to enable hot reload, hot restart, widget inspection, and error fetching. Use when modifying UI widgets, debugging errors, inspecting running apps, or proactively hot reloading whenever changes are made to Flutter UI widgets.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 07 Aug 2026 21:16:50 GMT
---
# Managing Dart and Flutter Applications via MCP

## Contents
- [Core Capabilities](#core-capabilities)
- [Workflow: Application Discovery and Connection](#workflow-application-discovery-and-connection)
- [Workflow: UI Modification and Hot Reloading](#workflow-ui-modification-and-hot-reloading)
- [Workflow: Runtime Debugging and Error Resolution](#workflow-runtime-debugging-and-error-resolution)
- [Workflow: UI Interaction via Flutter Driver](#workflow-ui-interaction-via-flutter-driver)
- [Examples](#examples)

## Core Capabilities

The Dart and Flutter MCP server manages the underlying connection to the application's VM service via the Dart Tooling Daemon (`dtd`). Assume the server is already configured and active.

- **Hot Reload:** Proactively push visual feedback for UI widget updates and simple logic changes.
- **Hot Restart:** Reset the app state for deep non-widget changes or clean resets.
- **Widget Inspection:** Query tree structures and identify UI hierarchy names.
- **Error Fetching:** Retrieve live runtime exceptions and trace pointers live.
- **Package Management:** Search pub.dev and manage `pubspec.yaml` dependencies.

## Workflow: Application Discovery and Connection

Execute this workflow before attempting runtime operations. 

- [ ] 1. Use the `dtd` tool (with `listDtdUris` and `connect`, or `listConnectedApps`) to discover active application instances in the current workspace.
- [ ] 2. Extract the `appUri` for the target application.
- [ ] 3. Verify the connection using `dtd` or `vm_service` to ensure the `appUri` matches the project's workspace. Re-sync via `dtd` if necessary.
- [ ] 4. **Conditional:** If no app is running, inform the user immediately, but **do not stop**. Proceed with static code edits and file modifications.

## Workflow: UI Modification and Hot Reloading

Whenever modifying Flutter UI widgets or Dart code, follow this feedback loop to maintain visual consistency.

- [ ] 1. Implement the requested code changes in the target `.dart` files.
- [ ] 2. **Conditional:** 
  - If editing Flutter UI widgets or simple methods, trigger `hot_reload` across all targeted instances immediately.
  - If modifying foundational logic, state initialization, or `main()`, trigger `hot_restart` to reset state across all devices.
- [ ] 3. Run `get_runtime_errors` to verify the reload/restart did not introduce new exceptions.
- [ ] 4. If errors exist, review the stack trace, apply a fix, and repeat step 2.

## Workflow: Runtime Debugging and Error Resolution

When tasked with fixing layout issues (e.g., RenderFlex overflow) or runtime exceptions, use this diagnostic loop.

- [ ] 1. Execute `get_runtime_errors` to fetch live exceptions from the running application.
- [ ] 2. Identify the failing widget or logic block from the stack trace.
- [ ] 3. Execute `widget_inspector` to query the live UI tree structure and understand the layout constraints causing the issue.
- [ ] 4. Apply the code fix to the relevant Dart file.
- [ ] 5. Trigger `hot_reload`.
- [ ] 6. Execute `get_runtime_errors` again to confirm the error is resolved.

## Workflow: UI Interaction via Flutter Driver

To drive a running Flutter app (take screenshots, tap buttons, enter text), the app must be instrumented with `flutter_driver`.

- [ ] 1. Verify `flutter_driver` is in `pubspec.yaml`. If not, run `flutter pub add flutter_driver --sdk=flutter`.
- [ ] 2. Ensure the app's `main()` function conditionally enables the driver extension:
  ```dart
  import 'package:flutter_driver/driver_extension.dart';
  
  void main() {
    if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
      enableFlutterDriverExtension();
    }
    runApp(const MyApp());
  }
  ```
- [ ] 3. Instruct the user to launch the app with: `flutter run -d <device-id> --dart-define=ENABLE_FLUTTER_DRIVER=true`.
- [ ] 4. Use the `dtd` tool to discover the app and `flutter_driver_command` to drive its UI.
- [ ] 5. **Conditional (Web Targets):** If the target is a web build, do not use `flutter_driver` finder-based commands (screenshots/taps). Instead, rely on a browser-driving MCP. Ensure the user runs `flutter run -d web-server` so DTD connects properly to the driven browser.

## Examples

### Scenario: Adding a Package and Scaffolding UI

**Input:** "Add a line chart to map user scores over time."

**Execution Steps:**
1. Execute `pub_dev_search` with query "line chart".
2. Identify `fl_chart` as the optimal package.
3. Add dependency to `pubspec.yaml`.
4. Generate the widget code using `fl_chart` boilerplate.
5. Insert the widget into the target UI file.
6. Trigger `hot_reload`.
7. Run `get_runtime_errors` to ensure no missing constraints or syntax errors exist.

### Scenario: Proactive Hot Reloading

**Input:** "Change the background color to red"

**Execution Steps:**
1. Locate the target background widget (e.g., `Scaffold`, `Container`) in the Dart code.
2. Update `backgroundColor: Colors.red` or `color: Colors.red`.
3. Save the file.
4. Immediately execute `hot_reload` using the active `appUri`.
5. Confirm successful reload via tool output.
