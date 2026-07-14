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

1.  **Formatting**: Run `dart format .` to format files, or `dart format --output=none --set-exit-if-changed .` to check without modifying. Ensure all files are formatted correctly.
2.  **Analysis**: Run `dart analyze --fatal-infos` and ensure there are zero issues (including info-level issues).
3.  **Metrics/Linter**: Run `dart run dart_code_linter:metrics analyze lib` and ensure there are zero issues. This checks for cyclomatic complexity and custom rules like file naming and redundant async.
4.  **Tests**: Run `dart test` and ensure all tests pass successfully.
5.  **Skill Validation**: If any skill files were modified, run `dart run dart_skills_lint -d .agents/skills` to ensure they are valid.
6.  **Changelog**: Ensure `CHANGELOG.md` is updated if the task includes user-facing features, bug fixes, or behavioral changes. Audit all entries against the *previously released version* (do not document changes to intermediate PR development code or new unreleased APIs as breaking changes).
7.  **Temporal Words**: Ensure that code and code comments contain no relative temporal terms (e.g., 'now', 'currently', 'new', 'old', 'existing behavior').

## 🚦 Completion Checklist

- [ ] Code is formatted (`dart format .` or checked with `--output=none --set-exit-if-changed .`).
- [ ] Analysis is clean (`dart analyze --fatal-infos`).
- [ ] Metrics/Linter are clean (`dart run dart_code_linter:metrics analyze lib`).
- [ ] Tests are passing (`dart test`).
- [ ] Skills validated if modified (`dart run dart_skills_lint -d .agents/skills`).
- [ ] `CHANGELOG.md` updated and audited against the previously released version (no intermediate or unreleased breaking changes listed).
- [ ] Verified that code and code comments contain no relative temporal terms (e.g., 'now', 'currently', 'new', 'old', 'existing behavior').
- [ ] Documentation is updated.
