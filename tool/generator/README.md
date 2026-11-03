# Skills CLI

The Skills CLI simplifies the process of creating "Agent Skills" from external documentation. It allows you to crawl documentation websites to discover relevant pages and then uses Generative AI (Gemini) to convert those pages into structured `SKILL.md` files that agents can use.

## Context

*   [Agent Skills Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

## Prerequisite

This tool requires the `GEMINI_API_KEY` environment variable to be set.

## Commands

> [!NOTE]
> To use the default configuration file path (`resources/flutter_skills.yaml`), commands should be run from the root of the repository as: `dart run tool/generator/bin/skills.dart <command>`.
> Alternatively, if running from this directory, specify the path to the configuration file explicitly (e.g., `../../resources/flutter_skills.yaml`).

### `generate-skill`

Generates `SKILL.md` files from a YAML configuration file. Use the `--skill` option to generate a specific skill.

**Usage:**
```bash
dart run skills generate-skill [options] [config_file]
```

**Arguments:**
*   `[config_file]`: Path to the YAML configuration file. Defaults to `resources/flutter_skills.yaml`.

**Options:**
*   `--skill`: Filter to generate only the specified skill by name.
*   `--directory` (`-d`): The directory to output the generated skill folder. Defaults to `../skills/`.
*   `--dry-run`: Performs a dry run, showing what would be generated and token count without writing files.

**Example:**
Generate all skills defined in resources/flutter_skills.yaml to the skills/ directory:

```bash
dart run skills generate-skill
```

Generate only the 'flutter-layout' skill to a custom directory:

```bash
dart run skills generate-skill --skill flutter-layout --directory ../skills
```

### `update-skill`

Updates an existing skill by combining its current content with fetched resources and new instructions.

**Usage:**
```bash
dart run skills update-skill [options] [config_file]
```

**Arguments:**
*   `[config_file]`: Path to the YAML configuration file. Defaults to `resources/flutter_skills.yaml`.

**Options:**
*   `--skill`: Filter to update only the specified skill by name.
*   `--directory` (`-d`): The directory to search for skills. Defaults to `../skills/`.
*   `--thinking-budget`: The token budget for the model to "think" before generating content. Defaults to 2048.

**Example:**
Update all skills defined in resources/flutter_skills.yaml:

```bash
dart run skills update-skill
```

Update only the 'flutter-layout' skill:

```bash
dart run skills update-skill --skill flutter-layout
```

### `validate-skill`

Validates skills by re-generating and comparing with existing skills. This is useful for testing prompts or verifying consistency.

**Usage:**
```bash
dart run skills validate-skill [options] [config_file]
```

**Arguments:**
*   `[config_file]`: Path to the YAML configuration file. Defaults to `resources/flutter_skills.yaml`.

**Options:**
*   `--skill`: Validate only the specified skill by name.
*   `--directory` (`-d`): The directory containing the generated skills to validate. Defaults to `../skills/`.
*   `--thinking-budget`: The token budget for the model to "think" before generating content. Defaults to 2048.

**Example:**
Validate skills in the default 'skills' directory:

```bash
dart run skills validate-skill
```

Validate skills in a custom directory:

```bash
dart run skills validate-skill --directory ../validation_results
```

### `update-readme`

Updates the `README.md` file with a table of available skills.

**Usage:**
```bash
dart run skills update-readme [config_file] [readme_file]
```

**Arguments:**
*   `[config_file]`: Path to the YAML configuration file. Defaults to `resources/flutter_skills.yaml`.
*   `[readme_file]`: Path to the README.md file to update. Defaults to `../README.md`.

**Example:**
Update the root README.md:

```bash
dart run skills update-readme
```

## Configuration

The default configuration file is located at `resources/flutter_skills.yaml`. It contains a list of skill definitions:

```yaml
- name: flutter-layout
  description: "..."
  resources:
    - https://docs.flutter.dev/ui/widgets/layout
    - https://docs.flutter.dev/ui/layout
    - ../packages/flutter/lib/src/widgets/layout.md
```

### Adding, Renaming, or Deleting Skills

When adding, renaming, or deleting a `flutter-*` skill in `skills/`:

1.  **Update `README.md`**: Run `dart run skills update-readme` (or update the `Available Skills` table in the root `README.md`) so the table matches the `flutter-*` directories in `skills/`.
2.  **Update `skills.sh.json`**: Add, rename, or remove the skill entry under `groupings` in the root `skills.sh.json` file ([skills.sh documentation](https://www.skills.sh/docs/customize)).
    *   Only `flutter-*` skills belong in `groupings` (synced `dart-*` skills are canonical in `dart-lang/skills`).
    *   Because `skills.sh` retains historical skill slugs from install telemetry after a skill is renamed or deleted in Git, `"notGrouped": "bottom"` at the end of `skills.sh.json` automatically demotes any retired skill slugs and ungrouped `dart-*` copies into an `Other skills` section at the bottom of the page.
3.  **Verify**: Run `dart test` in `tool/generator` (`test/lint_skills_test.dart` verifies that `skills.sh.json` and `README.md` match the `flutter-*` directories in `skills/`).

## Development

To run analysis, formatting, and tests, navigate to this directory (`tool/generator`) and run:

```bash
dart analyze
dart format .
dart test
```
