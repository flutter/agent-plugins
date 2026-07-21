# Skill Evaluations (Evals) Framework

Architecture, rubrics, and instructions for evaluating AI agent skills authored and maintained in this repository using an LLM Agent as Judge.

## Core Principles & Architecture

Evaluations in this repository use a **Two-Tiered Architecture** to separate domain-specific skill requirements from universal skill quality standards. The LLM Agent Judge evaluates execution runs against two components:

1. **Domain Evals (`<skill_dir>/evals/evals.json`)**:
   Skill-specific task prompts, macro narrative expected outputs, and micro expectation assertions unique to that skill.

2. **Universal Skill Quality Rubrics (`evals/*_rubric.json`)**:
   Modular, shared quality rubrics injected into the LLM Agent Judge system prompt representing universal quality classes required across skills.

---

### 1. Skill-Specific Evals (`<skill_dir>/evals/evals.json`)
Each skill maintains an `evals/evals.json` file containing target task prompts and expectations:
- **`prompt`**: Realistic user prompt testing primary or edge-case workflows.
- **`expected_output`**: High-level narrative summary of success for human reviewers and judge context.
- **`expectations`**: Array of discrete, testable assertions used by the judge to compute quantitative pass rates.
- **`repo-criteria`**: Array of relative file paths to shared universal quality rubrics (e.g., `["evals/code_quality_rubric.json"]`).

### 2. Universal Skill Quality Rubrics Framework (`evals/*_rubric.json`)
Universal skill quality expectations are structured into modular rubric classes that apply broadly across skills.

---

## Key Rules for Writing Evals

When authoring or updating `evals.json`:

1. Maintain Schema Consistency across all `evals.json` files.

---

## 🚀 Running & Validating Evals Locally

### 1. Validate Evals Structural Consistency
Run the unit test that checks all `evals.json` files for structural consistency across the repository:

```bash
dart test test/skills_evals_test.dart
```

### 2. Running Evals via Agent Orchestration

Within an agentic IDE, you can run evaluations interactively by instructing a parent orchestrator agent to spawn isolated subagents for execution, and then acting as the Agent Judge itself.

By default, evaluations run in **Unary Integration Mode**—meaning only a With-Skill subagent is spawned and evaluated. A Baseline subagent is only spawned if the user explicitly requests a benchmark or A/B comparison.

#### Subagent Execution Prompts

For each test case in `evals.json`, spawn execution subagent(s) using a branched workspace (`Workspace: branch`) to ensure isolation. Use these standard prompt structures:

**With-Skill Execution Prompt:**
```text
Execute this task:
- Skill path: <path-to-skill> (Please read and STRICTLY FOLLOW the instructions in this skill file before finishing)
- Task: <eval prompt>
- Input files: <eval files if any, or "none">

WARNING: You are executing in an isolated branch workspace. Confine all file modifications strictly to your current working directory. Do NOT use absolute paths to modify files in the parent workspace.

Once you are done, do not commit. Just send me a message with the `git diff` of your changes, and the output of running verification commands (e.g., `dart format`, `dart analyze`, `dart test`).
```

**Baseline Execution Prompt (Without Skill Comparison):**
Use this prompt if you are explicitly evaluating the value of a skill by comparing it against an agent that has zero specialized instructions.
```text
Execute this task:
- Task: <eval prompt>
- Input files: <eval files if any, or "none">

WARNING: You are executing in an isolated branch workspace. Confine all file modifications strictly to your current working directory. Do NOT use absolute paths to modify files in the parent workspace.

Once you are done, do not commit. Just send me a message with the `git diff` of your changes, and the output of running verification commands (e.g., `dart format`, `dart analyze`, `dart test`).
```

**Baseline Execution Prompt (Main Branch Comparison):**
Use this prompt if you are evaluating a PR and want to compare the feature branch's skill performance against the stable version of the skill on `main`.
```text
Execute this task:
- Skill path: <path-to-skill> (Please read and STRICTLY FOLLOW the instructions in this skill file before finishing)
- Task: <eval prompt>
- Input files: <eval files if any, or "none">

CRITICAL INSTRUCTION: Before beginning this task, you MUST run `git checkout main` to ensure you are executing the version of the skill that is currently on the main branch.

WARNING: You are executing in an isolated branch workspace. Confine all file modifications strictly to your current working directory. Do NOT use absolute paths to modify files in the parent workspace.

Once you are done, do not commit. Just send me a message with the `git diff` of your changes, and the output of running verification commands (e.g., `dart format`, `dart analyze`, `dart test`).
```

#### Resolving `repo-criteria` for Grading

When preparing to grade execution outputs, the orchestrator or grader agent must resolve the `repo-criteria` section from `evals.json`:

1. **Parse `repo-criteria`**: Read the array of file paths defined under `"repo-criteria"` in `evals.json` (e.g., `["evals/code_quality_rubric.json"]`).
2. **Load Referenced Rubrics**: Open each referenced JSON file relative to the `tool/dart_skills_lint/` directory and extract its `expectations` list under `evaluations`.
3. **Combine Expectations**: Concatenate the universal expectations from `repo-criteria` with the skill-specific `expectations` from `evals.json` to build the full grading payload.

#### Agent Judge Grading

Once execution subagents return their `git diff` and command outputs, grade the results using this prompt template:

**Agent Judge Prompt:**
```text
You are an expert evaluator. Review the following execution outputs from an AI agent against the provided combined rubric. 

Execution Outputs:
- Git Diff: <diff>
- Command Stdout: <test/analyze output>

Combined Rubric Expectations:
<combined expectations list>

For each expectation, explicitly state whether it PASSED or FAILED and provide a 1-sentence justification. Finally, provide an overall PASS/FAIL grade.
```

#### Generating the Evaluation Artifact

After grading the outputs, the orchestrator agent must compile the results into a markdown artifact so they can be easily reviewed.

**Artifact Generation Prompt:**
```text
Please compile the complete evaluation results into a Markdown artifact (e.g., `<skill_name>_eval_results.md`). The document should include:
1. Metadata at the top (Date, Skill Name, Model Evaluated, Prompt).
2. A section for the "With-Skill Agent" containing the PASS/FAIL grade, rationale, and the raw outputs (`git diff` and command stdout).
3. If a comparison was explicitly requested, a section for the "Baseline Agent" containing the PASS/FAIL grade, rationale, and its raw outputs.
```
This artifact serves as the permanent, human-readable record of the execution run.
