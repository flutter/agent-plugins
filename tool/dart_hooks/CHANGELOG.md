# Changelog

## 0.1.0

- **Breaking Change**: Hooks are now disabled by default and require a `dart_hooks.yaml` file in the package/project root to be executed.
- Updated YAML configuration keys to use hook class names (`DartAnalyzeHook`, `DartFormatHook`) instead of script filenames.
- Unsupported or unconfigured hooks now exit silently.

## 0.0.1

- Initial version with dart analyze and dart format hooks.
