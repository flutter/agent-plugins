---
name: definition-of-done
description: Mandatory checks to run before completing any task that touches md files or dart code in this repository.
metadata:
  internal: true
---

# Definition of Done

Use this skill to ensure that all work meets the repository standards before declaring a task complete or requesting review.

## 📋 Mandatory Verification Steps

Before stating that a task is complete, you MUST execute and pass the following checks:

1.  **Format**: Run `dart format .` to format files, or `dart format --output=none --set-exit-if-changed .` to check without modifying. Ensure all files are formatted correctly.
2.  **Analysis**: Run `dart analyze --fatal-infos` and ensure there are zero issues (including info-level issues).
3.  **Metrics**: Run `dart run cognitive_complexity --fail-threshold <N> lib test`, where `<N>` is the `--fail-threshold` value configured in `.github/workflows/dart_skills_lint_workflow.yaml`, and ensure there are zero issues. This checks for cognitive complexity.
4.  **Tests**: Run `dart test` and ensure all tests pass successfully.
5.  **Skills**: If any skill files were modified, run `dart run dart_skills_lint -d .agents/skills` to ensure they are valid.
6.  **Changelog**: If the task introduces user-facing CLI flags, package API changes, bug fixes, or user-facing behavioral changes, update `CHANGELOG.md`.
    - **Do NOT log internal chores**: Do not add entries for internal CI workflows, dev dependency updates/migrations, test refactoring, or repository infrastructure scripts.
    - **Explicit N/A**: If the task is internal-only, leave `CHANGELOG.md` untouched and output `[x] Changelog: (N/A) <reason>`.
    - Audit all entries against the *previously released version* (do not document changes to intermediate PR development code or new unreleased APIs as breaking changes).
7.  **Temporal**: Ensure that code and code comments contain no relative temporal terms (e.g., 'now', 'currently', 'new', 'old', 'existing behavior').
8.  **Documentation**: Ensure that any relevant documentation is updated.

## 🚦 Output Formatting

You MUST include a text list of all mandatory verification steps in your final response to the user. Use the exact following format:
- Use `[x] <Identifier>: <Explanation>` if the step was completed.
- Use `[ ] <Identifier>: <Skipped explanation>` if the step was skipped or not applicable.

CRITICAL: Do not just copy the full step description text. You MUST use the exact bolded Identifier from the Mandatory Verification Steps list above, followed by a colon and your short explanation.

Examples:
- `[x] Format: dart format success.`
- `[x] Analysis: Static clean (0 issues, dart analyze --fatal-infos).`
- `[ ] Skills: Skipped because dart_skills_lint is not installed.`
- `[x] Changelog: (N/A) Not necessary since we're updating internal eval fixtures.`
- `[x] Temporal: no added words.`
