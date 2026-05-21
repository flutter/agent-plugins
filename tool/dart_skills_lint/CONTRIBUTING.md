# How to Contribute

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement (CLA). You (or your employer) retain the copyright to your
contribution; this simply gives us permission to use and redistribute your
contributions as part of the project. Head over to
<https://cla.developers.google.com/> to see your current agreements on file or
to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Code Reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult
[GitHub Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests.

## Coding style

The Dart source code in this repo follows the:

  * [Dart style guide](https://dart.dev/guides/language/effective-dart/style)

You should familiarize yourself with those guidelines.

## File headers

All files in the Dart project must start with the following header; if you add a
new file please also add this. The year should be a single number stating the
year the file was created (don't use a range like "2011-2012"). Additionally, if
you edit an existing file, you shouldn't update the year.

    // Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
    // for details. All rights reserved. Use of this source code is governed by a
    // BSD-style license that can be found in the LICENSE file.

## Community Guidelines

This project follows
[Google's Open Source Community Guidelines](https://opensource.google/conduct/).

We pledge to maintain an open and welcoming environment. For details, see our
[code of conduct](https://dart.dev/code-of-conduct).

## Rule-stability policy (SemVer)

Lint rules are part of `dart_skills_lint`'s public API. Adopters wire
the linter into pre-commit hooks and CI gates, so a rule that silently
flips from "warning" to "error" can break a downstream build with no
code change of their own. We version rule changes the same way we
version code changes:

- **Patch release (`0.3.X` → `0.3.X+1`, `1.0.X` → `1.0.X+1`)** —
  bug fixes to existing rules, including diagnostic message
  rewording, internal refactors, and fixes that *narrow* what a rule
  matches (fewer false positives). The set of error states a passing
  skill needs to clear does not grow.

- **Minor release (`0.3.X` → `0.4.0`, `1.0.X` → `1.1.0`)** — new
  rules, **shipping with `defaultSeverity: AnalysisSeverity.disabled`**
  so existing skills keep passing. Adopters opt in by enabling the
  rule via flag or YAML config. Performance improvements that don't
  change diagnostics also land here. A rule's diagnostic message may
  expand to include additional context.

- **Major release (`0.X` → `1.0`, `1.X` → `2.0`)** — any change that
  can fail a previously-passing skill: removing a rule (so configs
  referencing it stop working), upgrading a rule's default severity
  (`disabled → warning`, `warning → error`), broadening what a rule
  matches (more true positives = more failures), or renaming a rule.
  Releases bump the major version and the CHANGELOG calls out the
  exact rules affected.

Rationale: adopters should be able to set `dart_skills_lint: ^1.0.0`
in `pubspec.yaml` and trust that a `dart pub upgrade` never turns
green CI red without their consent. Surprises belong in major
releases, and only there.

If you're proposing a change that doesn't fit cleanly into one of the
buckets above, say so on the PR and the maintainers will decide where
it lands. New built-in rules **must** include a `## <rule-name>`
entry in `RULES.md` describing default severity and behavior — see
the existing entries for the expected shape.
