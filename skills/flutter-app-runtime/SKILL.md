---
name: flutter-app-runtime
description: Interacts with running Dart and Flutter applications via Dart MCP server tools (widget_inspector, dtd, get_runtime_errors, hot_reload, hot_restart) to inspect live widget trees, diagnose layout clipping and runtime errors, and execute proactive hot reloads. Use when answering questions about the active screen, inspecting widget structure, styling, or colors, checking for runtime overflows, debugging errors, or modifying UI widgets in a running app.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 28 Aug 2026 22:38:31 GMT
---
# Interacting with Live Flutter Applications

## Contents
- [Prerequisites](#prerequisites)
- [Application Discovery](#application-discovery)
- [Live UI & Hierarchy Inspection](#live-ui--hierarchy-inspection)
- [Error & Layout Diagnostics](#error--layout-diagnostics)
- [Hot Reload & Hot Restart](#hot-reload--hot-restart)
- [Task Progress Checklist](#task-progress-checklist)

## Prerequisites
Ensure the Dart and Flutter MCP server is configured and active. This skill relies on the Dart Tooling Daemon (DTD) and associated MCP tools to interact with running application instances.

## Application Discovery
Always verify active application instances before attempting live inspection or hot reloading.

1. Execute the `dtd` tool using `listDtdUris` to find available daemon URIs.
2. Use `connect` to establish a connection to the DTD.
3. Use `listConnectedApps` to discover running application instances in the current workspace.
4. **Conditional Fallback:** If no application is running, inform the user immediately. Fall back to static source code analysis for inspection questions, or proceed with standard file edits if modifying code.

## Live UI & Hierarchy Inspection
When answering questions about current screen appearance, widget styling, colors, or parent-child hierarchy, query the live widget tree.

1. Execute the `widget_inspector` tool with `command: "get_widget_tree"`.
2. **Conditional Detail Level:**
   - If inspecting the exact immediate parent widget, intermediate styling, or layout widgets (e.g., `DefaultTextStyle`, `Semantics`, `Padding`), set `summaryOnly: false`.
   - If generating high-level user-defined widget summaries, set `summaryOnly: true`.

## Error & Layout Diagnostics
When diagnosing layout issues, clipping, or errors on the current screen size, retrieve live runtime exceptions.

1. Execute the `get_runtime_errors` tool to check for active `RenderFlex` overflows or exceptions.
2. Execute the `widget_inspector` tool to evaluate constraints and render box geometry for the problematic widgets.
3. Review the errors, apply the necessary layout fixes (e.g., wrapping in `Expanded`, `Flexible`, or `SingleChildScrollView`), and trigger a hot reload.

## Hot Reload & Hot Restart
Proactively push changes to the running application to maintain visual consistency and verify fixes. 

**Conditional Reload Logic:**
- **If modifying Flutter UI widgets or standard Dart code:** Trigger the `hot_reload` tool. This preserves application state and rebuilds the widget tree.
- **If modifying foundational state, `initState()`, `main()`, global variables, or static fields:** Trigger the `hot_restart` tool. This resets the application state and re-executes initialization code.
- **If modifying native code (Kotlin, Java, Swift, Objective-C):** Inform the user that a full manual restart is required. Hot reload/restart will not apply these changes.

**Feedback Loop:**
Always execute `get_runtime_errors` immediately following a `hot_reload` or `hot_restart` to verify that zero new exceptions were introduced. If errors are present, review the diagnostics, fix the code, and reload again.

## Task Progress Checklist
Copy and use this checklist to track progress during live application modification workflows:

```markdown
- [ ] Discover and connect to active application instances via `dtd`.
- [ ] Inspect current UI state via `widget_inspector` (if applicable).
- [ ] Implement code modifications.
- [ ] Determine required reload type (Hot Reload vs. Hot Restart).
- [ ] Execute `hot_reload` or `hot_restart`.
- [ ] Run `get_runtime_errors` to verify zero new exceptions.
- [ ] Fix any newly introduced errors and repeat the reload loop.
```
