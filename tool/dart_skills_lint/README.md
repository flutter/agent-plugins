# dart_skills_lint

A static analysis linter for Agent Skills to ensure they meet the specification in presubmit checks. This project is a Dart package and can be run as a CLI tool to validate your skills directory before committing.

## Table of Contents
- [Overview](#overview)
- [Installation](#installation)
- [Usage](#usage)
  - [Rule Precedence](#rule-precedence)
- [Specification Validation](#specification-validation)
- [Recipes](#recipes)
- [Contributing](#contributing)

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

`dart_skills_lint` runs as a command-line tool, configured by flags or by
a `dart_skills_lint.yaml` file. The CLI is the user-facing surface; it
also has a programmatic API for contributors who need to embed the
linter in their own test suite — see
[`CONTRIBUTING.md`](CONTRIBUTING.md#embedding-the-linter-in-tests).

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
- `--fix`: Write fixes for failing lints to disk.
- `--dry-run`: When combined with `--fix`, prints the proposed diff without writing.
- `--fix-apply`: *Deprecated* alias for `--fix`. Prints a deprecation notice on use.

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

### 3. Custom Rules

Custom rule authoring lives in the
[`dart-skills-lint-validation`](skills/dart-skills-lint-validation/SKILL.md)
skill — that skill walks through extending `SkillRule` and passing the
rule into the linter.

## Specification Validation

The linter checks each skill against the spec at
[`documentation/knowledge/SPECIFICATION.md`](documentation/knowledge/SPECIFICATION.md).
For the full list of built-in rules — default severities, exact
diagnostic shapes, auto-fix behavior, and how to disable each — see
[`RULES.md`](RULES.md).

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
auto-apply fixable lints inside the hook, append `--fix` to the linter
invocation.

### Recipe: have an agent set it up for you

If you're using Claude Code, Gemini, or another agent that can read
repository-local skills, paste the following prompt to have the agent
install and validate `dart_skills_lint` for you. The agent will
follow the
[`dart-skills-lint-setup`](skills/dart-skills-lint-setup/SKILL.md)
skill for first-time wiring, then the
[`dart-skills-lint-validation`](skills/dart-skills-lint-validation/SKILL.md)
skill to run the linter and resolve any failures.

> Set up dart_skills_lint in this project. Use the skill at
> `tool/dart_skills_lint/skills/dart-skills-lint-setup/SKILL.md`
> to add it as a dev_dependency, create the configuration file,
> and wire it into CI. Then use the skill at
> `tool/dart_skills_lint/skills/dart-skills-lint-validation/SKILL.md`
> to run the linter and resolve any failures.

## Contributing

Contributions are welcome! Please ensure that any PRs pass the linter themselves and align with the `documentation/knowledge/SPECIFICATION.md`.

