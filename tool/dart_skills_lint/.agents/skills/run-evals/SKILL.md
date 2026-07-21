---
name: run-evals
description: Run evaluations for one, multiple, or all skills using the agent orchestration framework. Make sure to use this skill whenever the user asks to run evals, test a skill's performance, run benchmarks, or compare baseline versus with-skill execution.
metadata:
  internal: true
---

# Run Skill Evals

1. **Read Framework**: Read `tool/dart_skills_lint/evals/README.md` for the exact subagent and grader prompts.
2. **Locate Targets**: Find target `evals/evals.json` files inside `.agents/skills/` and/or `skills/`.
3. **Orchestrate**: For each eval prompt, spawn two `bare-agent` subagents using `Workspace: branch`:
   - **Baseline**: Provide only the task prompt.
   - **With-Skill**: Provide the task prompt + instructions to strictly follow the target skill file.
   Instruct both to return their `git diff` and verification outputs (`dart format`, `dart analyze`, `dart test`) without committing.
   **CRITICAL**: You must explicitly warn both subagents to confine all file edits strictly to their current working directory and avoid using absolute paths to modify the parent workspace.
4. **Grade**: Parse the combined rubric (resolving `repo-criteria` + `evals.json` expectations).
5. **Artifact**: Grade the outputs and generate a Markdown artifact (e.g., `<skill>_eval_results.md`) containing the metadata, pass/fail rationale, and raw diffs/stdout.
