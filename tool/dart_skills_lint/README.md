# dart_skills_lint

A static analysis linter for Agent Skills to ensure they meet the specification in presubmit checks. This project is a Dart package and can be run as a CLI tool to validate your skills directory before committing.

## Table of Contents
- [Overview](#overview)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Specification Validation](#specification-validation)
- [Recipes](#recipes)
- [Support](#support)
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

There are three ways to interact with `dart_skills_lint`:

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
- `--fix`: Apply fixes for failing lints (matches `prettier --write` / `ruff --fix` / `eslint --fix`).
- `--dry-run`: When combined with `--fix`, prints the proposed diff without writing.
- `--fix-apply`: *Deprecated.* Alias for `--fix`; prints a deprecation notice on use.

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

## Recipes

Drop-in snippets for the two most common ways to wire `dart_skills_lint`
into a project's quality gates. Each recipe is exercised by
[`test/recipe_drift_test.dart`](test/recipe_drift_test.dart), so if a
flag here goes stale, CI fails.

### Recipe: GitHub Actions

Save the following as `.github/workflows/lint-skills.yml`. It runs on
every push and PR, installs `dart_skills_lint` globally on the runner,
and validates every skill under `.claude/skills/`. Adjust the path to
match where your skills live.

```yaml
# .github/workflows/lint-skills.yml
name: Lint Agent Skills
on:
  push:
    branches: [main]
  pull_request:

permissions: read-all

jobs:
  lint-skills:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate dart_skills_lint
      - run: dart pub global run dart_skills_lint --skills-directory ./.claude/skills
```

To validate a single skill directory instead, swap the last step:

```yaml
      - run: dart pub global run dart_skills_lint --skill ./.claude/skills/my-skill
```

### Recipe: Dart-native pre-commit hook

A pre-commit hook that calls into the linter directly — no Husky, no
Python `pre-commit` framework, just Dart and the existing
`dart pub global` tooling.

Activate the linter once per machine:

```bash
dart pub global activate dart_skills_lint
```

Then install the hook into the repository (run from the repo root):

```bash
cat > .git/hooks/pre-commit <<'HOOK'
#!/bin/sh
set -e
# Lint every skill under .claude/skills before each commit.
# Add --skill arguments for other locations as needed.
exec dart pub global run dart_skills_lint --skills-directory ./.claude/skills --quiet
HOOK
chmod +x .git/hooks/pre-commit
```

The hook exits non-zero on lint failure, blocking the commit. To
auto-apply fixable lints inside the hook, append `--fix` (see DT2 for
the new `--fix` / `--dry-run` semantics).

## Support

- **Bug report or feature request:** open an issue at
  <https://github.com/flutter/skills/issues>. Please include the
  output of `dart pub global run dart_skills_lint --help` and the
  failing `SKILL.md` (or a minimal reproducer) so the maintainers
  can replay it locally.
- **Questions, ideas, "is this the right rule for me?":** start a
  thread in
  [GitHub Discussions](https://github.com/flutter/skills/discussions).
  Discussions is enabled on the repo; if you land on a 404 the feature
  has been temporarily disabled — open an issue in the meantime and
  flag the discussions outage there.
- **Security issues:** do **not** file a public issue. Email the
  maintainers via the address listed in the repository's
  `SECURITY.md` (or in `AUTHORS` if `SECURITY.md` is not present).

## Contributing

Contributions are welcome! Please ensure that any PRs pass the linter themselves and align with the `documentation/knowledge/SPECIFICATION.md`.

