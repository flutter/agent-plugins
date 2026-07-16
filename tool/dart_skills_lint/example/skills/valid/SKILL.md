---
name: valid
description: >-
  Reference fixture for dart_skills_lint. Demonstrates a SKILL.md that
  passes every default rule: hyphen-lowercase name matching the parent
  directory, a properly sized description, and no other frontmatter fields
  that would trigger the disallowed-field check.
metadata:
  internal: true
---

# Valid example skill

This skill exists so the linter has a known-good fixture to validate
against. It deliberately does nothing useful — it's documentation.

Run it with:

```bash
dart run dart_skills_lint --skill ./example/skills/valid
```

Expected output: `Skill is valid.` and exit code 0.
