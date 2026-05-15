# dart_skills_lint

A static analysis linter for Agent Skills to ensure they meet the specification in presubmit checks. This project is a Dart package and can be run as a CLI tool to validate your skills directory before committing.

## Table of Contents
- [Overview](#overview)
- [Installation](#installation)
- [Usage](#usage)
  - [CLI vs Dart Test](#cli-vs-dart-test)
  - [Rule Precedence](#rule-precedence)
- [Configuration](#configuration)
- [Specification Validation](#specification-validation)
- [Best Practices](#best-practices)

## Overview

An **Agent Skill** is a portable, self-contained directory that extends an AI agent's capabilities. Pre-submit linting ensures that your skill definitions are valid and ready for consumption by agent platforms.

`dart_skills_lint` validates:
- Presence of mandatory `SKILL.md` file.
- YAML frontmatter constraints (naming, length, etc.).
- Directory structure (flat, no deep nesting).
- Relative path integrity.

For a full definition of the skill standard, see the [Agent Skills Specification](documentation/knowledge/SPECIFICATION.md).

## Installation

Add `dart_skills_lint` to your Dart project or activate it globally.

### 1. As a project dependency
Add it to your `pubspec.yaml` (once published on pub.dev):
```yaml
dev_dependencies:
  dart_skills_lint: ^0.2.0
```
Then run:
```bash
dart pub get
```

### 2. Globally activated
If you want to use it across multiple projects without adding it to each `pubspec.yaml`:
```bash
dart pub global activate dart_skills_lint
```

## Usage

There are three ways to interact with `dart_skills_lint`.

### CLI vs Dart Test

Depending on your workflow, you should choose the appropriate interaction mode:

*   **Use the CLI when:**
    *   **Ad-hoc Validation**: You want to quickly check a specific skill you are working on without running the entire test suite.
    *   **Baseline Generation**: You are integrating the tool into a legacy repo and need to generate an ignore file (`--generate-baseline`).
    *   **Automated Fixes**: You want to preview or apply fixes (`--fix`, `--fix-apply`) directly to the files.
    *   **Pre-commit Hooks**: You want a fast, isolated check in a Git pre-commit hook.
*   **Use Dart Test when:**
    *   **CI/CD Integration**: You want to guarantee that no invalid skills are merged by failing the build alongside unit tests.
    *   **Programmatic Configuration**: You need to inject custom rules or dynamic configurations that are hard to express in static YAML.
    *   **Ecosystem Consistency**: You want developers to rely on the familiar `dart test` command rather than learning a new tool invocation.

---

### 1. As a Command Line Tool with Arguments
Run the linter against your skills or root skills directories by passing arguments.

```bash
dart run dart_skills_lint --skills-directory ./path/to/skills-root
```

Multiple root directories can be specified:
```bash
dart run dart_skills_lint --skills-directory ./path/to/root-a --skills-directory ./path/to/root-b
```

Validate Individual Skills directly using `--skill` or `-s`:
```bash
dart run dart_skills_lint --skill ./path/to/my-single-skill
```

If no directory is specified, it automatically checks `.claude/skills` and `.agents/skills` relative to your workspace root.

### Flags
- `-d`, `--skills-directory`: Specifies a root directory containing sub-folders of skills to validate. Can be passed multiple times. Can use home tilde expansion (ex: `~/.agents/skills`).
- `-s`, `--skill`: Specifies an individual skill directory to validate directly. Can be passed multiple times.
- `-q`, `--quiet`: Hide non-error validation output.
- `-w`, `--print-warnings`: Enable printing of warning messages.
- `--fast-fail`: Halt execution immediately on the error.
- `--ignore-config`: Ignore the YAML configuration file entirely.
- `--[no-]check-trailing-whitespace`: Enable/disable checking for trailing whitespace. (Disabled by default).
- `--fix`: Preview fixes for failing lints (dry run).
- `--fix-apply`: Apply fixes for failing lints.

### 2. As a Command Line Tool with a YAML Configuration File
You can configure the linter using a configuration file (defaulting to `dart_skills_lint.yaml` in the current directory).

Create `dart_skills_lint.yaml` in the root of your repository:

```yaml
# dart_skills_lint.yaml
dart_skills_lint:
  rules:
    check-relative-paths: error
    check-absolute-paths: error
  directories:
    - path: "~/.agents/skills"
      ignore_file: "~/.agents/skills/ignore.json"
```

Then you can simply run:
```bash
dart run dart_skills_lint
```

### Rule Precedence

When resolving which severity to apply for a rule, `dart_skills_lint` evaluates settings in the following order of precedence (highest to lowest):

1. **CLI Flags / API Overrides**: Explicit flags passed to the CLI (e.g., `--check-trailing-whitespace`) or rules passed to the `validateSkills` API via `resolvedRules`.
2. **Path-Specific Config**: Rules defined under `directories:` in `dart_skills_lint.yaml` for a matching path.
3. **Global Config**: Rules defined under the top-level `rules:` in `dart_skills_lint.yaml`.
4. **Defaults**: The hardcoded default severity for each rule.

This ensures that you can always override configuration file settings for a specific run by using CLI flags.

---

### 3. As Dart Test Code
You can integrate the linter into your automated tests by importing the package and calling `validateSkills`. This allows you to enforce skill validity as part of your standard test suite.

Example `test/lint_skills_test.dart`:
```dart
import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:test/test.dart';

void main() {
  test('Run skills linter', () async {
    final config = Configuration(
      directoryConfigs: [
        DirectoryConfig(
          path: '../../skills',
          rules: {},
          ignoreFile: '.agents/skills/flutter_skills_ignore.json',
        ),
      ],
    );

    await validateSkills(
      skillDirPaths: ['../../skills'],
      resolvedRules: {
        'check-relative-paths': AnalysisSeverity.error,
        'check-absolute-paths': AnalysisSeverity.error,
      },
      config: config,
    );
  });
}
```

You can also use `Validator` and `ValidationResult` directly if you need to inspect the errors programmatically.

### Custom Rules

You can author custom rules by extending the `SkillRule` class and passing them to `validateSkills` or the `Validator` constructor.

Example custom rule:
```dart
import 'package:dart_skills_lint/dart_skills_lint.dart';

class MyCustomRule extends SkillRule {
  @override
  final String name = 'my-custom-rule';

  @override
  final AnalysisSeverity severity = AnalysisSeverity.warning;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];
    final yaml = context.parsedYaml;
    if (yaml == null) return errors;

    if (yaml['metadata']?['deprecated'] == true) {
      errors.add(ValidationError(
        ruleId: name,
        severity: severity,
        file: 'SKILL.md',
        message: 'This skill is marked as deprecated.',
      ));
    }
    return errors;
  }
}
```

Then use it in your test:
```dart
    await validateSkills(
      skillDirPaths: ['../../skills'],
      customRules: [MyCustomRule()],
    );
```

## Specification Validation

The linter checks against the criteria defined in `documentation/knowledge/SPECIFICATION.md` (Section 5.1). Key checks include:

### 1. Directory and File Structure
- Path existence and directory verification.
- Mandatory `SKILL.md` file at the root.
- Directories starting with a dot `.` (e.g., `.dart_tool`) are ignored when scanning for skills.

### 2. Metadata (YAML Frontmatter)
- Valid YAML syntax.
- Allowed fields: `name`, `description`, `license`, `allowed-tools`, `metadata`, `compatibility`, `category`, `tags`, `version`, `eval_task`.
- Required fields: `name` and `description`.

### 3. Field Specific Constraints
- **Skill Name (`name`)**: Max 64 characters, lowercase alphanumeric and hyphens only, no leading/trailing/consecutive hyphens. **Must match the parent directory name.**
- **Description (`description`)**: Max 1024 characters.
- **Compatibility (`compatibility`)**: Max 500 characters.

### 4. Content Constraints
- **Trailing Whitespace**: Lines in `SKILL.md` should not have trailing whitespace. Exactly 2 spaces at the end of a line are allowed to support Markdown hard line breaks, per the [CommonMark Spec](https://spec.commonmark.org/0.31.2/#hard-line-breaks).
- **Path Constraints**: Checks that **inline** Markdown links do not use absolute paths to enforce portability. Can optionally be configured to check that relative paths point to valid, existing files (disabled by default). *Note: This rule only supports inline Markdown links and does not detect HTML or reference-style links.*

## Contributing

Contributions are welcome! Please ensure that any PRs pass the linter themselves and align with the `documentation/knowledge/SPECIFICATION.md`.

