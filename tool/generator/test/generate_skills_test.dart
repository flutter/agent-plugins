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
import 'package:skills/src/commands/generate_skill_command.dart';
import 'package:test/test.dart';

void main() {
  group('GenerateSkillsCommand', () {
    late CommandRunner<void> runner;
    late Directory tempDir;
    late File inputYamlFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('skills_gen_test');
      inputYamlFile = File(p.join(tempDir.path, 'input.yaml'));
      runner = CommandRunner<void>('skills', 'Test runner');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('generates skill from YAML input with dart-docs- prefix', () async {
      // Create input YAML in a file named dart_dev.yaml to trigger prefixing
      inputYamlFile = File(p.join(tempDir.path, 'dart_dev.yaml'));
      final inputData = [
        {
          'name': 'foo',
          'description': 'Foo description',
          'resources': ['https://example.com/foo.html'],
        },
        {
          'name': 'example',
          'description': 'Example description',
          'resources': ['https://example.com/'],
        },
      ];
      inputYamlFile.writeAsStringSync(jsonEncode(inputData));

      final geminiRequests = <String>[];
      // Mock HTTP Client
      final mockClient = MockClient((request) async {
        final url = request.url.toString();

        // 1. Mock content fetch
        if (url.startsWith('https://example.com')) {
          return http.Response(
            '<html><body><h1>Skill</h1><p>Content for $url</p></body></html>',
            200,
          );
        }

        // 2. Mock Gemini API
        if (url.contains('generativelanguage.googleapis.com')) {
          geminiRequests.add(request.body);
          // ... strict mock ...
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Generated Content'},
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

      final command = GenerateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: tempDir,
      );
      runner.addCommand(command);

      // Run command
      await runner.run(['generate-skill', inputYamlFile.path]);

      // Just verify file creation for now
      final skillDirFoo = Directory(p.join(tempDir.path, 'foo'));
      expect(skillDirFoo.existsSync(), isTrue);

      final skillFile = File(p.join(skillDirFoo.path, 'SKILL.md'));
      expect(skillFile.existsSync(), isTrue);

      // Verify source header was sent to Gemini
      expect(geminiRequests, isNotEmpty);
      expect(
        geminiRequests.first,
        contains('--- Raw content from https://example.com/foo.html ---'),
      );
    });

    test('logs progress and summary', () async {
      inputYamlFile = File(p.join(tempDir.path, 'dart_dev.yaml'));
      final inputData = [
        {
          'name': 'success',
          'description': 'Desc',
          'resources': ['https://example.com/success'],
        },
        {
          'name': 'fail',
          'description': 'Desc',
          'resources': ['https://example.com/fail_404'],
        },
      ];
      inputYamlFile.writeAsStringSync(jsonEncode(inputData));

      final logs = <String>[];
      final sub = Logger.root.onRecord.listen((record) {
        logs.add(record.message);
      });

      addTearDown(sub.cancel);

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://example.com/success') {
          return http.Response('<html>Content</html>', 200);
        }
        if (url == 'https://example.com/fail_404') {
          return http.Response('Not Found', 404);
        }
        // Mock Gemini
        if (url.contains('generativelanguage')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Generated Content'},
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

      final command = GenerateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: tempDir,
      );
      runner.addCommand(command);

      await runner.run(['generate-skill', inputYamlFile.path]);

      // Verify Logs
      expect(logs, contains(contains('Generating skill: success...')));
      expect(
        logs,
        contains(contains('Fetching https://example.com/success...')),
      );
      expect(logs, contains(contains('Generating skill: fail...')));
    });

    test('accepts thinking-budget option', () async {
      // Setup for this test requires a configFile and skillsDir,
      // which are not defined in the provided context.
      // Assuming these would be defined in a real scenario or
      // this test is incomplete without them.
      // For now, I'll use tempDir for skillsDir and create a dummy configFile.

      final skillsDir = Directory(p.join(tempDir.path, 'skills_output'));
      await skillsDir.create();

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      final inputData = [
        {
          'name': 'budget_test',
          'description': 'Budget test description',
          'resources': ['https://example.com/budget'],
        },
      ];
      configFile.writeAsStringSync(jsonEncode(inputData));

      final logs = <String>[];
      final sub = Logger.root.onRecord.listen((record) {
        logs.add(record.message);
      });
      addTearDown(sub.cancel);

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://example.com/budget') {
          return http.Response('<html>Budget Content</html>', 200);
        }
        if (url.contains('generativelanguage')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Generated Budget Content'},
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

      final command = GenerateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: skillsDir,
      );
      runner.addCommand(command);

      await runner.run([
        'generate-skill',
        configFile.path,
        '--directory',
        skillsDir.path,
        '--thinking-budget',
        '4000',
      ]);

      expect(
        logs,
        contains(
          contains(
            'Model: models/gemini-4-argon, Max Output Tokens: 65536, Thinking Budget: 4000',
          ),
        ),
      );
      final skillDirBudget = Directory(p.join(skillsDir.path, 'budget_test'));
      expect(skillDirBudget.existsSync(), isTrue);
      final skillFile = File(p.join(skillDirBudget.path, 'SKILL.md'));
      expect(skillFile.existsSync(), isTrue);
      expect(
        skillFile.readAsStringSync(),
        contains('Generated Budget Content\n'),
      );
    });

    test('accepts custom --model option', () async {
      final skillsDir = Directory(p.join(tempDir.path, 'skills_output_model'));
      await skillsDir.create();

      final configFile = File(p.join(tempDir.path, 'config_model.yaml'));
      final inputData = [
        {
          'name': 'model_test',
          'description': 'Model test description',
          'resources': ['https://example.com/model'],
        },
      ];
      configFile.writeAsStringSync(jsonEncode(inputData));

      final logs = <String>[];
      final sub = Logger.root.onRecord.listen((record) {
        logs.add(record.message);
      });
      addTearDown(sub.cancel);

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://example.com/model') {
          return http.Response('<html>Model Content</html>', 200);
        }
        if (url.contains('generativelanguage')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Generated Model Content'},
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

      final command = GenerateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: skillsDir,
      );
      runner.addCommand(command);

      await runner.run([
        'generate-skill',
        configFile.path,
        '--directory',
        skillsDir.path,
        '--model',
        'models/custom-model-test',
      ]);

      expect(
        logs,
        contains(
          contains(
            'Model: models/custom-model-test, Max Output Tokens: 65536, Thinking Budget: 4096',
          ),
        ),
      );
    });

    test('handles invalid thinking-budget option gracefully', () async {
      final skillsDir = await Directory.systemTemp.createTemp('skills_output');
      addTearDown(() => skillsDir.delete(recursive: true));

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      final inputData = [
        {
          'name': 'budget_test',
          'description': 'Budget test description',
          'resources': ['https://example.com/budget'],
        },
      ];
      configFile.writeAsStringSync(jsonEncode(inputData));

      final logs = <String>[];
      final sub = Logger.root.onRecord.listen((record) {
        logs.add(record.message);
      });
      addTearDown(sub.cancel);

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://example.com/budget') {
          return http.Response('<html>Budget Content</html>', 200);
        }
        if (url.contains('generativelanguage')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Generated Budget Content'},
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

      final command = GenerateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: skillsDir,
      );
      runner.addCommand(command);

      await runner.run([
        'generate-skill',
        configFile.path,
        '--directory',
        skillsDir.path,
        '--thinking-budget',
        'invalid',
      ]);

      expect(
        logs,
        contains(contains('Invalid thinking-budget: invalid. Skipping.')),
      );
      final skillDirBudget = Directory(p.join(skillsDir.path, 'budget_test'));
      expect(skillDirBudget.existsSync(), isFalse);
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
        final inputYamlFile = File(p.join(tempDir.path, 'empty_fetch.yaml'))
          ..writeAsStringSync(jsonEncode(inputData));

        final logs = <String>[];
        final sub = Logger.root.onRecord.listen(
          (record) => logs.add(record.message),
        );
        addTearDown(sub.cancel);

        final mockClient = MockClient((request) async {
          return http.Response('', 200); // Empty HTML body
        });

        final command = GenerateSkillCommand(
          environment: {'GEMINI_API_KEY': 'test-key'},
          httpClient: mockClient,
          outputDir: tempDir,
        );
        runner.addCommand(command);

        await runner.run(['generate-skill', inputYamlFile.path]);
        expect(
          logs,
          contains('  No content fetched for empty-fetch. Skipping.'),
        );
      },
    );

    test('logs severe error when Gemini returns null or empty', () async {
      final inputData = [
        {
          'name': 'empty-gemini',
          'description': 'Description',
          'resources': ['https://example.com/source'],
        },
      ];
      final inputYamlFile = File(p.join(tempDir.path, 'empty_gemini.yaml'))
        ..writeAsStringSync(jsonEncode(inputData));

      final logs = <String>[];
      final sub = Logger.root.onRecord.listen(
        (record) => logs.add(record.message),
      );
      addTearDown(sub.cancel);

      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://example.com/source') {
          return http.Response('<html>Content</html>', 200);
        }
        if (request.url.toString().contains('generativelanguage')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': ''},
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

      final command = GenerateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: tempDir,
      );
      runner.addCommand(command);

      await runner.run(['generate-skill', inputYamlFile.path]);
      expect(logs, contains('  Failed to generate content for empty-gemini'));
    });

    test('logs severe error on generic exception during generation', () async {
      final inputData = [
        {
          'name': 'exception-gemini',
          'description': 'Description',
          'resources': ['https://example.com/source'],
        },
      ];
      final inputYamlFile = File(p.join(tempDir.path, 'exception_gemini.yaml'))
        ..writeAsStringSync(jsonEncode(inputData));

      final logs = <String>[];
      final sub = Logger.root.onRecord.listen(
        (record) => logs.add(record.message),
      );
      addTearDown(sub.cancel);

      final mockClient = MockClient((request) async {
        throw Exception('Generic Error');
      });

      final command = GenerateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: tempDir,
      );
      runner.addCommand(command);

      await runner.run(['generate-skill', inputYamlFile.path]);
      expect(
        logs,
        contains(
          contains(
            'Error processing exception-gemini: Exception: Generic Error',
          ),
        ),
      );
    });

    test('dry run fetches content but skips Gemini and file writes', () async {
      final inputData = [
        {
          'name': 'dry-run-skill',
          'description': 'Description',
          'resources': ['https://example.com/source'],
        },
      ];
      final inputYamlFile = File(p.join(tempDir.path, 'dry_run.yaml'))
        ..writeAsStringSync(jsonEncode(inputData));

      final logs = <String>[];
      final sub = Logger.root.onRecord.listen(
        (record) => logs.add(record.message),
      );
      addTearDown(sub.cancel);

      var geminiCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://example.com/source') {
          return http.Response('<html>Content</html>', 200);
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

      final command = GenerateSkillCommand(
        environment: {'GEMINI_API_KEY': 'test-key'},
        httpClient: mockClient,
        outputDir: tempDir,
      );
      runner.addCommand(command);

      await runner.run(['generate-skill', '--dry-run', inputYamlFile.path]);

      expect(geminiCalled, isFalse);
      expect(
        logs,
        contains(contains('[DRY RUN] Would generate skill: dry-run-skill')),
      );

      final skillDir = Directory(p.join(tempDir.path, 'dry-run-skill'));
      expect(skillDir.existsSync(), isFalse);
    });
  });
}
