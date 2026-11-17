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
import 'package:skills/src/commands/update_skill_command.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateSkillCommand', () {
    late CommandRunner<void> runner;
    late Directory tempDir;
    late File inputYamlFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('skills_update_test');
      inputYamlFile = File(p.join(tempDir.path, 'dart_dev.yaml'));
      runner = CommandRunner<void>('skills', 'Test runner');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('updates skill from YAML input preserving existing content', () async {
      final inputData = [
        {
          'name': 'foo',
          'description': 'Foo description',
          'resources': ['https://example.com/foo.html'],
        },
      ];
      inputYamlFile.writeAsStringSync(jsonEncode(inputData));

      // Create existing skill
      final skillDirFoo = Directory(p.join(tempDir.path, 'foo'))..createSync();
      final skillFile = File(p.join(skillDirFoo.path, 'SKILL.md'))
        ..writeAsStringSync('# Existing Content\n');

      final geminiRequests = <String>[];
      // Mock HTTP Client
      final mockClient = MockClient((request) async {
        final url = request.url.toString();

        // 1. Mock content fetch
        if (url.startsWith('https://example.com')) {
          return http.Response(
            '<html><body><h1>New Content</h1></body></html>',
            200,
          );
        }

        // 2. Mock Gemini API
        if (url.contains('generativelanguage.googleapis.com')) {
          geminiRequests.add(request.body);
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Updated Content with # Existing Content'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      final command = UpdateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: tempDir,
      );
      runner.addCommand(command);

      // Run command
      await runner.run(['update-skill', inputYamlFile.path]);

      expect(skillFile.existsSync(), isTrue);

      // Verify the updated content was written
      final updatedText = skillFile.readAsStringSync();
      expect(updatedText, contains('Updated Content with # Existing Content'));

      // Verify source header was sent to Gemini
      expect(geminiRequests, isNotEmpty);
      expect(geminiRequests.first, contains('# Existing Content'));
      expect(geminiRequests.first, contains('New Content'));
    });

    test('fails gracefully when SKILL.md does not exist', () async {
      final inputData = [
        {
          'name': 'missing',
          'description': 'Description',
          'resources': ['https://example.com/source'],
        },
      ];
      inputYamlFile.writeAsStringSync(jsonEncode(inputData));

      final logs = <String>[];
      final sub = Logger.root.onRecord.listen((record) {
        logs.add(record.message);
      });
      addTearDown(sub.cancel);

      final mockClient = MockClient((request) async {
        return http.Response('Error', 500);
      });

      final command = UpdateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: tempDir,
      );
      runner.addCommand(command);

      await runner.run(['update-skill', inputYamlFile.path]);

      expect(logs, contains(contains('Skill file not found at')));
      expect(logs, contains(contains('Cannot update an non-existent skill.')));
    });

    test(
      'logs warning when fetchAndConvertContent returns empty string',
      () async {
        final inputData = [
          {
            'name': 'empty-fetch',
            'description': 'Description',
            'resources': <String>[],
          },
        ];
        inputYamlFile.writeAsStringSync(jsonEncode(inputData));

        final skillDir = Directory(p.join(tempDir.path, 'empty-fetch'))
          ..createSync();
        File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('Existing');

        final logs = <String>[];
        final sub = Logger.root.onRecord.listen(
          (record) => logs.add(record.message),
        );
        addTearDown(sub.cancel);

        final mockClient = MockClient((request) async {
          return http.Response('', 200); // Empty HTML body
        });

        final command = UpdateSkillCommand(
          environment: {'GEMINI_API_KEY': 'test-key'},
          httpClient: mockClient,
          outputDir: tempDir,
        );
        runner.addCommand(command);

        await runner.run(['update-skill', inputYamlFile.path]);
        expect(
          logs,
          contains('  No content fetched for empty-fetch. Skipping.'),
        );
      },
    );

    test('dry run fetches content but skips Gemini and file writes', () async {
      final inputData = [
        {
          'name': 'dry-update',
          'description': 'Description',
          'resources': ['https://example.com/source'],
        },
      ];
      inputYamlFile.writeAsStringSync(jsonEncode(inputData));

      final skillDir = Directory(p.join(tempDir.path, 'dry-update'))
        ..createSync();
      final skillFile = File(p.join(skillDir.path, 'SKILL.md'))
        ..writeAsStringSync('Existing content');

      final logs = <String>[];
      final sub = Logger.root.onRecord.listen((record) {
        logs.add(record.message);
      });
      addTearDown(sub.cancel);

      var geminiCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://example.com/source') {
          return http.Response('<html>New Content</html>', 200);
        }
        if (request.url.toString().contains('generativelanguage')) {
          geminiCalled = true;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Gen'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response('Error', 500);
      });

      final command = UpdateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: tempDir,
      );
      runner.addCommand(command);

      await runner.run(['update-skill', '--dry-run', inputYamlFile.path]);

      expect(geminiCalled, isFalse);
      expect(
        logs,
        contains(contains('[DRY RUN] Would update skill: dry-update')),
      );
      expect(
        logs,
        contains(
          contains(
            '[DRY RUN] Original file size: ~2 words (~3 tokens) -> Raw content size: ~8 words (~10 tokens).',
          ),
        ),
      );
      expect(skillFile.readAsStringSync(), equals('Existing content'));
    });
  });
}
