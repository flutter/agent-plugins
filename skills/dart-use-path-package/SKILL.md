---
name: dart-use-path-package
description: >-
  Cross-platform file and directory path manipulation, segment splitting, extension extraction, and context conversion using `package:path` and `package:file`. Use when writing, inspecting, joining, splitting, or refactoring file paths, directory names, or extensions, or replacing raw string path operations (`.split('/')`, `'$dir/$file'`, `.endsWith('.ext')`, `.replaceAll('\\', '/')`). Don't use for HTTP network URI routing, database query strings, or non-path string processing.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Sun, 06 Sep 2026 07:14:00 GMT
---

# Safe Cross-Platform Path Manipulation in Dart

## Contents
* [1. Core Principles & Cross-Platform Rules](#1-core-principles--cross-platform-rules)
* [2. Recommended package:path Idioms vs. String Anti-Patterns](#2-recommended-packagepath-idioms-vs-string-anti-patterns)
* [3. Bridging Native Paths to POSIX, Git, & URL Contexts](#3-bridging-native-paths-to-posix-git--url-contexts)
* [4. Mockable File Systems (`package:file` vs. Global `p.*`)](#4-mockable-file-systems-packagefile-vs-global-p)
* [5. Extensions, Compound Extensions & Stem Extraction](#5-extensions-compound-extensions--stem-extraction)
* [6. Workflows & Audit Checklist](#6-workflows--audit-checklist)
* [References & Examples](#references--examples)

---

## 1. Core Principles & Cross-Platform Rules

### Avoid Treating File Paths as Raw Strings
* Native file paths on Windows use backslashes (`\`), whereas macOS and Linux use forward slashes (`/`).
* String operations like `.contains('foo/')`, `.startsWith('foo/')`, or `.split('/')` silently fail on Windows native paths.
* String interpolation like `'$dir/$file'` injects forward slashes on Windows and produces duplicate slashes (`//`) when `$dir` ends with a trailing slash.

**Rule**: Always decompose paths into segments using `p.split(path)` before inspecting directory hierarchy or segment names, and always join path components using `p.join(...)`.

### Pragmatic Boundary Joining vs. Multi-Segment Decomposition (`p.join`)
* **Cross-Platform Libraries (Windows + POSIX)**: Pass individual path segments to `p.join(dir, 'sub', 'file.json')` so `package:path` inserts OS-native separators (`\` on Windows, `/` on POSIX) between every component.
* **POSIX-Only Tools & Static Subpath Greppability**: In codebases exclusively targeting Linux/macOS (or when joining a dynamic base path to a known static subpath), decomposing 5–6 static segments into separate arguments (`p.join(home, '.local', 'share', 'app', 'bin', 'config.json')`) causes `dart format` to wrap across 6–8 vertical lines and **destroys substring greppability** (`grep` / `code_search` for `.local/share/app/bin`).
* **Rule for POSIX Targets**: Prefer **2-argument boundary joining** (`p.join(home, '.local/share/app/bin/config.json')`). This prevents duplicate-slash bugs (`//`) at variable boundaries while preserving single-line readability and exact string searchability.

### Normalization vs. Canonicalization (`p.normalize` vs. `p.canonicalize`)
* `p.normalize(path)` resolves `.` and `..` segments purely lexically without consulting the filesystem or standardizing case.
* When deduplicating directory paths or comparing physical file identity across symlinks, relative roots, or case-insensitive filesystems, use `p.canonicalize(path)`.

### Strip Location Specifiers & Convert URIs Safely
* Strings formatted as `<path>:<line>-<col>` or `<path>:<line>` are not pure file paths. Passing them directly to `p.normalize` or `Uri.parse` causes bugs (on Windows, `Uri.parse` mistakes `C:` for a URI scheme and `:line` for a port).
* Extract the trailing `:line-col` suffix via regular expression (`RegExp(r'^(.*?):(\d+(?:-\d+)?)$')`) *before* passing the file path to `package:path`.
* **URI Boundary Conversions**: When converting between file paths and `Uri` objects, always use `p.toUri(path)` and `p.fromUri(uri)` rather than `Uri.parse(path)` or manual string concatenation.

---

## 2. Recommended package:path Idioms vs. String Anti-Patterns

### Path Joining
* **Prefer**: `p.join(dir, file)`
* **Avoid**: `'$dir/$file'` or `'a/$b'`
* **Why**: String interpolation injects `/` on Windows and creates duplicate
  slashes (`//`) when `$dir` ends with a trailing separator.

### Segment Matching
* **Prefer**: `p.split(path).contains('foo')`
* **Avoid**: `path.contains('foo/')`
* **Why**: String matching fails on Windows backslashes (`foo\bar`) and produces
  false positives on partial substring names (e.g. `barfoo/`).

### Root and Directory Prefixes
* **Prefer**: `p.split(path).first == 'foo'` or `p.isWithin('foo', path)`
* **Avoid**: `path.startsWith('foo/')`
* **Why**: Fails on Windows separators and misses relative prefix variants such
  as `./foo/`.

### File Extensions
* **Prefer**: `p.extension(path) == '.wasm'`
* **Avoid**: `path.endsWith('.wasm')`
* **Why**: Substring suffix matching falsely matches directories (`foo.wasm/`)
  or non-extension suffixes.

### Extension Slicing and Compound Extensions
* **Prefer**: `p.withoutExtension(path)` and `p.extension(path, 2)`
* **Avoid**: `path.lastIndexOf('.')` and manual `substring` slicing
* **Why**: Manual arithmetic breaks on hidden dotfiles (`.gitignore`) and
  compound extensions (`.js.map`, `.tar.gz`).

### POSIX and URL Path Conversion
* **Prefer**: `p.posix.joinAll(p.split(path))` or `p.url.joinAll(p.split(path))`
* **Avoid**: `path.replaceAll(r'\', '/')`
* **Why**: Ad-hoc separator replacement fails on root drives and mixes OS
  context with POSIX or URL targets.

### URI Conversion
* **Prefer**: `p.toUri(path)` and `p.fromUri(uri)`
* **Avoid**: `Uri.parse(path)` and `uri.path`
* **Why**: Direct URI parsing fails on Windows drive letters (`C:`) and leaks
  percent-encoding (e.g. `%20` for spaces).

### Directory Basename Helper
* **Prefer**:
  `String canonicalDirName(Directory d) => p.basename(p.normalize(d.absolute.path));`
* **Avoid**: Repeating `p.basename(p.normalize(dir.absolute.path))` inline
  across files.
* **Why**: Centralizes canonical directory naming logic and reduces boilerplate.

---

## 3. Bridging Native Paths to POSIX, Git, & URL Contexts

Avoid calling `.replaceAll('\\', '/')` or `.replaceAll(r'\', '/')` to convert
OS-native paths into POSIX paths (for Git, YAML, archive manifests) or URL
segments.

**Rule**: Split the relative native path using `p.split(...)`, inspect segments
with **Dart 3 list pattern matching**, and join using `p.posix.joinAll(...)` or
`p.url.joinAll(...)`. Always call `p.relative(filePath, from: root)` first so
leading root segments (`'/'` on POSIX or `r'C:\'` on Windows) do not interfere
with relative prefix patterns:

```dart
import 'package:path/path.dart' as p;

String computeWebAssetKey(String filePath, String projectRoot) {
  final relative = p.relative(filePath, from: projectRoot);
  final segments = p.split(relative);
  return switch (segments) {
    ['assets', ...] => p.posix.joinAll(segments),
    _ => p.posix.joinAll(['assets', ...segments]),
  };
}
```

### Git Paths and Repository Metadata
* Git repository tree objects, `.gitignore` pattern rules, `.gitattributes`,
  and git-tracked symlinks strictly use POSIX forward slashes (`/`), even on
  Windows.
* Inserting native Windows backslashes (`\`) into `.gitignore` or git commands
  causes Git to treat `\` as an escape character rather than a directory
  separator, silently breaking pattern matching.
* When generating `.gitignore` entries, repository manifests, or symlink
  targets programmatically from native file paths, convert the relative native
  path using `p.posix.joinAll(p.split(relativePath))` or `p.posix.join(...)`.

---

## 4. Mockable File Systems (`package:file` vs. Global `p.*`)

In codebases that use `package:file` (e.g., CLI applications or services tested
with `MemoryFileSystem`), avoid calling top-level `p.*` functions on `File` or
`Directory` paths.

* Top-level `p.*` functions bind to the *host operating system* running the test.
* If a unit test creates a `MemoryFileSystem(style: FileSystemStyle.windows)` on a Linux or macOS runner, global `p.split(file.path)` will split on `/` instead of `\`, breaking the test.

**Rule**: Always use the `Context` attached to the `FileSystem` (`file.fileSystem.path`):

```dart
import 'package:file/file.dart';

List<String> listSubdirectoryNames(Directory dir) {
  final pathContext = dir.fileSystem.path;
  return dir
      .listSync()
      .whereType<Directory>()
      .map((d) => pathContext.basename(d.path))
      .toList();
}
```

---

## 5. Extensions, Compound Extensions & Stem Extraction

Avoid manual `.lastIndexOf('.')` and `.substring()` arithmetic when extracting file extensions or inserting content hashes. `p.extension` natively supports multi-level extensions via its optional `level` parameter.

* **Multi-Dot Stem Nuance**: Calling `p.extension('main.dart.wasm', 2)` returns `'.dart.wasm'` because it blindly captures the last two dot-separated segments. When hashing or stripping extensions on files that may have multi-dot stems (e.g., `main.dart.wasm` vs. `main.dart.js.map`), check whether `p.extension(filename, 2)` matches a known compound extension (or `.endsWith('.map')`) before falling back to single-level `p.extension(filename)`:

```dart
import 'package:path/path.dart' as p;

String insertContentHash(String filename, String hash) {
  final compoundExt = p.extension(filename, 2);
  // Only use the 2-level extension for true compound suffixes (e.g., '.js.map')
  final ext = compoundExt.endsWith('.map')
      ? compoundExt
      : p.extension(filename);
  final stem = filename.substring(0, filename.length - ext.length);
  return '$stem.$hash$ext';
}
```

---

## 6. Workflows & Audit Checklist

### Path Refactoring Checklist
- [ ] Replace string interpolation (`'$dir/$file'`) with `p.join(dir, file)`.
- [ ] Replace `.contains('dir/')` and `.startsWith('dir/')` with `p.split(path)` segment checks or `p.isWithin(parent, child)`.
- [ ] Replace `.replaceAll(r'\', '/')` with `p.posix.joinAll(p.split(path))` (or `p.url.joinAll`).
- [ ] Replace `.endsWith('.ext')` on file paths with `p.extension(path) == '.ext'`.
- [ ] Replace manual dot-index slicing with `p.withoutExtension(path)` and `p.extension(path, [level])`.
- [ ] Verify that code using `package:file` accesses `fileSystem.path` instead of global `p.*`.
- [ ] Ensure Git paths, `.gitignore` entries, and symlink targets use `p.posix` forward slashes.

---

## References & Examples

* **Cross-Platform Path & POSIX Conversion Examples**: [examples/cross_platform_paths.dart](examples/cross_platform_paths.dart)
* **Mockable FileSystem Path Context Example**: [examples/file_system_context.dart](examples/file_system_context.dart)
