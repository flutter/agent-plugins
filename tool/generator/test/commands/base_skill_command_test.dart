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

  int runSkillCalls = 0;

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
  }) async {
    runSkillCalls++;
  }
}

void main() {
  group('BaseSkillCommand Edge Cases', () {
    late CommandRunner<void> runner;
    late Directory tempDir;
    late MockClient mockClient;
    final logs = <String>[];
    final records = <LogRecord>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'base_skill_commands_test',
      );
      mockClient = MockClient((request) async => throw UnimplementedError());
      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(_TestSkillCommand(httpClient: mockClient));

      Logger.root.level = Level.INFO;
      final sub = Logger.root.onRecord.listen((record) {
        logs.add(record.message);
        records.add(record);
      });
      addTearDown(sub.cancel);
      logs.clear();
      records.clear();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
      logs.clear();
      records.clear();
    });

    test('logs severe error when configuration file not found', () async {
      final path = p.join(tempDir.path, 'missing.yaml');
      await IOOverrides.runZoned(() async {
        await runner.run(['test-command', path]);
      }, getCurrentDirectory: () => tempDir);

      expect(logs, contains('Configuration file not found: $path'));
    });

    test(
      'logs severe error when YAML syntax or item schema is invalid',
      () async {
        final invalidYamlFile = File(p.join(tempDir.path, 'invalid.yaml'));
        await invalidYamlFile.writeAsString(': invalid: [yaml');
        await runner.run(['test-command', invalidYamlFile.path]);
        expect(logs, contains(contains('Invalid YAML syntax in')));

        logs.clear();
        final nonMapItemFile = File(p.join(tempDir.path, 'non_map.yaml'));
        await nonMapItemFile.writeAsString(jsonEncode([123]));
        await runner.run(['test-command', nonMapItemFile.path]);
        expect(logs, contains('Invalid configuration: Item 0 is not a Map.'));

        logs.clear();
        final badMapItemFile = File(p.join(tempDir.path, 'bad_map.yaml'));
        await badMapItemFile.writeAsString(
          jsonEncode([
            {'name': 'foo', 'description': 123, 'resources': <String>[]},
          ]),
        );
        await runner.run(['test-command', badMapItemFile.path]);
        expect(
          logs,
          contains(
            'Invalid configuration at item 0: '
            'Skill "foo" field "description" must be a string.',
          ),
        );
      },
    );

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

    test(
      'logs severe error when GEMINI_API_KEY is missing or blank unless --dry-run',
      () async {
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

        final missingKeyCommand = _TestSkillCommand(
          httpClient: mockClient,
          environment: {},
        );
        runner = CommandRunner<void>('skills', 'Test runner')
          ..addCommand(missingKeyCommand);
        await runner.run(['test-command', configFile.path]);
        expect(logs, contains('GEMINI_API_KEY environment variable not set.'));
        expect(missingKeyCommand.runSkillCalls, 0);

        logs.clear();
        await runner.run(['test-command', '--dry-run', configFile.path]);
        expect(
          logs,
          isNot(contains('GEMINI_API_KEY environment variable not set.')),
        );
        expect(missingKeyCommand.runSkillCalls, 1);

        logs.clear();
        final blankKeyCommand = _TestSkillCommand(
          httpClient: mockClient,
          environment: {'GEMINI_API_KEY': '   '},
        );
        runner = CommandRunner<void>('skills', 'Test runner')
          ..addCommand(blankKeyCommand);
        await runner.run(['test-command', configFile.path]);
        expect(logs, contains('GEMINI_API_KEY environment variable not set.'));
        expect(blankKeyCommand.runSkillCalls, 0);
      },
    );

    test('logs severe error when --thinking-budget is invalid', () async {
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

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          _TestSkillCommand(
            httpClient: mockClient,
            environment: {'GEMINI_API_KEY': 'test-key'},
          ),
        );

      await runner.run([
        'test-command',
        configFile.path,
        '--thinking-budget',
        '-1',
      ]);
      expect(
        records.any(
          (r) =>
              r.level == Level.SEVERE &&
              r.message.contains('Invalid thinking-budget: -1. Skipping.'),
        ),
        isTrue,
      );
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
