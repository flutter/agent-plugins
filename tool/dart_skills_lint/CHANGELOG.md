## 0.4.0-dev.1

**Pre-release.** Pub.dev consumers with caret ranges (`^0.3.0` or `^0.4.0`)
will not auto-pick this up; pin explicitly (`dart_skills_lint: 0.4.0-dev.1`)
to try the preview.

### Distribution

- Native binaries are now published to GitHub Releases for macOS arm64,
  macOS x64, Linux x64, and Linux arm64. Users without the Dart SDK on
  PATH can install the linter via `install.sh` or a direct `curl -L` of
  the release tarball — no `dart pub global activate` required.
- New `tool/dart_skills_lint/scripts/install.sh`: detects OS/arch,
  downloads the matching tarball from the latest release, verifies its
  SHA256 against the release's `SHA256SUMS`, and installs the binary to
  `INSTALL_DIR` (default `/usr/local/bin`, with a sudo fallback).
  `REPO`, `VERSION`, and `INSTALL_DIR` are env-configurable.
- New `.github/workflows/dart_skills_lint_release.yaml`: tag-triggered
  workflow that builds the four-target matrix with `dart compile exe`,
  packages each as `dart_skills_lint-<target>.tar.gz`, generates a
  `SHA256SUMS` aggregate, and cuts a GitHub Release whose body is
  extracted from this CHANGELOG entry.
- The pub.dev install paths (`dart pub global activate dart_skills_lint`
  and `dev_dependencies:`) are unchanged. Native binaries are a parallel
  channel, not a replacement.
- macOS binaries in this preview are **not yet code-signed**. Users will
  see a Gatekeeper warning on first launch. Workaround:
  `xattr -d com.apple.quarantine $(which dart_skills_lint)`. Signing
  lands once the org Developer ID Application cert is approved.
- Homebrew formula is **deferred**: `dart_skills_lint` is being moved to
  a dedicated repo (location TBD), and a `brew tap` would force every
  early adopter through a re-tap on migration. The formula ships from
  the new repo once it exists.

## 0.3.1

- `--fix` now writes fixes to disk; pair with `--dry-run`
  (`--fix --dry-run`) to preview the proposed diff without writing.
  The legacy `--fix-apply` flag still works but is deprecated and
  emits a notice on stderr.
- Running the CLI with no arguments and no `.claude/skills` or
  `.agents/skills` directory present now prints a short onboarding
  guide explaining how to point the linter at a skill or a skills
  root.
- `description-too-long` errors now report the actual character
  count and show an excerpt with a `|HERE|` marker at the cutoff
  so authors can see exactly where the text went over. The same
  diagnostic shape is now used for the `compatibility` field's
  500-character limit.
- `invalid-skill-name` errors now disambiguate the frontmatter
  `name:` field from the parent directory name, quote the offending
  value, and suggest a normalized form. The directory-mismatch
  error offers both directions of the fix (edit the field or
  rename the directory).
- `check-relative-paths` errors now include the resolved absolute
  path and, when a near-miss filename exists in the same
  directory, surface a `Did you mean "..."?` suggestion that
  preserves the link's directory prefix.
- New `example/` directory with reference `valid` and `invalid`
  skill fixtures and a walkthrough.
- New "Recipes" section in `README.md` with copy-pasteable GitHub
  Actions and pre-commit hook integrations.

## 0.3.0

- Exposed `ConfigParser.loadConfig()` API to load configuration files programmatically.
- Supported tilde expansion (`~/`) in configuration file paths.
- Updated documentation to clarify CLI vs. Dart Test usage.

## 0.2.0

- Refactored validator to a pluggable rule-based architecture.
- Added support for custom rules via `SkillRule`.
- Added runtime assertion for duplicate rule names.
- Added warning when a rule emits an error with severity different from its definition.
- Updated `README.md` with custom rules documentation.
- **Breaking Change**: Enabling a rule via CLI flag now sets its severity to `error` instead of `warning`.

## 0.1.0

- Initial version.
