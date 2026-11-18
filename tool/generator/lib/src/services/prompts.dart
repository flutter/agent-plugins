// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

/// Manages prompts used by the GeminiService.
class Prompts {
  /// Creates the prompt for generating a new skill.
  static String createSkillPrompt(String markdown, String? instructions) {
    return '''
Rewrite the following technical documentation into a high-quality "SKILL.md" file.
Synthesize the essential procedures into a concise, focused document strictly under 500 lines and between 1,500 and 3,500 tokens (never exceed 5,000 tokens). Omit basic introductory concepts that competent AI agents already know.

${instructions != null && instructions.isNotEmpty ? 'Special Instructions: $instructions' : ''}

Raw Content:
$markdown
''';
  }

  /// Creates the prompt for updating an existing skill.
  static String updateSkillPrompt(
    String existingContent,
    String markdown,
    String? instructions,
  ) {
    return '''
Update the following existing "SKILL.md" file using the provided new technical documentation.
Carefully integrate the new information without losing valuable existing instructions or context, keeping the final output concise, high-density, and strictly under 500 lines.

${instructions != null && instructions.isNotEmpty ? 'Special Instructions: $instructions' : ''}

Existing SKILL.md Content:
$existingContent

New Technical Documentation (Raw Content):
$markdown
''';
  }

  /// Creates the prompt for validating an existing skill.
  static String validateExistingSkillContentPrompt(
    String markdown,
    String instructions,
    String generationDate,
    String modelName,
    String currentSkillContent,
  ) {
    return '''
Validate the following skill document against the provided source material and verify if it is valid.
Focus on accuracy, structure, and completeness based on the Source Material and the system instructions.

Context:
- The skill was originally generated on: $generationDate
- The current evaluation is using model: $modelName
- The instructions used to generate the skill were:
$instructions

Source Material:
$markdown

Current Skill Content:
  "$currentSkillContent"
---

Grade the current output based on the instructions and the comparison to current website content and instructions today.
Establish a conclusion on whether the new skill is valid or not.
Reasons for a good or bad quality grade should be provided including concepts such as missing content, different model used, more than a few months old, etc.
On the very last line, output "Grade: [0-100]" representing overall quality of the skill compared to the assumed value if it were generated again today.
''';
  }
}
