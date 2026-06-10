# Rules

The full rule contract for `dart_skills_lint`. Every built-in rule listed
here is registered in
[`lib/src/rule_registry.dart`](lib/src/rule_registry.dart) and pinned to
this document by
[`test/rules_md_consistency_test.dart`](test/rules_md_consistency_test.dart).
If a rule is added, removed, renamed, or has its default severity /
fixability changed, both the registry **and** this file must be updated
in the same commit — the consistency test fails otherwise.

Severity vocabulary:

- `error` — failure exits 1 and blocks CI.
- `warning` — printed but does not change exit code.
- `disabled` — not run unless explicitly enabled via CLI flag or
  `dart_skills_lint.yaml` `rules:` config.

All rules are enabled / disabled / escalated the same three ways:

- CLI: `--<rule-name>` (escalates to `error`),
  `--no-<rule-name>` (disables).
- YAML config: `dart_skills_lint.rules.<rule-name>: error|warning|disabled`.
- Per-directory YAML: `dart_skills_lint.directories[].rules.<rule-name>: ...`.

The "Disable" line under each rule below names the negated CLI flag for
quick reference.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the SemVer policy that
governs how changes to these rules ship.

---

## check-absolute-paths

- **Default severity:** warning
- **Fixable:** yes
- **What it checks:** inline Markdown links in `SKILL.md` do not use
  absolute filesystem paths (POSIX `/foo/bar` or Windows `C:\foo`).
  Absolute paths break portability across machines.
- **Diagnostic shape:**
  `Absolute filepath found in link: <path>. Skills must use paths relative to SKILL.md so they remain portable across machines.`
- **Auto-fix behavior:** if the absolute path resolves to a file that
  exists on disk, the fixer rewrites it to the equivalent POSIX-style
  relative path from `SKILL.md`. If the target does not exist the
  fixer leaves the link untouched.
- **Disable:** `--no-check-absolute-paths`.

## check-relative-paths

- **Default severity:** disabled
- **Fixable:** no
- **What it checks:** inline Markdown links in `SKILL.md` with
  relative targets resolve to files that actually exist on disk.
  Web URLs, anchors, `mailto:`, `javascript:`, and `data:` links are
  skipped.
- **Diagnostic shape:**
  `Linked file does not exist: <path> (resolved to <absolute path>). Did you mean "<sibling>"?`
  The `Did you mean` clause is only included when a near-miss file
  is found in the same directory; it's scored by string similarity
  against the missing basename. The suggestion preserves the link's
  original directory prefix, normalized to forward slashes.
- **Auto-fix behavior:** none. The author is expected to pick the
  intended target by hand.
- **Disable:** `--no-check-relative-paths` (also the default state).

## check-trailing-whitespace

- **Default severity:** disabled
- **Fixable:** yes
- **What it checks:** lines in `SKILL.md` do not have trailing
  whitespace. Exactly two spaces are allowed as a CommonMark hard
  line break; one space or three-or-more spaces, or any trailing tab,
  is reported.
- **Diagnostic shape:**
  `Line <N> has <count> trailing space(s). Only exactly 2 spaces are
  allowed for line breaks.`
  Trailing tabs report `Line <N> has trailing whitespace containing
  tabs.` instead.
- **Auto-fix behavior:** trims violating trailing whitespace from
  each offending line. Lines with exactly two trailing spaces are
  left alone.
- **Disable:** `--no-check-trailing-whitespace` (also the default
  state).

## description-too-long

- **Default severity:** error
- **Fixable:** no
- **What it checks:** the YAML frontmatter `description:` field is
  at most 1024 characters.
- **Diagnostic shape:**
  `Description field is <N> characters; maximum is 1024. Cutoff at
  character 1024: ...<40 chars before>|HERE|<40 chars after>... (see
  https://agentskills.io/specification#description-field)`
  The `|HERE|` marker pins the exact cutoff point so the author can
  see what slipped past the limit without having to count characters.
- **Auto-fix behavior:** none. The fix is editorial; the linter
  refuses to silently truncate the author's prose.
- **Disable:** `--no-description-too-long`.

## disallowed-field

- **Default severity:** disabled
- **Fixable:** no
- **What it checks:** every key in the YAML frontmatter is one of the
  spec-allowed fields: `name`, `description`, `license`,
  `allowed-tools`, `metadata`, `compatibility`, `category`, `tags`,
  `version`, `eval_task`.
- **Diagnostic shape:**
  `Disallowed field: <key> (see
  https://agentskills.io/specification#frontmatter)`
- **Auto-fix behavior:** none. The fix is destructive (removing a
  field) so it requires a human decision.
- **Disable:** `--no-disallowed-field` (also the default state).

## prevent-skills-sh-publishing

- **Default severity:** disabled
- **Fixable:** no
- **What it checks:** the YAML frontmatter contains `metadata:` with `internal: true`, which prevents the skill from being published to skills.sh.
- **Diagnostic shape:**
  A multi-line message specifying the exact structural issue. It instructs the developer to remove quotes if `internal` is set to a string, or warns when `metadata` is missing, not a map, or when `internal` is not explicitly set to boolean `true`. Each diagnostic includes the expected schema:
  ```yaml
  metadata:
    internal: true
  ```
- **Auto-fix behavior:** none.
- **Disable:** `--no-prevent-skills-sh-publishing` (also the default state).

## invalid-skill-name

- **Default severity:** error
- **Fixable:** yes
- **What it checks:** the frontmatter `name:` field is:
  - lowercase
  - 1–64 characters
  - only lowercase letters, digits, and hyphens
  - has no leading, trailing, or consecutive hyphens
  - exactly equal to the parent directory's name
- **Diagnostic shape:** each violation produces a separate error
  message naming the frontmatter `name:` field explicitly,
  quoting the offending value, and suggesting a normalized form
  (e.g. `Frontmatter `name` "My_Skill" contains invalid characters.
  Only lowercase letters, digits, and hyphens are allowed.
  Suggested: "my-skill" (see
  https://agentskills.io/specification#name-field)`).
  The directory-mismatch error offers both fix directions (edit the
  field or rename the directory).
- **Auto-fix behavior:** when the only violation is a directory
  mismatch, the fixer rewrites the frontmatter `name:` value to
  match the parent directory name. Other violations (invalid
  characters, length, etc.) are not auto-fixed because the
  normalization is a suggestion and the author may want a different
  name entirely.
- **Disable:** `--no-invalid-skill-name`.

## valid-yaml-metadata

- **Default severity:** error
- **Fixable:** no
- **What it checks:**
  - `SKILL.md` contains a YAML frontmatter block delimited by `---`
    that parses without errors.
  - Required fields `name` and `description` are both present.
  - If `compatibility:` is present, it is at most 500 characters.
- **Diagnostic shape:**
  - `Invalid YAML metadata: <parser error> (see
    https://agentskills.io/specification#frontmatter)`
  - `Missing required field: <field> (see ...)`
  - `Compatibility field is <N> characters; maximum is 500. Cutoff at character 500: ...<context>|HERE|<context>... (see https://agentskills.io/specification#compatibility-field)`
    — same shape as `description-too-long`, produced by the shared
    `buildLengthDiagnostic` helper.
- **Auto-fix behavior:** none. A broken frontmatter block isn't
  safely mechanically repairable.
- **Disable:** `--no-valid-yaml-metadata`.
