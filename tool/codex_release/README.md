# codex_release

Builds, validates, and releases the Dart and Flutter Codex plugin zip that's
uploaded to the [OpenAI plugin submission portal](https://platform.openai.com/plugins).

The zip is a skills-only build of the plugin: the release copy of
`.codex-plugin/plugin.json` has every MCP reference removed and release notes
added. The repo manifest is unchanged.

## Releasing

From an up-to-date `main` with no uncommitted changes:

```sh
dart run tool/codex_release/bin/release.dart
```

The script:

1. checks that you're on `main`, it matches the remote, and the tree is clean;
2. reads `version` from `.codex-plugin/plugin.json` and stops if
   `codex-plugin-v<version>` already exists;
3. creates and pushes the tag;
4. waits for the `release_codex_plugin` workflow to build and validate the zip;
5. downloads the zip to `dist/`.

Then upload the zip in the portal, resolve any findings, submit it for review,
and publish it after approval.

If the version was already released, bump `version` in
`.codex-plugin/plugin.json` in a PR first. Tags are never moved or reused.

The script needs the [GitHub CLI](https://cli.github.com) (`gh auth login`),
and push access to `flutter/agent-plugins`. It finds the git remote for
`flutter/agent-plugins` automatically; pass `--remote` to choose one.

To check everything without tagging, build and validate the zip locally:

```sh
dart run tool/codex_release/bin/release.dart --dry-run
```

## Building and validating by hand

```sh
dart run tool/codex_release/bin/build.dart          # writes dist/dart-flutter-codex-<version>.zip
dart run tool/codex_release/bin/validate.dart dist/dart-flutter-codex-<version>.zip
```

The validator checks the zip against OpenAI's documented
[package rules](https://developers.openai.com/plugins/deploy/submission-errors)
and reports OpenAI's error code for each problem. Checks specific to this repo
use codes starting with `release_`. The portal is still the final authority:
its skill safety scans and review can't be reproduced locally.

## Release notes

The build sets `extensions.com.openai.publication.release_notes` to the skills
added, updated, and removed since the previous `codex-plugin-v*` tag. Pass
`--release-notes` to `build.dart` to override them.
