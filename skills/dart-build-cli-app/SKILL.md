---
name: dart-build-cli-app
description: Entrypoint structure, exit codes, cross-platform scripts. Use when building command line utilities, scripts, or applications.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 04 May 2026 17:41:00 GMT
---
# Building Dart CLI Applications

## Contents
- [Project Setup & Architecture](#project-setup--architecture)
- [Argument Parsing & Command Routing](#argument-parsing--command-routing)
- [Execution & Error Handling](#execution--error-handling)
- [Testing CLI Applications](#testing-cli-applications)
- [Compilation & Distribution](#compilation--distribution)
- [Workflows](#workflows)
- [Examples](#examples)

## Project Setup & Architecture

Initialize new CLI projects using the official Dart template to ensure standard directory structures.

*   Run `dart create -t cli <project_name>` to scaffold a console application with basic argument parsing.
*   Place executable entry points (files containing `main()`) exclusively in the `bin/` directory.
*   Place internal implementation logic in `lib/src/` and expose public APIs via `lib/<project_name>.dart`.
*   Enforce formatting in CI environments by running `dart format . --set-exit-if-changed`. This returns exit code 1 if formatting violations exist.

## Argument Parsing & Command Routing

Import the `args` package to manage command-line arguments, flags, and subcommands.

*   If building a simple script: Use `ArgParser` directly to define flags (`addFlag`) and options (`addOption`).
*   If building a complex, multi-command CLI (like `git`): Implement `CommandRunner` and extend `Command` for each subcommand.
*   Define global arguments on the `CommandRunner.argParser` and command-specific arguments on the individual `Command.argParser`.
*   Catch `UsageException` to gracefully handle invalid arguments and display the automatically generated help text.
*   **Validate Help Text Accuracy**: Ensure the help text provides all necessary information to run the tool. If the help text references a compiled executable name, and the user needs to add it to their PATH to run it that way, provide clear instructions on how to do so in the help text or description.

## Execution & Error Handling

Leverage the `io` and `stack_trace` packages to build robust, production-ready CLI tools.

*   Use the `io` package's `ExitCode` enum to return standard POSIX exit codes (e.g., `ExitCode.success.code`, `ExitCode.usage.code`).
*   Use `sharedStdIn` from the `io` package if multiple asynchronous listeners need sequential access to standard input.
*   Wrap the application execution in `Chain.capture()` from the `stack_trace` package to track asynchronous stack chains.
*   Format output stack traces using `Trace.terse` or `Chain.terse` to strip noisy core library frames and present readable errors to the user.
*   **Do not swallow exceptions** in lower-level logic or storage classes unless recovery is possible. Let them bubble up or rethrow them so higher-level commands know operations failed.
*   **Fail fast and with non-zero exit codes**: Ensure operation failures result in descriptive error messages to `stderr` and appropriate non-zero exit codes (e.g., using `exit(1)` or triggering a 64 exit code after a caught `UsageException`).

## Testing CLI Applications

> [!IMPORTANT]
> **All new commands and significant features must be covered by automated tests.** Manual verification is not sufficient for testing logic. However, manual verification of help text and user experience (UX) is still required to ensure the interface is intuitive and correct.

Use `test_process` and `test_descriptor` to write high-fidelity integration tests for your CLI.

*   Define expected filesystem states using `test_descriptor` (`d.dir`, `d.file`).
*   Create the mock filesystem before execution using `await d.Descriptor.create()`.
*   Spawn the CLI process using `TestProcess.start('dart', ['run', 'bin/cli.dart', ...args])`.
*   Validate standard output and error streams using `StreamQueue` matchers (e.g., `emitsThrough`, `emits`).
*   Assert the final exit code using `await process.shouldExit(0)`.
*   Validate resulting filesystem mutations using `await d.Descriptor.validate()`.

## Compilation & Distribution

Select the appropriate compilation target based on your distribution requirements.

*   **If testing locally during development:** Use `dart run bin/cli.dart`. This uses the JIT compiler for rapid iteration.
*   **If bundling code assets and dynamic libraries:** Use `dart build cli`. This runs build hooks and outputs to `build/cli/_/bundle/`.
*   **If distributing a standalone native executable:** Use `dart compile exe bin/cli.dart -o <output_path>`. This bundles the Dart runtime and machine code into a single file.
*   **If distributing multiple apps with strict disk space limits:** Use `dart compile aot-snapshot bin/cli.dart`. Run the resulting `.aot` file using `dartaotruntime`.

<details>
<summary>Cross-Compilation Targets (Linux Only)</summary>

Dart supports cross-compiling to Linux from macOS, Windows, or Linux hosts.
Use the `--target-os` and `--target-arch` flags with `dart compile exe` or `dart compile aot-snapshot`.

*   `--target-os=linux` (Only Linux is currently supported as a cross-compilation target)
*   `--target-arch=arm64` (64-bit ARM)
*   `--target-arch=x64` (x86-64)
*   `--target-arch=arm` (32-bit ARM)
*   `--target-arch=riscv64` (64-bit RISC-V)

Example: `dart compile exe --target-os=linux --target-arch=arm64 bin/cli.dart`
</details>

## Workflows

### Task Progress: Implement a New CLI Command
- [ ] Create a new class extending `Command` in `lib/src/commands/`.
- [ ] Define the `name` and `description` properties.
- [ ] Register command-specific flags in the constructor using `argParser.addFlag()` or `argParser.addOption()`.
- [ ] Implement the `run()` method with the core logic.
- [ ] Register the new command in the `CommandRunner` instance in `bin/cli.dart` using `addCommand()`.
- [ ] Create tests for the new command in the `test/` directory using `test_process` or standard tests.
- [ ] Run validator -> Execute `dart run bin/cli.dart help <command_name>` to verify help text generation.
- [ ] Verify final UX: Compile the application using `dart compile exe` and run the resulting executable to verify the target user experience (e.g., `./bin/cli <command>`).

### Task Progress: Compile and Release Native Executable
- [ ] Run validator -> Execute `dart format . --set-exit-if-changed` to ensure code formatting.
- [ ] Run validator -> Execute `dart analyze` to ensure no static analysis errors.
- [ ] Run validator -> Execute `dart test` to pass all integration tests.
- [ ] Compile for host OS: `dart compile exe bin/cli.dart -o build/cli-host`
- [ ] Compile for Linux (if host is macOS/Windows): `dart compile exe --target-os=linux --target-arch=x64 bin/cli.dart -o build/cli-linux-x64`

## Examples

### Example: CommandRunner Implementation

```dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:stack_trace/stack_trace.dart';

class CommitCommand extends Command {
  @override
  final String name = 'commit';
  @override
  final String description = 'Record changes to the repository.';

  CommitCommand() {
    argParser.addFlag('all', abbr: 'a', help: 'Commit all changed files.');
  }

  @override
  Future<void> run() async {
    final commitAll = argResults?['all'] as bool? ?? false;
    print('Committing... (All: $commitAll)');
  }
}

void main(List<String> args) {
  Chain.capture(() async {
    final runner = CommandRunner('dgit', 'Distributed version control.')
      ..addCommand(CommitCommand());

    await runner.run(args);
  }, onError: (error, chain) {
    if (error is UsageException) {
      stderr.writeln(error.message);
      stderr.writeln(error.usage);
      exit(64); // ExitCode.usage.code
    } else {
      stderr.writeln('Fatal error: $error');
      stderr.writeln(chain.terse);
      exit(1);
    }
  });
}
```

### Example: Integration Testing with Subprocesses

```dart
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test('CLI formats output correctly and modifies filesystem', () async {
    // 1. Setup mock filesystem
    await d.dir('project', [
      d.file('config.json', '{"key": "value"}')
    ]).create();

    // 2. Spawn the CLI process
    final process = await TestProcess.start(
      'dart',
      ['run', 'bin/cli.dart', 'process', '--path', '${d.sandbox}/project']
    );

    // 3. Validate stdout stream
    await expectLater(process.stdout, emitsThrough('Processing complete.'));

    // 4. Validate exit code
    await process.shouldExit(0);

    // 5. Validate filesystem mutations
    await d.dir('project', [
      d.file('config.json', '{"key": "value"}'),
      d.file('output.log', 'Success')
    ]).validate();
  });
}
```
