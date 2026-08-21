---
name: dart-write-documentation
description: "Rules and formatting guidelines for writing Dart /// API documentation and doc comments. Use when documenting Dart code, writing doc comments for any Dart declaration (libraries, classes, methods, variables, etc.), or when instructed to follow the Effective Dart documentation guidelines."
---

# Writing Dart API Documentation

## Contents
*   [1. Scope and Structure](#1-scope-and-structure)
*   [2. Tone and Openers](#2-tone-and-openers)
*   [3. Strict Anti-Patterns (Banned)](#3-strict-anti-patterns-banned)
*   [4. Technical Placement & Resolution](#4-technical-placement--resolution)
*   [5. Linking and Markdown](#5-linking-and-markdown)
*   [6. Verification](#6-verification)
*   [Examples](#examples)

When asked to write or update documentation for Dart code, you must strictly follow these formatting rules based on the "Effective Dart: Documentation" guidelines.

## 1. Scope and Structure
*   **Target Public APIs:** Focus your documentation efforts on public declarations. Do not document private members (those starting with an underscore `_`) unless explicitly instructed, as they do not appear in generated API reference sites.
*   **Always use `///`:** Use `///` consecutive line comments for all API documentation. Never use `/** ... */` block comments.
*   **Proper Sentences:** Format all comments like proper sentences. Capitalize the first word (unless it's a lowercase identifier) and end with a period.
*   **The First Paragraph:** The first paragraph of a doc comment must be a single, concise sentence that summarizes the element. End it with a period. Dartdoc extracts this verbatim for list views.
*   **Separation:** Always separate the first sentence summary from the rest of the documentation with a blank line containing `///`. Never output a completely empty newline (e.g., a `\n` without `///`), as this terminates the doc comment block.

## 2. Tone and Openers
*   **Noun phrases for properties:** Start descriptions of variables, getters, or setters with a noun phrase.
    `/// The radius of the sphere.` (Not "Gets the radius...")
*   **"Whether" for booleans:** Start documentation for boolean properties with "Whether".
    `/// Whether the connection is active.`
*   **Third-person verbs for methods:** Start descriptions of methods or functions with a third-person verb that describes what it does.
    `/// Initializes the database.` (Not "Initialize" or "This method initializes").
*   **Avoid redundancy:** Do not restate the signature or the element name. Do not say "This class is a..." or "The foo method does...".

## 3. Strict Anti-Patterns (Banned)
*   **No Javadoc/TSDoc Tags (`@param`, `@return`, `@throws`, etc.):** Never use Javadoc-style tags (`@param`, `@return`, `@returns`, `@throws`, `@exception`, `@see`, `@type`). Instead, weave parameter names, return behavior, and exceptions into the prose.

## 4. Technical Placement & Resolution
*   **Annotations (`@override`, etc.):** Doc comments must be placed before metadata annotations.
*   **Inherited Documentation:** Avoid duplicating doc comments on `@override` members if the behavior does not differ from the superclass or interface. Dartdoc automatically inherits the base documentation.
*   **Getter/Setter Pairs:** If a property has both a getter and a setter, place the documentation only on the getter. Tooling will emit a warning if both are documented.
*   **Default Constructors:** To link to a default, unnamed constructor in doc comments, you must use the `.new` syntax (e.g., `[ClassName.new]`).

## 5. Linking and Markdown
*   **Square brackets (`[identifier]`) for in-scope symbols:** Use square brackets to link to any in-scope identifier (parameters, classes, methods, fields, and top-level functions) so dartdoc can resolve them. Never use backticks for parameters.
*   **No parentheses in method links:** Avoid parentheses in links (e.g., use `[String.contains]`, not `[String.contains()]`).
*   **Backticks for keywords & literals:** Use backticks for keywords, literals, and arbitrary expressions (e.g. `` `null` ``, `` `true` ``, `` `void` ``). Never put keywords in square brackets (avoid `[null]` or `[true]`).
*   **Out-of-Scope Links:** If you need to link to a symbol that is not imported by the current library, use the `@docImport` directive at the top of the file (on the `library;` declaration) rather than adding a standard `import`.
*   **Code Blocks:** For code samples, always label the language fence. Use ```` ```dart ```` for Dart, or ```` ```sh ```` for shell commands. Do not leave code blocks unlabelled, as Dartdoc will attempt to auto-detect the language and frequently guesses wrong.
*   **Formatting:** Use standard Markdown (bold, lists, etc.) after the first paragraph to fully explain edge cases, exceptions thrown, and internal behavior the caller cannot see.

## 6. Verification
After writing or updating doc comments:
1. Run `dart analyze` to ensure all bracketed references resolve properly without triggering `comment_references` warnings.
2. (Optional) Run `dart doc` to verify the generated documentation renders cleanly.

## Examples

### 1. Banned Tags vs. Prose
**Bad:**
```dart
/// This method fetches data.
/// @param force true to force reload.
/// @return the data
/// @throws NetworkException if host is unreachable.
Data load(bool force) { ... }
```
**Good:**
```dart
/// Fetches the remote data.
///
/// If [force] is true, this bypasses the local cache and forces a
/// network request.
///
/// Throws a [NetworkException] if the host is unreachable.
Data load(bool force) { ... }
```

### 2. The Annotation Placement Trap
**Bad:**
```dart
@override
/// Renders the widget to the screen.
Widget build(BuildContext context) { ... }
```
**Good:**
```dart
/// Renders the widget to the screen.
@override
Widget build(BuildContext context) { ... }
```

### 3. Openers and Tone
**Bad:**
```dart
/// Gets if the connection is active.
bool get isActive => _active;

/// This method initializes the connection.
void init() { ... }
```
**Good:**
```dart
/// Whether the connection is active.
bool get isActive => _active;

/// Initializes the connection.
void init() { ... }
```

### 4. Constructor Linking
**Bad:**
```dart
/// Creates a new user. Similar to calling [User()].
User.create() { ... }
```
**Good:**
```dart
/// Creates a new user. Similar to calling [User.new].
User.create() { ... }
```

### 5. Out-of-Scope Links (@docImport)
**Bad:**
```dart
import 'package:http/http.dart'; // Adds unnecessary runtime dependency just for docs

/// To use this, you must pass a [Client].
```
**Good:**
```dart
/// @docImport 'package:http/http.dart';
library;

/// To use this, you must pass a [Client].
```
