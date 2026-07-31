# Agent Skills Specification

This document defines the technical requirements and architectural priorities for implementing Agent Skills. It serves as a self-contained reference for engineers building or integrating skills into AI agent environments.

## 1. Overview
An **Agent Skill** is a portable, self-contained directory that extends an AI agent's capabilities. It provides the agent with specific instructions, tools, and domain-specific knowledge required to perform a specialized task.

## 2. Directory Structure
A skill directory must follow a flat and predictable structure. The only mandatory file is `SKILL.md` at the root.

```text
skill-name/
├── SKILL.md       # Required: Metadata + Instructions
├── scripts/       # Optional: Executable code (Python, Bash, JS, etc.)
├── references/    # Optional: Deep-dive documentation and templates
└── assets/        # Optional: Static resources (images, schemas, etc.)
```

## 3. The `SKILL.md` File
The `SKILL.md` file uses YAML frontmatter for machine-readable metadata, followed by Markdown-formatted instructions for the agent.

### 3.1 Metadata (YAML Frontmatter)
| Field | Required | Constraints |
| :--- | :--- | :--- |
| `name` | Yes | 1-64 chars; lowercase alphanumeric and hyphens (`-`) only; no leading/trailing/consecutive hyphens. **Must match the parent directory name.** |
| `description` | Yes | 1-1024 chars. A concise summary used by agents to determine when to activate the skill. |
| `license` | No | Short name (e.g., MIT, Apache-2.0) or reference to a bundled license file. |
| `compatibility` | No | 1-500 chars; specifies environment requirements (e.g., `Requires Python 3.10+`, `Node.js 18`). |
| `metadata` | No | Arbitrary key-value mapping for client-specific properties (e.g., `version`, `author`). |
| `allowed-tools` | No | (Experimental) Space-delimited list of pre-approved tools (e.g., `Bash(git:*)`). |

### 3.2 Instructions (Markdown Body)
The body should contain the "expert knowledge" for the agent.
- **Referencing:** Use relative paths to files within the skill directory (e.g., `[See technical details](references/DETAILS.md)`).


## 4. Implementation Requirements

### 4.1 Validation
Validation ensures that a skill directory and its `SKILL.md` file adhere to the specification. A linter or validator must check the following rules:

#### 4.1.1 Directory and File Structure
- **Existence**: The target path must exist and be a directory.
- **Mandatory File**: The root directory must contain a `SKILL.md` file.

#### 4.1.2 Metadata (YAML Frontmatter)
- **YAML Integrity**: The frontmatter must be valid YAML.
- **Allowed Fields**: Only the following fields are allowed: `name`, `description`, `license`, `allowed-tools`, `metadata`, `compatibility`.
- **Required Fields**: `name` and `description` are mandatory.

#### 4.1.3 Field Specific Constraints
- **Skill Name (`name`)**:
  - Must be lowercase.
  - Length: Maximum 64 characters.
  - Characters: Only lowercase letters, digits, and hyphens (`-`).
  - No leading or trailing hyphens.
  - No consecutive hyphens (`--`).
  - **Directory Name Match**: The skill `name` must exactly match the name of its parent directory.
- **Description (`description`)**:
  - Length: Maximum 1024 characters.
- **Compatibility (`compatibility`)**:
  - Length: Maximum 500 characters.

#### 4.1.4 Content Constraints
- **Trailing Whitespace**: Lines in `SKILL.md` should not have trailing whitespace. Exactly 2 spaces at the end of a line are allowed to support Markdown hard line breaks, per the [CommonMark Spec](https://spec.commonmark.org/0.31.2/#hard-line-breaks).
- **Path Constraints**: **Inline** Markdown links must not use absolute paths to enforce portability. Can optionally be configured to check that relative paths point to valid, existing files (disabled by default). *Note: Validation only applies to inline Markdown links; HTML and reference-style links are not supported.*

## 5. Scripts & Tools
- Scripts in the `scripts/` directory should be self-documenting and provide clear error messages.

## 6. Versioning
- Use the `metadata` field in `SKILL.md` to track versions:
  ```yaml
  metadata:
    version: "1.0.0"
  ```

## 7. Best Practices
- **Avoid Deep Nesting:** Keep the directory structure as flat as possible. References should ideally be only one level deep from the root.
