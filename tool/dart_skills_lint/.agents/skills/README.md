# Dart Skills Lint - Agent Skills

This directory (`tool/dart_skills_lint/.agents/skills/`) contains skills and configurations for agents working on the dart_skills_lint package.

## Setup Instructions

To set up this directory for development, you must install the remote skills using `npx`. These include general Dart development practices, testing fundamentals, and productivity tools that agents rely on.

Run the following commands from the `tool/dart_skills_lint/` directory to fetch the dependencies:

```sh
# Core Dart Skills
npx skills install kevmoo/dash_skills/skills/dart-best-practices
npx skills install kevmoo/dash_skills/skills/dart-doc-validation
npx skills install kevmoo/dash_skills/skills/dart-long-lines
npx skills install kevmoo/dash_skills/skills/dart-matcher-best-practices
npx skills install kevmoo/dash_skills/skills/dart-package-maintenance

npx skills install dart-lang/skills/skills/dart-migrate-to-checks-package
npx skills install dart-lang/skills/skills/dart-build-cli-app
npx skills install dart-lang/skills/skills/dart-collect-coverage
npx skills install dart-lang/skills/skills/dart-add-unit-test
npx skills install dart-lang/skills/skills/dart-use-pattern-matching

# Productivity and Workflows
npx skills install mattpocock/skills/skills/productivity/grill-me
npx skills install obra/superpowers/skills/test-driven-development
```

## Overview and Philosophy

* **Remote Dependencies:** We prefer to leverage community-maintained skills from upstream repositories rather than duplicating them locally. This ensures we stay aligned with the broader ecosystem's best practices.
* **Internal Skills:** We maintain a few local skills directly in this repository (e.g., `add-dart-lint-validation-rule` and `dart-skills-lint-integration`). These are explicitly marked with `internal: true` in their frontmatter to prevent them from being accidentally published to the global registry, as they are specific to our local tools.

## Contributing and Maintenance

When adding new external skills to this directory, follow these guidelines:

1. Use `npx skills install` to pull them from upstream.
2. Add the generated skill folder name to `.gitignore` inside this directory (`.agents/skills/.gitignore`) to prevent checking third-party content into version control.
3. Commit the updated `skills-lock.json` file located in `tool/dart_skills_lint/` to track dependency versions across the team.
