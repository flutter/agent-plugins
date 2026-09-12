# Signal Handling, Terminal Teardown, and Stream Resilience

Guidance on cross-platform signal listeners, restoring terminal modes, tearing down network resources, and handling broken pipes in Dart CLI applications.

---

## 1. Cross-Platform Signal Handling

Standard POSIX signals (`SIGINT`, `SIGTERM`) require platform-specific guards because Windows does not implement POSIX `SIGTERM`.

### The Windows `SIGTERM` Guard Rule:
Calling `ProcessSignal.sigterm.watch()` on Windows throws an unhandled `UnsupportedError`. Multi-platform signal handlers must always guard `sigterm`:

```dart
import 'dart:async';
import 'dart:io';
import 'package:async/async.dart';

/// Listens for process termination signals across Windows, macOS, and Linux.
Stream<ProcessSignal> watchTerminationSignals() {
  if (Platform.isWindows) {
    return ProcessSignal.sigint.watch();
  }
  return StreamGroup.merge([
    ProcessSignal.sigint.watch(),
    ProcessSignal.sigterm.watch(),
  ]);
}
```

---

## 2. Terminal Mode & Cursor Restoration

If your CLI mutates the terminal state (e.g., interactive menus, password input prompts, progress spinners):

### A. Raw Mode Teardown (`echoMode` & `lineMode`):
If setting `stdin.echoMode = false` or `stdin.lineMode = false`, install a signal handler to restore them upon user cancellation (`Ctrl+C` / `SIGINT`). Otherwise, the host shell remains in raw mode and user keystrokes become invisible after exit.

```dart
import 'dart:io';

void enableInteractiveMode() {
  // Defensive guard: only configure terminal modes if standard input is an interactive TTY.
  if (!stdin.hasTerminal) return;
  stdin.echoMode = false;
  stdin.lineMode = false;

  // Ensure terminal state is synchronously restored on Ctrl+C.
  final sub = ProcessSignal.sigint.watch().listen((_) {
    restoreTerminal();
    // Exiting with 128 + SIGINT (2) = 130 is the standard POSIX protocol
    // for asynchronous signal handlers to communicate signal interruption to the host shell.
    exit(130);
  });

  try {
    // Run interactive loop...
  } finally {
    sub.cancel();
    restoreTerminal();
  }
}

void restoreTerminal() {
  if (stdin.hasTerminal) {
    stdin.lineMode = true;
    stdin.echoMode = true;
  }
}
```

### B. Cursor Visibility (Spinners & Progress Bars):
If emitting ANSI escape code to hide the cursor (`\x1B[?25l`), always restore cursor visibility (`\x1B[?25h`) inside `finally` blocks and signal handlers:

```dart
void showCursor() {
  if (useAnsi) {
    stdout.write('\x1B[?25h');
  }
}

/// Canonical ANSI support check respecting NO_COLOR standards.
bool get useAnsi =>
    stdout.hasTerminal &&
    stdout.supportsAnsiEscapes &&
    !Platform.environment.containsKey('NO_COLOR');
```

---

## 3. Server Socket & Child Process Teardown

* **Listening Sockets**: If the CLI starts an `HttpServer` or TCP `ServerSocket`, listen for termination signals to close the socket immediately (`server.close(force: true)`) so the OS releases port bindings without waiting for kernel socket timeouts.
* **Child Processes**: When spawning long-running child processes, register a termination listener to forward signals (`childProcess.kill(ProcessSignal.sigterm)`) before the parent exits to prevent orphaned background processes.

---

## 4. Broken Pipe (`EPIPE` / `SocketException`) Handling

When piping CLI output to downstream commands that terminate early (e.g., `my_cli | head -n 5` or `my_cli | grep -q foo`), the downstream process closes the pipe. Subsequent writes to `stdout` throw `SocketException: Broken pipe (errno = 32)`.

Intercept broken pipe exceptions without printing noisy crash traces to `stderr`:

```dart
import 'dart:io';

Future<void> safeWriteln(String line) async {
  try {
    stdout.writeln(line);
  } on SocketException catch (e) {
    // EPIPE / Broken pipe: downstream closed standard input.
    if (e.osError?.errorCode == 32 || e.message.contains('Broken pipe')) {
      await stdout.close().catchError((_) {});
      // In a bulk streaming context, calling exit(0) immediately stops the
      // producer loop when downstream has closed its pipe.
      exit(0);
    }
    rethrow;
  }
}
```
