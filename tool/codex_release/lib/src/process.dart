import 'dart:io';

/// Runs external commands. Tests substitute a fake.
abstract class ProcessRunner {
  /// Runs [executable] with [arguments] and returns its result.
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });

  /// Runs [executable] with its output streamed to the terminal, and returns
  /// its exit code.
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });
}

/// Runs commands with `dart:io`.
class IoProcessRunner implements ProcessRunner {
  const IoProcessRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) => Process.run(executable, arguments, workingDirectory: workingDirectory);

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}

/// Thrown when a command fails.
class CommandException implements Exception {
  CommandException(this.command, this.result);

  /// The command line that failed.
  final String command;

  /// The failed command's result.
  final ProcessResult result;

  @override
  String toString() {
    final stderr = (result.stderr as String).trim();
    return '`$command` failed with exit code ${result.exitCode}'
        '${stderr.isEmpty ? '' : ':\n$stderr'}';
  }
}

/// Runs git commands in a repository.
class Git {
  Git(this.root, {this.runner = const IoProcessRunner()});

  /// The repository root.
  final String root;

  /// Runs the commands.
  final ProcessRunner runner;

  /// Runs `git <args>` and returns trimmed stdout, throwing on failure.
  Future<String> call(List<String> args) async {
    final result = await runner.run('git', args, workingDirectory: root);
    if (result.exitCode != 0) {
      throw CommandException('git ${args.join(' ')}', result);
    }
    return (result.stdout as String).trim();
  }

  /// Runs `git <args>` and returns whether it exited with 0.
  Future<bool> succeeds(List<String> args) async {
    final result = await runner.run('git', args, workingDirectory: root);
    return result.exitCode == 0;
  }

  /// Files tracked by git under [path], relative to [root].
  Future<List<String>> trackedFiles(String path) async {
    final output = await call(['ls-files', '-z', '--', path]);
    return output.split('\u0000').where((p) => p.isNotEmpty).toList()..sort();
  }
}
