# Architecture Overview: Agent Skills Linter (`dart_skills_lint`)

This document provides a high-level architectural overview of the `dart_skills_lint` codebase. It outlines the project's components, execution flow, and design patterns used to validate Agent Skill specifications.

## 🧱 Key Components

The codebase is organized into standard Dart package layers, separating CLI handling, validation logic, and data models.

### 🚗 1. CLI Entry Point (`lib/src/entry_point.dart`)
The `entry_point.dart` file serves as the command-line interface. 
- **Argument Parsing:** Uses standard `package:args` to parse input flags (`--skills-directory`, `--generate-baseline`, rules toggles, etc.).
- **Workspace Discovery:** Resolves target folders by searching standard locations (e.g., `.agents/skills`, `.claude/skills`) or parsing user arguments.
- **Ignore System Integration:** Handlers for baseline ignore files (via `--ignore-file` or `dart_skills_lint.yaml`) to filter out known failures without failing the build.
- **Log Management:** Consumes validation reports and standardizes format for terminal display (stdout vs stderr).

### ⚙️ 2. Configuration Parser (`lib/src/config_parser.dart`)
- Loads user-defined custom settings from `dart_skills_lint.yaml` if it exists.
- Maps directory-specific rules overrides and toggles severity defaults.

### 🛡️ 3. Validation Engine (`lib/src/validator.dart`)
The core motor of the package.
- Scans `SKILL.md` using regular expressions (`dotAll: true`) to extract Frontmatter.
- Delegates to sub-routines for checking:
  - **Directory structure:** Correct place and flat tree constraints.
  - **Field constraints:** Descriptions vs name match.
  - **Relational properties:** Verifies relative links resolve correctly on disk.
- Outputs `ValidationResult` objects wrapping aggregates of `ValidationError`.

### 📜 4. Predefined Rules templates (`lib/src/rule_registry.dart` and `lib/src/rules/`)
Contains global definitions for standard checks. Uses standard types (`CheckType`) allowing toggling and severity states.

### 📦 5. Core Data Models (`lib/src/models/`)
- **`ValidationError`:** Complex error object recording rule IDs, messages, severity contexts, and ignore statuses.
- **`CheckType`:** A schema binding check descriptions to severity settings.
- **`IgnoreEntry`:** Structure for serializing/deserializing file suppressions to/from JSON.

---

## ⏳ Execution Lifecycle

A typical run of the linter follows this sequential graph:

```mermaid
graph TD
    Start([CLI - runApp]) --> ArgParse[Parse ARGs & Load config.yaml]
    ArgParse --> Discover[Resolve Target Directories]
    Discover --> ValidatorLoad[Instantiate Validator w/ Settings]
    ValidatorLoad --> DirLoop[Iterate Directories]
    DirLoop --> Validation[Run validator.validate]
    Validation --> ParseFront[YAML Frontmatter Parsing]
    ParseFront --> RuleChecks[Run Field + Path Checks]
    RuleChecks --> ResultAggregate[Compile ValidationError List]
    ResultAggregate --> IgnoreFilter[Apply baseline ignore file filters]
    IgnoreFilter --> LogOutput[Print to console & Set exitCode]
    LogOutput --> Next{Next Dir?}
    Next -- Yes --> DirLoop
    Next -- No --> Finish([Exit Term])
```

## 🧠 Design Principles

- **Separation of Concerns:** CLI runners are isolated from pure validation units. The `Validator` takes objects and doesn't know about `ArgResults`.
- **Stateless Configuration vs Overrides:** When running against a workspace with specific subdirectory traits, the `Validator` instances are re-instantiated with isolated context bindings so properties do not leak.
- **Context Preservation:** Standardizing lint exceptions (Ignore Systems) as structural objects rather than ad-hoc string matches prevent brittle regressions.
