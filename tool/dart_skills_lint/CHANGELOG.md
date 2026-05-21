## 0.3.0

The "earn 1.0.0 with real users" prerelease. Same rule semantics as 0.2.0
under defaults; everything else is paperwork, diagnostics polish, and
distribution prep. See `CONTRIBUTING.md` for the SemVer rule-stability
policy that governs every release from here on.

### Package metadata

- Bumped `pubspec.yaml` description to a 50–180 char band, added
  pub.dev topics (`agent-skills`, `linter`, `static-analysis`, `cli`,
  `validation`) and an `issue_tracker` field. Targets pana score ≥ 150.

### CLI

- `--fix` now applies fixes by default (matches `prettier --write`,
  `eslint --fix`, `ruff --fix`). Use `--fix --dry-run` to preview.
  The legacy `--fix-apply` flag still works as an alias but emits a
  deprecation notice on stderr and is hidden from `--help`.
- First run with no flags and no `.claude/skills` / `.agents/skills`
  directory now prints a champion-tier onboarding guide instead of
  a terse error. Still exits 64.

### Rules

Diagnostic polish only — no rule semantics changed, so every skill that
passed under 0.2.0 still passes under 0.3.0. Severity defaults and
which rules fire are unchanged.

- `description-too-long`: error message now reports the actual
  character count and shows a `|HERE|` cutoff excerpt with `±40` chars
  of context so authors can see exactly where the text went over.
- `invalid-skill-name`: every diagnostic now disambiguates the
  frontmatter `name:` field from the parent directory name, quotes the
  offending value, and suggests a normalized form. The
  directory-mismatch error offers both directions of the fix (edit the
  field OR rename the dir) instead of silently preferring one.
- `check-relative-paths`: missing-target errors include the resolved
  absolute path, scan the parent directory for the nearest existing
  filename by Levenshtein distance, and surface a `Did you mean ...?`
  suggestion when one is close enough.
- `check-absolute-paths`: gained a one-line rationale (portability)
  and a spec link so authors don't have to guess why a hard-coded
  path is rejected.

### Documentation

- New `example/` directory with `valid/` and `invalid/` reference
  fixtures plus an `example/README.md` walkthrough. Pinned by a
  drift-guard test (`test/example_fixtures_test.dart`) so the
  fixtures and their expected diagnostics can never desync.
- New "Recipes" section in `README.md` with two drop-in integrations:
  a GitHub Actions workflow and a Dart-native pre-commit hook. Pinned
  by `test/recipe_drift_test.dart`, which parses both recipes out of
  the README and replays them against the example fixtures.
- New "Support" section in `README.md` pointing to GitHub Issues,
  Discussions, and the private security-report path.
- `CONTRIBUTING.md` gains a SemVer rule-stability policy that
  describes exactly what kind of rule change requires which version
  bump.

### CI

- New `pana_score` job in `dart_skills_lint_workflow.yaml` that runs
  pana against the package and fails if `grantedPoints` drops below
  150. Catches regressions in package metadata, docs coverage, and
  static-analysis hygiene before they hit pub.dev.
- New `publish_dry_run` job on `workflow_dispatch` only that runs
  `dart pub publish --dry-run` so maintainers can rehearse the v1.0.0
  publish flow without it interfering with day-to-day CI.

## 1.0.0 — planned

v1.0.0 will ship after `0.3.0` has burned in with the named adopters
for at least one of their release cycles. The release will:

- Lock the public rule contract per the SemVer policy in
  `CONTRIBUTING.md` (new rules thereafter default to `disabled`;
  default-severity upgrades require a major bump).
- Publish to pub.dev under a named publisher.
- Make `RULES.md` the canonical reference for every shipped rule's
  default severity and behavior, kept in sync with `RuleRegistry`
  by a consistency test.

No new rules and no rule-shape changes are planned between 0.3.0 and
1.0.0 — the burn-in window is intentional and the freeze is the
point.

## 0.2.0

- Refactored validator to a pluggable rule-based architecture.
- Added support for custom rules via `SkillRule`.
- Added runtime assertion for duplicate rule names.
- Added warning when a rule emits an error with severity different from its definition.
- Updated `README.md` with custom rules documentation.
- **Breaking Change**: Enabling a rule via CLI flag now sets its severity to `error` instead of `warning`.

## 0.1.0

- Initial version.
