---
name: dart-skills-lint-validation
description: |-
  Use this skill when you need to validate that AI agent skills meet the specification.
  This includes running the linter via CLI, authoring custom rules, and following the validation workflow.
---

# Validating Skills with dart_skills_lint

## Contents
- [Usage for Agents (CLI)](#usage-for-agents-cli)
- [Authoring Custom Rules](#authoring-custom-rules)
- [Workflow: Validating Skills](#workflow-validating-skills)
- [Specification Reference](#specification-reference)

## Usage for Agents (CLI)
Use the `dart_skills_lint` CLI to validate skills. Choose the appropriate workflow based on your environment:

**Note on choosing the right method:**
- **If you are a Dart developer**: The method where you add a test to your project (see the `dart-skills-lint-setup` skill) is preferred as it integrates with your existing testing workflow.
- **If you are working on a non-Dart project**: The CLI and global install (Scenario B below) is the best way to use the linter without adding a dependency to your project.

### Scenario A: The package is in your project dependencies
Use this method if you are working within a project that has `dart_skills_lint` listed in `pubspec.yaml`.
Run:
```bash
dart run dart_skills_lint:cli -d .agents/skills
```

### Scenario B: The package is activated globally
Use this method if you want to validate skills across multiple projects without adding a dependency to each one.
Run:
```bash
dart pub global run dart_skills_lint:cli -d .agents/skills
```

### Common Flags
- `-d`, `--skills-directory`: Specifies a root directory containing sub-folders of skills to validate. Can be passed multiple times.
- `-s`, `--skill`: Specifies an individual skill directory to validate directly. Can be passed multiple times.
- `-q`, `--quiet`: Hide non-error validation output.
- `-w`, `--print-warnings`: Enable printing of warning messages.
- `--fast-fail`: Halt execution immediately on the error.
- `--ignore-config`: Ignore the YAML configuration file entirely.
- `--fix`: Preview fixes for failing lints (dry run).
- `--fix-apply`: Apply fixes for failing lints.

## Authoring Custom Rules
To author custom rules, extend the `SkillRule` class and pass them to `validateSkills`.

Example:
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

Use it in your test:
```dart
final config = await ConfigParser.loadConfig();
await validateSkills(
  config: config,
  customRules: [MyCustomRule()],
);
```

## Workflow: Validating Skills
Follow this workflow to validate skills:

1. **Run the validator**: Execute the linter on your skills directory.
   ```bash
   dart run dart_skills_lint:cli -d .agents/skills
   ```
2. **Review errors**: Check the output for any errors or warnings.
3. **Fix violations**: Use `--fix-apply` or edit files manually to resolve issues.
4. **Verify**: Re-run the validator to ensure all checks pass.

### Task Progress
- [ ] Run validator
- [ ] Review errors
- [ ] Fix violations
- [ ] Verify clean run

## Specification Reference
<details>
<summary>View Skill Specification Constraints</summary>

### Directory and File Structure
- Mandatory `SKILL.md` file at the root of the skill folder.
- Directories starting with a dot `.` (e.g., `.dart_tool`) are ignored.

### Metadata (YAML Frontmatter)
- Required fields: `name` and `description`.

### Field Constraints
- **Name**: Max 64 characters, lowercase alphanumeric and hyphens only. Must match the parent directory name.
- **Description**: Max 1024 characters.
- **Compatibility**: Max 500 characters.
</details>
