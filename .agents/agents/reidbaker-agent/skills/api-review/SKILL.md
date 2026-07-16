---
name: api-review
description: Reviews the specified code against the canonical API Design guidelines. Use this skill when the user asks for an API review or to check code against API design principles.
---

# API review skill

This skill reviews code against the canonical API Design guidelines.

## Instructions

1. **Load Guidelines**: Read the API design guidelines from [references/canonical_api_design.md](references/canonical_api_design.md) to ensure they are fully available in the context.
2. **Identify Target**: Identify the code to review.
   - If the user specified files (e.g., "review main.dart"), use those.
   - If the user has an open file in their context, assume that is the target.
   - If neither, ask the user to specify the target files.
3. **Analyze**: For each target file, perform a deep analysis against the "Foundations of Canonical API Design Principles" (loaded in step 1), specifically looking for:
   - **Contract-First**: Is the interface clear and decoupled from implementation?
   - **KISS/YAGNI**: Are there unnecessary parameters or over-generalized features?
   - **Ergonomics**: Are names intent-revealing? Do they follow the Principle of Least Astonishment?
   - **CQS**: Are commands and queries separated?
   - **Safety**: Are types used strictly (Enums vs Strings)? Is validation visible?
   - **Explicit Configuration**: Are dependencies explicitly injected rather than implicitly resolved via global state, registries, or environment variables?
4. **Report**: Generate a structured report:
   - **Score**: Give a letter grade (A-F) based on alignment.
   - **Critical Issues**: Violations that _must_ be fixed (e.g., severe strictness or safety issues).
   - **Suggestions**: Ergonomic improvements (renaming, rearranging).
   - **Code Examples**: Provide `before` vs `after` code blocks for the suggested improvements.
   - Save the report as a markdown artifact in the conversation artifacts directory (e.g., `<appDataDir>/brain/<conversation-id>/api_review_results.md`).
