# Dart SDK Discovery and Subprocess Spawning in AOT & JIT

Guidance on locating the Dart SDK and spawning Dart child processes across JIT (`dart run`, `pub global activate`) and standalone AOT (`dart compile exe`, `dart install`) execution modes.

---

## 1. The AOT SDK Discovery Trap

When writing CLI developer tools that spawn `dart` child processes (e.g. running `build_runner`, `dart format`, `dart test`, or code analyzers), developers frequently write:

```dart
// ❌ WRONG: Breaks when compiled to AOT
final dart = Platform.resolvedExecutable;
final sdkDir = path.dirname(path.dirname(dart));
```

### Why This Fails in Standalone AOT:
* **JIT VM (`dart run`, `pub global activate`)**: `Platform.resolvedExecutable` points directly to `<dart-sdk>/bin/dart`. Calling `dirname(dirname(...))` resolves to the valid SDK root directory.
* **AOT Binary (`dart compile exe`, `dart install`)**: `Platform.resolvedExecutable` points to the compiled application binary (e.g. `~/.dart/install/app-bundles/my_cli/.../bin/my_cli`).

### Consequences of Naive Resolution:
1. **Recursive Subprocess Loop**: If the application executes `Platform.resolvedExecutable` expecting the `dart` VM, it spawns itself recursively.
2. **Flag Rejection Crash**: If the child process passes VM flags (such as `--observe`, `--enable-vm-service`) or tool subcommands (like `run`, `format`, or `test`), the compiled binary fails immediately with unknown option errors.
3. **Broken SDK Root**: Traversing parent directories from `Platform.resolvedExecutable` to locate SDK resources (such as `libraries.json`) fails because the binary resides in an application bundle directory rather than a Dart SDK installation.

---

## 2. The Solution: `package:cli_util` (`^0.6.0`)

Do not write bespoke SDK discovery probes. Depend on `package:cli_util` (version 0.6.0 or higher), which provides memoized, nullable getters (`dartExecutable` and `sdkPath`) that locate the Dart SDK across both JIT and AOT environments:

```dart
import 'dart:io' as io;
import 'package:cli_util/cli_util.dart' as cli_util;

Future<void> runSubprocess() async {
  // Resolves the dart executable across both JIT and AOT environments
  final dartExe = cli_util.dartExecutable;
  if (dartExe == null) {
    io.stderr.writeln('Error: Could not locate the Dart SDK on PATH.');
    io.exitCode = 1;
    return;
  }

  final result = await io.Process.run(dartExe, ['format', '.']);
  io.stdout.write(result.stdout);
  io.stderr.write(result.stderr);
}
```

### Potential Dart SDK Locations:
A valid Dart SDK and `dart` executable may reside in several environmental locations across different developer setups:
* **Running VM (`Platform.resolvedExecutable`)**: When running on the JIT VM (`dart run`), `resolvedExecutable` points directly to `<dart-sdk>/bin/dart`.
* **Explicit Environment (`DART_SDK`)**: Defined when a developer explicitly points `DART_SDK` to an SDK installation directory.
* **System `PATH`**: Resolved via system `PATH` entries (`dart`, `dart.exe`, or `dart.bat`), including dereferencing symlinks and checking `bin/cache/dart-sdk` for Flutter installations.
* **Flutter Root (`FLUTTER_ROOT`)**: Bundled under `FLUTTER_ROOT/bin/cache/dart-sdk`.

The exact search order and SDK directory validation logic should be delegated to `package:cli_util` rather than re-implemented in application code.

---

## 3. Subprocess Spawning Invariants

When executing child subprocesses from a Dart CLI:

1. **Always use `cli_util.dartExecutable`**: Never pass `Platform.executable` or `Platform.resolvedExecutable`.
2. **Fallback to `'dart'` on `PATH`**: If `package:cli_util` is not an option, execute the literal string `'dart'` directly via `Process.start('dart', [...], runInShell: Platform.isWindows)`.
3. **Windows Batch File Handling**: On Windows, Flutter installs `dart.bat` in `flutter/bin`. Invoking batch files directly via `Process.start` requires `runInShell: true` unless pointing to the resolved binary `dart.exe`.
