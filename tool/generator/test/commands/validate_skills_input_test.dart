// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills/src/commands/validate_skill_command.dart';
import 'package:test/test.dart';

void main() {
  group('ValidateSkillCommand Input Validation', () {
    late CommandRunner<void> runner;
    late Directory tempDir;
    late MockClient mockClient;
    final logs = <String>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'validate_skills_input_test',
      );
      mockClient = MockClient((request) async => http.Response('', 200));

      Logger.root.level = Level.INFO;
      Logger.root.onRecord.listen((record) {
        logs.add(record.message);
      });
      logs.clear();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
      logs.clear();
    });

    Future<void> runValidation(String filename, String content) async {
      final configFile = File(p.join(tempDir.path, filename));
      await configFile.writeAsString(content);

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: tempDir,
            httpClient: mockClient,
          ),
        );

      await IOOverrides.runZoned(() async {
        await runner.run(['validate-skill', configFile.path]);
      }, getCurrentDirectory: () => tempDir);
    }

    test('passes when configuration is perfectly valid', () async {
      final content = jsonEncode([
        {
          'name': 'flutter-test-skill',
          'description': 'A Flutter test skill',
          'resources': ['https://example.com/doc'],
        },
      ]);

      await runValidation('flutter_skills.yaml', content);
      expect(logs, isNot(contains('Configuration validation failed.')));
    });

    test('fails when root structure is not a list', () async {
      final content = jsonEncode({'name': 'flutter-test-skill'});

      await runValidation('flutter_skills.yaml', content);
      expect(
        logs,
        contains('Invalid configuration: Root must be a YAML list.'),
      );
    });

    test('fails when configuration list is empty', () async {
      final content = jsonEncode([]);

      await runValidation('flutter_skills.yaml', content);
      expect(logs, contains('Configuration list must not be empty.'));
    });

    test('fails when item is not a map', () async {
      final content = jsonEncode(['just-a-string-not-a-map']);

      await runValidation('flutter_skills.yaml', content);
      expect(logs, contains('Item 0 is not a Map.'));
      expect(logs, contains('Configuration validation failed.'));
    });

    test('fails when fields are missing', () async {
      final content = jsonEncode([
        {'name': 'flutter-skill'},
      ]);

      await runValidation('flutter_skills.yaml', content);
      expect(
        logs,
        contains(
          'Skill "flutter-skill" is missing required field "description".',
        ),
      );
      expect(
        logs,
        contains(
          'Skill "flutter-skill" is missing required field "resources".',
        ),
      );
      expect(logs, contains('Configuration validation failed.'));
    });

    test('fails when skill name is not kabob-case', () async {
      final content = jsonEncode([
        {
          'name': 'flutter_skill_invalid',
          'description': 'A Flutter skill description',
          'resources': ['https://example.com'],
        },
      ]);

      await runValidation('flutter_skills.yaml', content);
      expect(
        logs,
        contains(
          'Skill name "flutter_skill_invalid" must be kabob-case (e.g. abc-def).',
        ),
      );
      expect(logs, contains('Configuration validation failed.'));
    });

    test(
      'fails when flutter_skills.yaml name or description conventions are violated',
      () async {
        final content = jsonEncode([
          {
            'name': 'dart-skill',
            'description': 'A skill description with no framework keyword',
            'resources': ['https://example.com'],
          },
        ]);

        await runValidation('flutter_skills.yaml', content);
        expect(
          logs,
          contains(
            'Skill name "dart-skill" in flutter_skills.yaml must start with "flutter-".',
          ),
        );
        expect(logs, contains('Configuration validation failed.'));
      },
    );

    test(
      'fails when dart_skills.yaml name or description conventions are violated',
      () async {
        final content = jsonEncode([
          {
            'name': 'flutter-skill',
            'description': 'A skill description with no language keyword',
            'resources': ['https://example.com'],
          },
        ]);

        await runValidation('dart_skills.yaml', content);
        expect(
          logs,
          contains(
            'Skill name "flutter-skill" in dart_skills.yaml must start with "dart-".',
          ),
        );
        expect(logs, contains('Configuration validation failed.'));
      },
    );

    test('fails when resources list is empty', () async {
      final content = jsonEncode([
        {
          'name': 'flutter-skill',
          'description': 'A Flutter skill description',
          'resources': <dynamic>[],
        },
      ]);

      await runValidation('flutter_skills.yaml', content);
      expect(
        logs,
        contains('Skill "flutter-skill" field "resources" must not be empty.'),
      );
      expect(logs, contains('Configuration validation failed.'));
    });

    test('fails when resource URL uses insecure HTTP protocol', () async {
      final content = jsonEncode([
        {
          'name': 'flutter-skill',
          'description': 'A Flutter skill description',
          'resources': ['http://example.com/insecure'],
        },
      ]);

      await runValidation('flutter_skills.yaml', content);
      expect(
        logs,
        contains(
          'Skill "flutter-skill" resource URL "http://example.com/insecure" must use secure HTTPS.',
        ),
      );
      expect(logs, contains('Configuration validation failed.'));
    });

    test('fails when fields have invalid types', () async {
      final content1 = jsonEncode([
        {
          'name': 12345, // int, should be string
          'description': 'A Flutter skill description',
          'resources': ['https://example.com'],
        },
      ]);

      await runValidation('flutter_skills.yaml', content1);
      expect(logs, contains('Item 0 field "name" must be a string.'));

      logs.clear();
      final content2 = jsonEncode([
        {
          'name': 'flutter-skill',
          'description': true, // bool, should be string
          'resources': ['https://example.com'],
        },
      ]);

      await runValidation('flutter_skills.yaml', content2);
      expect(
        logs,
        contains('Skill "flutter-skill" field "description" must be a string.'),
      );

      logs.clear();
      final content3 = jsonEncode([
        {
          'name': 'flutter-skill',
          'description': 'A Flutter skill description',
          'resources': ['https://example.com'],
          'instructions': 999, // int, should be string
        },
      ]);

      await runValidation('flutter_skills.yaml', content3);
      expect(
        logs,
        contains(
          'Skill "flutter-skill" field "instructions" must be a string.',
        ),
      );
    });
  });
}
