---
name: dart-skills-lint-integration
description: >
  How to integrate, update, and configure the dart_skills_lint validation tool
  within a repository. Make sure to use this skill whenever the user asks to
  update dart_skills_lint, configure skills validation tests, fix skills linter
  dependency drifts, verify repository state before editing, optimize
  lint rules execution, or draft pull request submission commands.
---

# Integrating and Configuring dart_skills_lint

Use this skill to verify repository state, update pinned references, manage
centralized configurations, implement efficient validation test suites, and
output clean pull request commands for `dart_skills_lint`.

## Pre-Flight Repository Verification

Before initiating any modifications or executing dependency updates, ensure
the repository is in a clean, safe state:

1. Run `git status` to confirm the repository has no active work in progress.
2. If clean, check out the primary tracking branch (e.g., `main` or `master`).
3. Fast-forward update from the remote owned by the authoritative org.
4. If post-checkout hooks report engine updates, run necessary sync utilities
   (such as `gclient sync`) to guarantee consistency before proceeding.

## Dependency Management Workflow

When updating `dart_skills_lint` within a workspace or standalone project:

1. Locate the target `pubspec.yaml` defining the dependency.
2. Update the pinned Git commit reference directly in the `ref` field.
3. Synchronize the lockfile natively using the environment's package manager.

### Example: Pinned Git Dependency
```yaml
  dart_skills_lint:
    git:
      url: https://github.com/flutter/skills
      path: tool/dart_skills_lint
      ref: e4497873950727ee781fa411c1a2f624b1ec50c6
```

## Centralized Configuration Schema

Configure rules and target paths globally via `dart_skills_lint.yaml`. Always
define paths relative to the repository root execution context. Ensure that
rules at the directory level are properly oriented within a nested `rules` map.

### Standard Schema Implementation
```yaml
dart_skills_lint:
  rules:
    check-relative-paths: error
    check-absolute-paths: error
    check-trailing-whitespace: error
  directories:
    - path: ".agents/skills"
```

## Validation Test Implementation Patterns

To centralize rule management, load `Configuration` dynamically via
`ConfigParser.loadConfig` and supply it to `validateSkills`.

If test suites execute under simple environments with stable execution roots,
omit the `skillDirPaths` parameter entirely to natively inherit target paths
defined within the YAML configuration.

**Absolute Isolation Pattern**: If test harnesses manipulate runtime
execution working directories (such as CI frameworks running tests inside
sub-package folders), guarantee path resilience by resolving configuration
files absolutely using dynamic directory contexts (e.g., `repoRoot.path`).
Explicitly inject absolute `skillDirPaths` targeting; global rules defined
under `rules:` map unconditionally regardless of explicit target path usage.

When updating an existing validation block, explicitly audit any adjacent
`TODO` or tracker comments. If the comment describes refactoring config
loading or references issues resolved by this update, delete the comment
block entirely.

### Core Validation Workflow
```dart
import 'package:dart_skills_lint/dart_skills_lint.dart';

const String _configFileName = 'dart_skills_lint.yaml';

test('Validate Repository Skills', () async {
  // Use dynamic absolute resolution references to guarantee CI stability
  final Configuration config = await ConfigParser.loadConfig(
    path: path.join(repoRoot.path, 'path', 'to', _configFileName),
  );
  final bool isValid = await validateSkills(
    skillDirPaths: [skillsDirectory], // Explicit absolute targeting
    config: config,
  );
  expect(isValid, isTrue);
});
```

### Eliminating Duplicate Overhead in Secondary Blocks

Secondary test blocks enforcing specialized custom rules without loading the
shared configuration must supply target paths explicitly. To prevent
duplicate execution overhead, explicitly map all default registered
built-in rules to `AnalysisSeverity.disabled`.

```dart
test('Custom Rule Validation', () async {
  final bool isValid = await validateSkills(
    skillDirPaths: ['path/to/skills'],
    customRules: [MyCustomRule()],
    resolvedRules: {
      'check-absolute-paths': AnalysisSeverity.disabled,
      'check-relative-paths': AnalysisSeverity.disabled,
      'check-trailing-whitespace': AnalysisSeverity.disabled,
      'description-too-long': AnalysisSeverity.disabled,
      'disallowed-field': AnalysisSeverity.disabled,
      'invalid-skill-name': AnalysisSeverity.disabled,
      'valid-yaml-metadata': AnalysisSeverity.disabled,
    },
  );
  expect(isValid, isTrue);
});
```

## Expected Final Output: Pull Request Creation Command

Conclude tasks by staging verified work on a descriptive local branch
(suffixed with the ISO 8601 date format), committing the changes with
a concise, standard commit message, and outputting a fully executable
`gh pr create` command.

### Discovering and Populating the Pull Request Template

To ensure formatting compliance, always look up the target repository's native
pull request template before generating the submission body:

1. **Locate Template**: Search for template files within `.github/`,
   `.github/PULL_REQUEST_TEMPLATE/`, or the project root. Common filenames
   include `PULL_REQUEST_TEMPLATE.md` or `pull_request_template.md`.
2. **Extract Structure**: Read the discovered file to identify required
   markdown headers, description placeholders, issue citation rules, and
   checklists.
3. **Populate Content**: Replace placeholders with clear context summarizing
   the dependency rolls, configurations created, and rule blocks optimized.
   Check all applicable verification boxes (`[x]`).
4. **Fallback**: If no native template exists, construct a clean submission
   body containing a brief summary of modifications, relevant issue links,
   and static analysis/testing outcomes.

### Output Command Structure
```bash
gh pr create \
  --title "Update dart_skills_lint dependency to <hash> and centralize config" \
  --body "<populated repository template content>"
```

## Tips for the Flutter Repository (`flutter/flutter`)

When operating directly within the main Flutter codebase:

* **Package Resolution**: Run `bin/flutter pub get` at the repository root
  instead of `dart pub get` to prevent SDK version mismatch errors.
* **Checksum Integrity**: Updating dependencies natively breaks autogenerated
  pubspec checksum hashes. Always recalculate and update stale hashes by
  running `bin/flutter update-packages --update-hashes`.
* **Test Orchestration**: Run repository unit tests from the root context:
  `bin/flutter test dev/tools/test/validate_skills_test.dart`.
* **Verification**: Ensure zero static analysis warnings using `dart analyze
  --fatal-infos` and format all source code cleanly with `dart format`.
