import 'dart:async';
import 'dart:io';
import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  test('Run skills linter mirroring config', () async {
    final Level oldLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final StreamSubscription<LogRecord> subscription = Logger.root.onRecord.listen(
      (record) => stdout.writeln(record.message),
    );

    try {
      // Load configuration from the default file (dart_skills_lint.yaml)
      // to mirror what is configured in the repository.
      final Configuration config = await ConfigParser.loadConfig();

      final bool isValid = await validateSkills(config: config);
      expect(isValid, isTrue, reason: 'Skills validation failed. See above for details.');
    } finally {
      Logger.root.level = oldLevel;
      await subscription.cancel();
    }
  });
}
