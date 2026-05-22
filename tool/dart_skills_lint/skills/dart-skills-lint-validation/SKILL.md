---
name: dart-skills-lint-validation
description: |-
  Use this skill when you need to validate AI agent skills with dart_skills_lint — running the linter, interpreting failures, fixing violations, and authoring custom rules.
---

# Validating Skills with dart_skills_lint

This skill covers **day-to-day use**: running the linter, walking
through a failing run, and writing a custom rule when defaults
aren't enough. For first-time wiring (adding the dep, creating the
config file, generating a baseline) see
[`dart-skills-lint-setup`](../dart-skills-lint-setup/SKILL.md). The
full rule reference (default severities, diagnostic shapes,
fixability) lives in [`RULES.md`](../../RULES.md).

## Running the linter

If `dart_skills_lint` is in `pubspec.yaml`:

```bash
dart run dart_skills_lint:cli -d .agents/skills
```

If it's installed globally with `dart pub global activate`:

```bash
dart pub global run dart_skills_lint:cli -d .agents/skills
```

Run `dart run dart_skills_lint:cli --help` for the full flag list
(skip the inline duplicate so it never goes stale).

## Workflow for a failing run

1. **Run the validator.**
2. **Read the errors.** Each diagnostic names the rule that fired,
   the offending value, and a suggested fix when one applies.
3. **Fix the violations.** For fixable rules
   (`check-absolute-paths`, `check-trailing-whitespace`,
   `invalid-skill-name`), pass `--fix` to write the corrections
   to disk; add `--dry-run` to preview the diff first.
4. **Re-run** to confirm the run is clean.

### Task progress

- [ ] Run validator
- [ ] Read errors
- [ ] Fix violations (manual or `--fix` / `--fix --dry-run`)
- [ ] Verify clean run

## Authoring a custom rule

Extend `SkillRule` and pass the rule into `validateSkills`:

```dart
import 'package:dart_skills_lint/dart_skills_lint.dart';

class DeprecatedSkillRule extends SkillRule {
  @override
  final String name = 'deprecated-skill';

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

Wire it up in a Dart test:

```dart
import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:test/test.dart';

void main() {
  test('skills pass with deprecated-skill custom rule', () async {
    final config = await ConfigParser.loadConfig();
    await validateSkills(
      config: config,
      customRules: [DeprecatedSkillRule()],
    );
  });
}
```

## Related

- [`dart-skills-lint-setup`](../dart-skills-lint-setup/SKILL.md) —
  first-time wiring.
- [`RULES.md`](../../RULES.md) — canonical rule reference.
- [`README.md`](../../README.md) — installation, configuration,
  integration recipes.
