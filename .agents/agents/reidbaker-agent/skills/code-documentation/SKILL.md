---
name: code-documentation
description: Guide for writing effective code documentation, including docstrings, JSDoc, dartdoc, and implementation comments. Use this skill when writing new code, adding features, or improving existing documentation in Dart, Python, or TypeScript to ensure clarity and maintainability.
---

# Code Documentation Skill

This skill provides comprehensive guidelines for documenting code, prioritizing user-centric writing, clarity, and consistency.

## 1. General Philosophy

- **User-Centric**: Write for the person using your API. If you had to look up how to use something, document it so others don't have to.
- **Explain "Why"**: Explain _why_ code exists and _how_ to use it effectively, since the code signature already tells _what_ it does.
- **Be Concise**: Omit fluff. Avoid merely restating the code name, as it is not helpful.
- **Consistency**: Use standard terminology and consistent formatting.
- **Public APIs**: Document all public APIs (classes, members, top-level functions) without exception.
- **Code Samples**: Strongly consider adding code samples to explain usage.

## 2. General Structure

Follow this general structure for documentation comments across languages:

1.  **Summary Sentence**: Start with a single-sentence summary on the first line, ending with a period.
2.  **Blank Line**: Follow the summary with a blank line.
3.  **Details**: Add paragraphs, code samples, or lists as needed to explain parameters, return values, exceptions, and behavior.
4.  **Annotations**: Place doc comments **before** any metadata annotations.

## 3. Writing Guidelines

### Brevity & Style

- **Avoid Fluff**: Omit "This class...", "This method...", "Is used to...", "Note that...".
  - _Bad_: "This method is used to calculate the total."
  - _Good_: "Calculates the total."
- **Third-Person Verbs**: Start function/method docs with a third-person singular verb.
  - _Examples_: "Returns...", "Calculates...", "Updates...", "Creates...".
- **Noun Phrases**: Start variable/property docs with a noun phrase.
  - _Examples_: "The current color.", "A list of active users.".
- **Booleans**: Always start with "Whether" (or similar clear indicator).
  - _Good_: "Whether this widget is enabled."
  - _Bad_: "If this widget is enabled...", "True if...", "Flag to indicate...".
- **Avoid Jargon**: Use plain English unless the term is a widely accepted standard (e.g., "HTTP", "URL").

### Formatting

- **Sparingly**: Use Markdown features (bold, lists) sparingly.
- **No HTML**: Avoid HTML unless strictly necessary and supported by the documentation tool.
- **Parameters/Returns/Exceptions**: Use prose to describe parameters, return values, and thrown exceptions. Do not rely solely on tags like `@param` unless mandated by the language standard (e.g., Javadoc).

## 4. Implementation Comments

Ensure implementation comments (`//`) are accurate, relevant, factual, and provide information that is not readily understandable from the code. Remove or reword comments that do not meet these criteria. If an implementation comment provides information useful to an API consumer that is not already in the documentation comments, move it to the documentation comments.

## 5. Review Checklist

Use this checklist to verify your documentation:

1.  [ ] **Summary**: Ensure every public member starts with a one-sentence summary ending in a period.
2.  [ ] **Brevity**: Remove "This class..." or "This function..." fluff.
3.  [ ] **Completeness**: Document strict constraints (e.g., "must not be null") and exceptions.
4.  [ ] **Examples**: Consider adding a code sample for complex widgets or methods.

## 6. Language Specific Instructions

Refer to the language guides for detailed instructions on structure, linking, and framework-specific patterns:

- **Dart / Flutter**: [references/dart.md](references/dart.md)
- **TypeScript / JavaScript**: [references/typescript.md](references/typescript.md)
- **Python**: [references/python.md](references/python.md)
