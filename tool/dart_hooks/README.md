# Dart Hooks

A package containing custom Git hooks for Dart development in this workspace. These hooks are designed to be run automatically by Antigravity or manually by developers.

## Purpose
The package provides hooks to enforce code quality and style standards before changes are finalized. Current hooks include:
- **Dart Analyze**: Runs `dart analyze` on modified files.
- **Dart Format**: Runs `dart format` on modified files.

## Configuration

### Triggers (`hooks.json`)
Hooks are configured in a `.agents/hooks.json` file. Antigravity reads this file to determine which hook scripts to execute.

Example `hooks.json` entry:
```json
{
  "dart-format": {
    "Stop": [
      {
        "type": "command",
        "command": "../tool/dart_hooks/bin/agent_dart_format.dart --source hook --log",
        "timeout": 30
      }
    ]
  },
  "dart-analyze": {
    "Stop": [
      {
        "type": "command",
        "command": "../tool/dart_hooks/bin/agent_dart_analyze.dart --source hook --log",
        "timeout": 90
      }
    ]
  }
}
```

### Activation (`dart_hooks.yaml`)
To prevent hooks from running unnecessarily in sub-packages, hooks are **disabled by default**.

To enable hooks, you must create a `dart_hooks.yaml` file in the package/project root (the parent directory of the `.agents` folder where the hook runs). In this file, specify the hook's script/executable filename as the key and set it to `true`.

Example `dart_hooks.yaml` to enable both formatting and analysis:
```yaml
agent_dart_format.dart: true
agent_dart_analyze.dart: true
```

If `dart_hooks.yaml` is missing or does not contain the key for a specific hook, that hook will be skipped and exit silently.

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
