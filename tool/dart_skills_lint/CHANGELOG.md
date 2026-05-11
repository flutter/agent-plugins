## 0.3.0

- Exposed `ConfigParser.loadConfig()` API to load configuration files programmatically.
- Supported tilde expansion (`~/`) in configuration file paths.
- Refactored fallback logic for skills directories to `validateSkillsInternal`.
- Added tests for path utilities and configuration loading.
- Updated documentation to clarify CLI vs. Dart Test usage.

## 0.2.0

- Refactored validator to a pluggable rule-based architecture.
- Added support for custom rules via `SkillRule`.
- Added runtime assertion for duplicate rule names.
- Added warning when a rule emits an error with severity different from its definition.
- Updated `README.md` with custom rules documentation.
- **Breaking Change**: Enabling a rule via CLI flag now sets its severity to `error` instead of `warning`.

## 0.1.0

- Initial version.
