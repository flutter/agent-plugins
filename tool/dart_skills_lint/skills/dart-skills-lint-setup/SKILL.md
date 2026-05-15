---
name: dart-skills-lint-setup
description: |-
  Use this skill when you need to set up validation for AI agent skills in a Dart project for the first time.
  This includes adding dependencies, configuring the linter, setting up tests, and creating a CI workflow.
---

# Setting up Skill Validation with dart_skills_lint

## Contents
- [Setup for Dart Developers](#setup-for-dart-developers)
- [Initial Integration in a Repository](#initial-integration-in-a-repository)
- [GitHub Workflow Setup](#github-workflow-setup)

## Setup for Dart Developers
Setup validation in your Dart project:

1. Add `dart_skills_lint` to your `pubspec.yaml` as a `dev_dependency`. If it is published to pub.dev:
   ```yaml
   dev_dependencies:
     dart_skills_lint: ^0.2.0
   ```
   If it is a local package or hosted on Git, use a path or git dependency:
   ```yaml
   dev_dependencies:
     dart_skills_lint:
       git:
         url: https://github.com/flutter/skills.git
         path: tool/dart_skills_lint
   ```
   **Note:** The test example below also requires `package:logging` and `package:test` to be added to your `dev_dependencies` if they are not already present.

2. Integrate the linter into your automated tests by importing the package and calling `validateSkills`. This ensures your skills are automatically validated whenever you run `dart test`.

   Example `test/lint_skills_test.dart`:
   ```dart
   import 'dart:async';
   import 'package:dart_skills_lint/dart_skills_lint.dart';
   import 'package:logging/logging.dart';
   import 'package:test/test.dart';

   void main() {
     test('Run skills linter', () async {
       final Level oldLevel = Logger.root.level;
       Logger.root.level = Level.ALL;
       final StreamSubscription<LogRecord> subscription =
           Logger.root.onRecord.listen((record) => print(record.message));

       try {
         // Load configuration from the default file (dart_skills_lint.yaml)
         final config = await ConfigParser.loadConfig();

         final isValid = await validateSkills(
           config: config,
         );
         expect(isValid, isTrue, reason: 'Skills validation failed. See above for details.');
       } finally {
         Logger.root.level = oldLevel;
         await subscription.cancel();
       }
     });
   }
   ```

3. **Recommended**: Create a configuration file `dart_skills_lint.yaml` in the root of your project to centralize your rules and directory settings. This ensures both the CLI and your automated tests use the same configuration.
   **Note:** If you use `validateSkills` directly in tests, you can load the `dart_skills_lint.yaml` file using `ConfigParser.loadConfig()` and pass it to `validateSkills` to share the same configuration as the CLI.
   ```yaml
   dart_skills_lint:
     rules:
       check-relative-paths: error
       check-trailing-whitespace: error
     directories:
       - path: ".agents/skills"
   ```
   **Note:** The following rules are enabled by default and do not need to be listed unless you want to change their severity or disable them: `check-absolute-paths`, `valid-yaml-metadata`, `invalid-skill-name`, `description-too-long`.

## Initial Integration in a Repository
When adding `dart_skills_lint` to a repository for the first time, follow these best practices:
- **Isolate the dependency**: Add it to a specific package that handles tooling or tests (e.g., `tool/pubspec.yaml`) rather than the root.
- **Keep hashes in sync**: If you must add it to multiple `pubspec.yaml` files (e.g., root and a tool package), ensure the `ref` (commit hash) is identical to avoid resolution conflicts.
- **Generating a Baseline**: If integrating into a repository with existing skills that have legacy errors, use the baseline feature:
  ```bash
  dart run dart_skills_lint:cli --skills-directory=.agents/skills --generate-baseline
  ```

## GitHub Workflow Setup
To enforce skill validation in CI, add a GitHub workflow file (e.g., `.github/workflows/dart_skills_validation.yaml`):

```yaml
name: dart_skills_validation
permissions: read-all

on:
  pull_request:
    paths:
      - '.agents/skills/**'
      - 'tool/**' # Adjust to your tool package path
  push:
    branches: [ main ]
    paths:
      - '.agents/skills/**'
      - 'tool/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: dart-lang/setup-dart@v1
    - name: Install dependencies
      run: dart pub get
      working-directory: tool # Adjust to your tool package path
    - name: Run skills validation
      run: dart test
      working-directory: tool # Adjust to your tool package path
```
