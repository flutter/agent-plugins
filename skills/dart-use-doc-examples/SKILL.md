---
name: dart-use-doc-examples
description: "How to inject external code examples into Dartdoc using the {@example} directive, and how to filter those files using #hide, #region, and #endregion tags."
---

# Using Examples in Dartdoc

## Contents
*   [1. The `{@example}` Directive](#1-the-example-directive)
*   [2. Using Regions](#2-using-regions)
*   [3. Hiding Setup Code](#3-hiding-setup-code)
*   [4. Marker Filtering Rules](#4-marker-filtering-rules)
*   [5. Placement and Path Resolution](#5-placement-and-path-resolution)
*   [6. Verification](#6-verification)

When writing documentation that requires multi-line code examples, you should generally extract those examples into standalone `.dart` files and inject them using the `{@example}` directive, rather than writing them inline inside `///` comments. This ensures the examples can be analyzed, linted, and executed.

## 1. The `{@example}` Directive
The `{@example}` directive parses an external file and resolves it into a fenced Markdown code block in the generated documentation.

**Syntax:** `{@example <path>[#<region>] [lang=LANGUAGE] [indent=keep|strip]}`

*   **`<path>`**: The path to the file. A leading `/` evaluates from the package root. Otherwise, it is relative to the current file.
*   **`lang`**: The language for the markdown fence. Auto-detected from the file extension (e.g., `dart`), but can be explicit (e.g., `lang=text`).
*   **`indent`**: `strip` (default) aggressively removes shared leading indentation from the code block.

*Bad (Inline Markdown):*
```dart
/// Makes a client service request to the backend.
///
/// ```dart
/// final client = Client();
/// client.send();
/// ```
```

*Good (External File Injection):*
```dart
/// Makes a client service request to the backend.
///
/// {@example /example/client_request.dart}
```

## 2. Using Regions
Often, an external example file contains imports, setup, or `void main()` wrappers that you don't want to show in the documentation. You can extract a specific block of code by appending `#<region>` to the `{@example}` directive path, and wrapping that code with `#region` and `#endregion` comments in the target file.

**Dart Code (e.g., `/example/client.dart`):**
```dart
import 'package:http/http.dart';

void main() {
  // #region request_snippet
  final client = Client();
  client.send();
  // #endregion request_snippet
}
```

**Dartdoc Usage:**
```dart
/// Connects the client to the server and sends a request.
///
/// {@example /example/client.dart#request_snippet}
```

## 3. Hiding Setup Code
If there is a specific line of code within your extracted region that is necessary for the compiler/analyzer to pass but irrelevant (or distracting) for the documentation reader, append `#hide` to that line.

**Dart Code:**
```dart
final mockServer = startServer(); // #hide
final data = await fetch(mockServer.url);
```
In the generated documentation, only `final data = await fetch(mockServer.url);` will be visible. The line with `#hide` is completely dropped.

## 4. Marker Filtering Rules
When working with `#hide`, `#region`, and `#endregion` markers, you must follow these two technical constraints:

*   **Region Required:** The markers are only processed and stripped when you target a specific region suffix (e.g., `{@example file.dart#region_name}`). If you inject an entire file without a region suffix, the file is embedded exactly as it appears in the source, including any marker text like `// #hide`.
*   **Format Agnosticism:** The marker system is completely format-agnostic. Dartdoc simply runs a regex to strip lines containing the marker strings, meaning it works identically in non-Dart files (e.g., inside YAML comments `# #region` or HTML comments `<!-- #region -->`).

## 5. Placement and Path Resolution
The `{@example}` directive is a block-level directive. It must appear on its own line prefixed with `///`. Its internal `<path>` parser follows strict URI reference rules:

*   **Package-Root Paths (`/`)**: Paths starting with a leading slash automatically resolve directly to the root of the Dart package. Use this when the destination file is deep.
    *   *Example:* `{@example /test/data/sample.txt}` exactly maps to `<package_root>/test/data/sample.txt`.
*   **Relative Paths**: Paths without a leading slash resolve relative to the directory of the file containing the doc comment.
    *   *Example:* `{@example ../utils/demo.dart}`
*   **Boundary Enforcement:** Using `..` segments to traverse upward is perfectly acceptable, but dartdoc natively stops directory traversal at the package root (it will never escape the package).
*   **No Network URLs:** Absolute URIs (e.g., starting with `https://`) are strictly not supported. The example file *must* sit natively somewhere in the local filesystem.
*   **Separators & Encoding:** Because dartdoc resolves the path as a URI, you must always use forward slashes (`/`) as folder separators (even on Windows). You can natively include URI-encoded characters (like `%20` for spaces) as permitted by URI reference rules.

## 6. Verification
After injecting examples:
1.  Run `dart analyze` on the example files to ensure the hidden setup code compiles.
2.  (Optional) Run `dart doc` to verify that dartdoc successfully parsed the directive without throwing a "Failed to read file" or "missing region" warning.
