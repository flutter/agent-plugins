# Dart Hooks

A package containing custom Git hooks for Dart development in this workspace. These hooks are designed to be run automatically by Antigravity or manually by developers.

## Purpose
The package provides hooks to enforce code quality and style standards before changes are finalized. Current hooks include:
- **Dart Analyze**: Runs `dart analyze` on modified files.
- **Dart Format**: Runs `dart format` on modified files.

## Configuration
Hooks are configured in a `.agents/hooks.json` file. Antigravity reads this file to determine which hooks to run.

Example `hooks.json` entry:
```json
{
  "hooks": [
    {
      "id": "dart_analyze",
      "script": "dart tool/dart_hooks/bin/agent_dart_analyze.dart"
    },
    {
      "id": "dart_format",
      "script": "dart tool/dart_hooks/bin/agent_dart_format.dart"
    }
  ]
}
```

## Hierarchical Scoping
To balance robustness and noise in large repositories, these hooks use a hierarchical scoping strategy:
- A hook will only analyze or format files that are **changed** AND are located **below the directory** containing the `.agents` folder that defined the hook.
- For example, if you have a hook defined in `tool/dart_skills_lint/.agents/hooks.json`, it will only run on modified files under `tool/dart_skills_lint/`.
- A hook defined in the repository root `.agents/hooks.json` will run on modified files anywhere in the repository.

This ensures that localized hooks do not pick up noise from unrelated modifications in other parts of the repository, while still preventing the mistake of missing relevant files.

## Manual Execution
While these scripts are typically run by Antigravity, they can be executed manually from the project root:

```bash
dart tool/dart_hooks/bin/agent_dart_analyze.dart
dart tool/dart_hooks/bin/agent_dart_format.dart
```

## Logging
Logs are written to a file in the directory where the script was run (e.g., `.agents/dart_analyze.log`).
