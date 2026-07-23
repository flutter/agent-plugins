---
name: add-dart-lint-validation-rule
description: >
  Instructions for adding a new validation rule and CLI flag to dart_skills_lint.
  Use this skill when asked to create a new rule that validates aspects of skills
  (like frontmatter metadata).
metadata:
  internal: true
---

# Add a New Validation Rule and Flag

Use this skill when you need to add a new validation rule to the `dart_skills_lint` package, expose it as a toggleable CLI flag, and verify its behavior.

---

## 🛠️ Step-by-Step Implementation

### 1. Create the Rule Class
Create a new file in `lib/src/rules/` extending `SkillRule`.

> [!TIP]
> If your rule expects a specific structure in the skill's YAML frontmatter (e.g., inside `metadata`), document this structure clearly in the class Dart docstring.

```dart
// lib/src/rules/my_new_rule.dart

import '../models/analysis_severity.dart';
import '../models/skill_context.dart';
import '../models/skill_rule.dart';
import '../models/validation_error.dart';

class MyNewRule extends SkillRule {
  MyNewRule({super.severity});

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];
    // Add validation logic here using context.rawContent or context.directory
    return errors;
  }
}
```

#### Accessing YAML Frontmatter
If your rule needs configuration from the skill's YAML frontmatter, you can access it via `context.parsedYaml`.

```dart
  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];
    final yaml = context.parsedYaml;
    if (yaml != null) {
      final metadata = yaml['metadata'];
      if (metadata is Map) {
        // Read your custom config here
      }
    }
    return errors;
  }
```

### 2. Register the Rule in `lib/src/rule_registry.dart`

Add a new `CheckType` instance to `RuleRegistry.allChecks` list. This automatically exposes it as a CLI flag.

```dart
// lib/src/rule_registry.dart in allChecks list

  const CheckType(
    name: MyNewRule.ruleName,
    defaultSeverity: MyNewRule.defaultSeverity,
    help: 'Description of what the rule does for CLI help.',
  ),
```

Then, add a case to `RuleRegistry.createRule` to instantiate your rule:

```dart
// lib/src/rule_registry.dart in createRule method

  static SkillRule? createRule(String name, AnalysisSeverity severity) {
    switch (name) {
      // ... other rules
      case MyNewRule.ruleName:
        return MyNewRule(severity: severity);
      default:
        return null;
    }
  }
```

### 3. Handle Disabled by Default Rules (If applicable)
If the rule is disabled by default (`defaultSeverity: AnalysisSeverity.disabled`), passing the flag `--check-my-new-rule` will automatically enable it with `AnalysisSeverity.error` severity (handled in `entry_point.dart`).

---

## 🧪 Testing the New Rule

You must write automated tests verifying your rule triggers when it should and skips when it shouldn't.

### Preferred Approach: In-Memory Unit Tests
Instead of writing files to disk, test the rule directly using a mock `SkillContext`. This is faster and avoids I/O dependencies.

```dart
// test/my_new_rule_test.dart

import 'dart:io';
import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/skill_context.dart';
import 'package:dart_skills_lint/src/models/validation_error.dart';
import 'package:dart_skills_lint/src/rules/my_new_rule.dart';
import 'package:test/test.dart';

void main() {
  group('MyNewRule', () {
    test('flags invalid content', () async {
      final rule = MyNewRule(severity: AnalysisSeverity.warning);
      final context = SkillContext(
        directory: Directory('dummy'),
        rawContent: 'Invalid content',
      );

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('Expected error message'));
    });

    test('passes valid content', () async {
      final rule = MyNewRule(severity: AnalysisSeverity.warning);
      final context = SkillContext(
        directory: Directory('dummy'),
        rawContent: 'Valid content',
      );

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isEmpty);
    });
  });
}
```

### Alternative Approach: File System Interaction
If the rule interacts with the file system or wraps an external CLI tool (like `popmark`), you should use a temporary directory for testing instead of in-memory mocks.

```dart
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('my_rule_test.');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('flags invalid file content', () async {
      final Directory skillDir = await Directory('${tempDir.path}/test-skill').create();
      await File('${skillDir.path}/SKILL.md').writeAsString('Invalid content');

      final rule = MyNewRule(severity: AnalysisSeverity.warning);
      final context = SkillContext(directory: skillDir, rawContent: 'Invalid content');

      final List<ValidationError> errors = await rule.validate(context);

      expect(errors, isNotEmpty);
    });
```

### Integration Tests
If the rule interacts with CLI flags or configuration files, add a test in `test/cli_integration_test.dart` using `TestProcess`.
> [!IMPORTANT]
> When writing integration tests that use config files and `TestProcess`, ensure that paths in the config file and paths passed to the CLI match in style (both relative or both absolute) to avoid issues with path matching in `entry_point.dart`.

---

## 📚 Documentation Updates

When a new rule is introduced, verify that you synchronize sibling markdown files!

1.  **`README.md`:**
    *   Add your flag under the **Flags** section (under **Usage**) so users know it exists. 
    *   **CRITICAL FORMATTING:** You MUST use the exact format `- \`--[no-]<rule-name>\`: <brief description>. (Disabled by default if applicable)`.
    *   **CRITICAL NAMING:** Ensure the flag string matches the `ruleName` EXACTLY. For example, if the `ruleName` is `file-existence`, the flag MUST be documented as `--[no-]file-existence` (do NOT hallucinate a `check-` prefix like `--[no-]check-file-existence`). Do NOT add empty bullet points.
2.  **`RULES.md`:**
    *   Add a new entry for your rule documenting its default severity, fixability, what it checks, diagnostic shape, auto-fix behavior, and how to disable it. This is strictly required by the `rules_md_consistency_test.dart` test.
3.  **`documentation/knowledge/SPECIFICATION.md`:**
    *   Document the formal constraint in the specification if it defines a standard for skill files.

---

## 🚦 Checklist Before Submitting PR

- [ ] Rule class created in `lib/src/rules/`.
- [ ] Rule registered in `lib/src/rule_registry.dart`.
- [ ] Unit tests added in `test/` using in-memory `SkillContext`.
- [ ] **CRITICAL**: Usage flag correctly documented in `README.md` under Flags (ensure flag string matches `ruleName` EXACTLY and format is correct).
- [ ] Rule documented in `RULES.md`.
- [ ] Schema documented in `documentation/knowledge/SPECIFICATION.md` (if applicable).
- [ ] Run `dart format .` to format code.
- [ ] Run `dart analyze --fatal-infos` to ensure no issues.
- [ ] Run `dart test` to ensure tests passing.
