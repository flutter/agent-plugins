---
name: dart-skills-lint-setup
description: |-
  Use this skill when you need to set up validation for AI agent skills in a Dart project for the first time.
  Adds the linter as a dev_dependency, creates a configuration file, and generates a baseline for legacy repos.
metadata:
  internal: true
---

# Setting up Skill Validation with dart_skills_lint

This skill covers **first-time wiring** of `dart_skills_lint` into a
repository. For ongoing use — running the linter, interpreting
output, and writing custom rules — see the
[`dart-skills-lint-validation`](../dart-skills-lint-validation/SKILL.md)
skill. For copy-pasteable CI workflow and pre-commit hook recipes,
see the [`Recipes` section of the README](../../README.md#recipes).

## Steps

1. **Add `dart_skills_lint` as a `dev_dependency`.** Prefer a git
   dependency (the package isn't on pub.dev yet):

   ```yaml
   dev_dependencies:
     dart_skills_lint:
       git:
         url: https://github.com/flutter/skills.git
         path: tool/dart_skills_lint
   ```

   **Isolate the dependency** in a `tool/` package when you can,
   instead of putting it on the root `pubspec.yaml` — keeps the
   linter's deps out of your runtime closure. If you must add it
   to multiple `pubspec.yaml` files, ensure the `ref:` (commit
   hash) is identical across all of them so resolution doesn't
   diverge.

2. **Create `dart_skills_lint.yaml`** at the repository root so both
   the CLI and any embedded test invocation share the same config:

   ```yaml
   dart_skills_lint:
     rules:
       check-relative-paths: error
       check-trailing-whitespace: error
     directories:
       - path: ".agents/skills"
   ```

   Rules enabled by default — `check-absolute-paths`,
   `valid-yaml-metadata`, `invalid-skill-name`,
   `description-too-long` — only need to be listed if you want to
   change their severity. See [`RULES.md`](../../RULES.md) for the
   full list.

3. **Generate a baseline** if you're integrating into a repository
   with pre-existing skills that have legacy violations you don't
   want to fix immediately:

   ```bash
   dart run dart_skills_lint:cli --skills-directory=.agents/skills --generate-baseline
   ```

   This writes the current set of failures into an ignore file so
   the next run exits clean. New violations introduced after the
   baseline still surface as errors.

4. **Wire it into CI.** Use the
   [GitHub Actions recipe](../../README.md#recipes) from the README
   verbatim, or follow the
   [pre-commit hook recipe](../../README.md#recipes) below it.

## When you're done

The dart-skills-lint-validation skill takes over from here for
day-to-day use.
