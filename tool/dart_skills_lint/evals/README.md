# Skill Evaluations

Architecture, rubrics, and instructions for evaluating AI agent skills authored and maintained in this repository. 
**Note:** These evaluations are essentially unit tests for the skills within the `dart_skills_lint` package and its internal ecosystem. They are *not* intended to be a generic evaluation framework for other agent client plugins or tools outside of this specific domain.

## What Should (and Shouldn't) Be Evaluated

**DO Evaluate:**
- Core workflows of a skill (e.g., adding a dependency, running validation checks).
- Specific edge cases that a skill claims to handle (e.g., legacy integration paths without `--fix`).
- Whether a skill correctly leaves the repository in a compilable, passing state.

**DO NOT Evaluate:**
- Trivial syntax formatting that `dart format` already fixes perfectly.
- Complete system architectures that take longer than a few minutes to generate and verify.
- Skills that are outside the scope of `dart_skills_lint` (e.g. general flutter app creation).

## Core Principles & Architecture

Evaluations in this repository use a **Two-Tiered Architecture** to separate domain-specific skill requirements from universal skill quality standards.

### 1. Per-Skill Evals (`<skill_dir>/evals/evals.json`)
Each skill maintains an `evals/evals.json` file containing target task prompts and expectations:
- **`prompt`**: Realistic user prompt testing primary or edge-case workflows.
- **`expected_chat_output`**: High-level narrative summary of what the LLM should say/give to the user.
- **`expected_repo_state`**: Array of discrete, testable assertions regarding the end state of the repository and tracked files.
- **`repo_criteria`**: Array of relative file paths to shared universal quality rubrics (e.g., `["evals/code_quality_rubric.json"]`).
- **`agent_config`**: The model configuration/harness used when executing the eval against the skill. For published skills, use `"bare-agent"`. For internal contributor skills, use the internal agent profile (e.g., `"reidbaker-agent"`).

### 2. Cross-Skill Evals (`evals/*_rubric.json`)
Universal skill quality expectations are structured into modular rubric classes that apply broadly across skills.

## Cross-Cutting Rules
Skills that author or modify code MUST adhere to the universal code quality expectations defined in `code_quality_rubric.json`. This ensures that generated code compiles cleanly, adheres to Effective Dart, works across platforms, and is placed in standard canonical directories.

## 🚀 Running & Validating Evals Locally

### 1. Validate Evals Structural Consistency
Run the unit test that checks all `evals.json` files for structural consistency across the repository:

```bash
dart test test/skills_evals_test.dart
```

### 2. Running Evals via Agent Orchestration
You should use the `/run-evals` skill to run evaluations. The bulk of the execution logic and prompts are located within the `run-evals` skill itself (`.agents/skills/run-evals/SKILL.md`). The environment, model, and harness are determined by the `agent_config` specified in the corresponding `evals.json` file.
