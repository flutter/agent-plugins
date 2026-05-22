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

## Testing and coverage

Run the test suite from the package root (`tool/dart_skills_lint`):

```bash
dart test
```

CI enforces a minimum line-coverage threshold for `lib/` (currently 73%),
excluding generated `*.g.dart` files. To reproduce the coverage numbers
locally:

```bash
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

The local `lcov.info` includes the generated `*.g.dart` files, which CI
excludes via the action's `exclude` input, so your local total reads slightly
higher than the enforced threshold.

CI feeds `coverage/lcov.info` to the
[`very_good_coverage`](https://github.com/VeryGoodOpenSource/very_good_coverage)
GitHub Action, which fails the build when coverage falls below the threshold.
The threshold ratchets against regressions: when you raise overall coverage,
bump `min_coverage` in `.github/workflows/dart_skills_lint_workflow.yaml` to
lock in the gain. To inspect coverage locally, render `coverage/lcov.info` with
`genhtml` or an editor LCOV viewer.

## Community Guidelines

This project follows
[Google's Open Source Community Guidelines](https://opensource.google/conduct/).

We pledge to maintain an open and welcoming environment. For details, see our
[code of conduct](https://dart.dev/code-of-conduct).
