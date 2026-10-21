// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills/src/commands/base_skill_command.dart';
import 'package:skills/src/models/skill_params.dart';
import 'package:skills/src/services/gemini_service.dart';
import 'package:test/test.dart';

class _TestSkillCommand extends BaseSkillCommand {
  _TestSkillCommand({required super.httpClient, super.environment})
    : super(logger: Logger('_TestSkillCommand'));

  @override
  String get name => 'test-command';

  @override
  String get description => 'Description';

  @override
  Future<void> runSkill(
    SkillParams skill,
    GeminiService gemini,
    Directory outputDir,
    int thinkingBudget, {
    Directory? configDir,
  }) async {}
}

void main() {
  group('BaseSkillCommand Edge Cases', () {
    late CommandRunner<void> runner;
    late Directory tempDir;
    late MockClient mockClient;
    final logs = <String>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'base_skill_commands_test',
      );
      mockClient = MockClient((request) async => throw UnimplementedError());
      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(_TestSkillCommand(httpClient: mockClient));

      Logger.root.level = Level.INFO;
      Logger.root.onRecord.listen((record) => logs.add(record.message));
      logs.clear();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
      logs.clear();
    });

    test('logs severe error when configuration file not found', () async {
      final path = p.join(tempDir.path, 'missing.yaml');
      await IOOverrides.runZoned(() async {
        await runner.run(['test-command', path]);
      }, getCurrentDirectory: () => tempDir);

      expect(logs, contains('Configuration file not found: $path'));
    });

    test('logs warning when no skills match the --skill filter', () async {
      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode(<Map<String, dynamic>>[
          {
            'name': 'existent-skill',
            'description': 'desc',
            'resources': <String>[],
          },
        ]),
      );

      await IOOverrides.runZoned(() async {
        await runner.run([
          'test-command',
          configFile.path,
          '--skill',
          'non-existent',
        ]);
      }, getCurrentDirectory: () => tempDir);

      expect(logs, contains('No skill found with name: non-existent'));
    });

    test('logs warning when configuration file contains no skills', () async {
      final configFile = File(p.join(tempDir.path, 'empty.yaml'));
      await configFile.writeAsString('[]');

      await IOOverrides.runZoned(() async {
        await runner.run(['test-command', configFile.path]);
      }, getCurrentDirectory: () => tempDir);

      expect(logs, contains('No skills found in configuration file.'));
    });

    test('logs severe error when GEMINI_API_KEY is not set', () async {
      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode(<Map<String, dynamic>>[
          {
            'name': 'existent-skill',
            'description': 'desc',
            'resources': <String>[],
          },
        ]),
      );

      // Override environment parameter to simulate missing api key
      runner = CommandRunner(
        'skills',
        'Test runner',
      )..addCommand(_TestSkillCommand(httpClient: mockClient, environment: {}));

      await IOOverrides.runZoned(() async {
        await runner.run(['test-command', configFile.path]);
      }, getCurrentDirectory: () => tempDir);

      expect(logs, contains('GEMINI_API_KEY environment variable not set.'));
    });

    test('defines model option defaulting to GeminiService.defaultModel', () {
      final command = _TestSkillCommand(httpClient: mockClient);
      expect(command.argParser.options.containsKey('model'), isTrue);
      expect(
        command.argParser.options['model']!.defaultsTo,
        GeminiService.defaultModel,
      );
    });
  });
}
