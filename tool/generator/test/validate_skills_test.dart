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
  group('ValidateSkillCommand', () {
    late CommandRunner<void> runner;
    late Directory tempDir;
    late Directory skillsDir;
    late Directory validationDir;
    late MockClient mockClient;
    final logs = <String>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('validate_skills_test');
      skillsDir = Directory(p.join(tempDir.path, 'skills'));
      await skillsDir.create();
      validationDir = Directory(p.join(tempDir.path, 'validation'));
      await validationDir.create();

      mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      // Capture logs
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

    test('validates single skill defined in config', () async {
      const skillName = 'test-skill';
      final skillDir = Directory(p.join(skillsDir.path, skillName));
      await skillDir.create();
      final skillFile = File(p.join(skillDir.path, 'SKILL.md'));
      await skillFile.writeAsString('content');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skillName,
            'description': 'Description',
            'resources': ['https://example.com'],
          },
        ]),
      );

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            validationDir: validationDir,
            httpClient: mockClient,
          ),
        );

      await IOOverrides.runZoned(() async {
        await runner.run(['validate-skill', configFile.path]);
      }, getCurrentDirectory: () => tempDir);

      expect(logs, contains('Validating skill: $skillName...'));
    });

    test('validates and grades single skill', () async {
      const skillName = 'test-skill';
      final skillDir = Directory(p.join(skillsDir.path, skillName));
      await skillDir.create();
      final skillFile = File(p.join(skillDir.path, 'SKILL.md'));
      await skillFile.writeAsString('Existing content');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skillName,
            'description': 'Description',
            'resources': ['https://example.com/source'],
          },
        ]),
      );

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://example.com/source') {
          return http.Response(
            '<html><body><h1>Source</h1></body></html>',
            200,
          );
        }
        if (url.contains('generativelanguage')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text':
                            '# Validation Report\n\n'
                            '- Accuracy: High\n'
                            '- Structure: Correct\n'
                            '- Completeness: Good\n\n'
                            'Conclusion: Valid\n'
                            'Similarity Score: 85',
                      },
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

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            validationDir: validationDir,
            httpClient: mockClient,
          ),
        );

      await IOOverrides.runZoned(() async {
        await runner.run(['validate-skill', configFile.path]);
      }, getCurrentDirectory: () => tempDir);

      expect(logs, contains('Validating skill: $skillName...'));
      expect(logs, contains(contains('Validation report written to')));
    });

    test('validates all skills in config', () async {
      const skill1Name = 'skill1';
      final skill1Dir = Directory(p.join(skillsDir.path, skill1Name));
      await skill1Dir.create();
      File(p.join(skill1Dir.path, 'SKILL.md')).writeAsStringSync('content');

      const skill2Name = 'skill2';
      final skill2Dir = Directory(p.join(skillsDir.path, skill2Name));
      await skill2Dir.create();
      File(p.join(skill2Dir.path, 'SKILL.md')).writeAsStringSync('content');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skill1Name,
            'description': 'Desc 1',
            'resources': ['https://example.com/1'],
          },
          {
            'name': skill2Name,
            'description': 'Desc 2',
            'resources': ['https://example.com/2'],
          },
        ]),
      );

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            validationDir: validationDir,
            httpClient: mockClient,
          ),
        );

      await IOOverrides.runZoned(() async {
        await runner.run(['validate-skill', configFile.path]);
      }, getCurrentDirectory: () => tempDir);

      expect(logs, contains('Validating skill: $skill1Name...'));
      expect(logs, contains('Validating skill: $skill2Name...'));
    });

    test('logs severe error when config file not found', () async {
      final path = p.join(tempDir.path, 'NON_EXISTENT.yaml');

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            httpClient: mockClient,
          ),
        );

      await IOOverrides.runZoned(() async {
        await runner.run(['validate-skill', path]);
      }, getCurrentDirectory: () => tempDir);

      expect(logs, contains('Configuration file not found: $path'));
    });

    test('logs warning when existing skill file not found', () async {
      const skillName = 'missing-skill';
      // Do NOT create skill directory or file

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skillName,
            'description': 'Desc',
            'resources': ['https://example.com'],
          },
        ]),
      );

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://example.com') {
          return http.Response('Content', 200);
        }
        if (url.contains('generativelanguage')) {
          return http.Response(
            '{"candidates": [{"content": {"parts": [{"text": "Generated Content"}]}}]}',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            httpClient: mockClient,
          ),
        );

      await IOOverrides.runZoned(() async {
        await runner.run(['validate-skill', configFile.path]);
      }, getCurrentDirectory: () => tempDir);

      expect(logs, contains(contains('Existing skill file not found')));
    });

    test('logs warning when failed to fetch URL', () async {
      const skillName = 'fail-skill';
      final skillDir = Directory(p.join(skillsDir.path, skillName));
      await skillDir.create();
      File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('content');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skillName,
            'description': 'Desc',
            'resources': ['https://example.com/fail'],
          },
        ]),
      );

      final mockClient = MockClient((request) async {
        // Throw to trigger the 'Error fetching' catch block
        throw Exception('Network Error');
      });

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            httpClient: mockClient,
          ),
        );

      await runner.run(['validate-skill', configFile.path]);

      expect(
        logs,
        contains(
          contains('Error validating $skillName: Exception: Network Error'),
        ),
      );
    });

    test(
      'logs severe error when grading fails repeatedly/exceptionally',
      () async {
        const skillName = 'grade-fail';
        final skillDir = Directory(p.join(skillsDir.path, skillName));
        await skillDir.create();
        File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('content');

        final configFile = File(p.join(tempDir.path, 'config.yaml'));
        await configFile.writeAsString(
          jsonEncode([
            {
              'name': skillName,
              'description': 'Desc',
              'resources': ['https://example.com/source'],
            },
          ]),
        );

        final mockClient = MockClient((request) async {
          if (request.url.toString() == 'https://example.com/source') {
            return http.Response('# Source', 200);
          }
          if (request.url.toString().contains('generativelanguage')) {
            // Validation (grading) fails
            throw Exception('Gemini API Error');
          }
          return http.Response('Not Found', 404);
        });

        runner = CommandRunner<void>('skills', 'Test runner')
          ..addCommand(
            ValidateSkillCommand(
              environment: {'GEMINI_API_KEY': 'test-key'},
              outputDir: skillsDir,
              validationDir: validationDir,
              httpClient: mockClient,
            ),
          );

        await runner.run(['validate-skill', configFile.path]);

        expect(
          logs,
          contains(contains('Failed to generate validation report')),
        );
      },
    );

    test('logs severe error when Gemini grading throws exception', () async {
      const skillName = 'gemini-fail';
      final skillDir = Directory(p.join(skillsDir.path, skillName));
      await skillDir.create();
      // Ensure name matches to avoid name mismatch error
      File(
        p.join(skillDir.path, 'SKILL.md'),
      ).writeAsStringSync('name: $skillName\nContent');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skillName,
            'description': 'Desc',
            'resources': ['https://example.com/source'],
          },
        ]),
      );

      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://example.com/source') {
          return http.Response('# Source', 200);
        }
        if (request.url.toString().contains('generativelanguage')) {
          // Validation (grading) throws
          throw Exception('Gemini API Error');
        }
        return http.Response('Not Found', 404);
      });

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            validationDir: validationDir,
            httpClient: mockClient,
          ),
        );

      await runner.run(['validate-skill', configFile.path]);

      expect(logs, contains(contains('Failed to generate validation report')));
    });

    test('logs severe error when skill name/description mismatch', () async {
      const skillName = 'mismatch-skill';
      final skillDir = Directory(p.join(skillsDir.path, skillName));
      await skillDir.create();
      // Write content WITHOUT name/description
      final skillFile = File(p.join(skillDir.path, 'SKILL.md'));
      await skillFile.writeAsString('Invalid content without frontmatter');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skillName,
            'description': 'Expected Description',
            'resources': ['https://example.com/source'],
          },
        ]),
      );

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://example.com/source') {
          return http.Response('# Source', 200);
        }
        if (url.contains('generativelanguage')) {
          return http.Response(
            '{"candidates": [{"content": {"parts": [{"text": "Generated Content"}]}}]}',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            validationDir: validationDir,
            httpClient: mockClient,
          ),
        );

      await IOOverrides.runZoned(() async {
        await runner.run(['validate-skill', configFile.path]);
      }, getCurrentDirectory: () => tempDir);

      expect(
        logs,
        contains(contains('Validation Failed: Skill name mismatch')),
      );
      expect(
        logs,
        contains(contains('Validation Failed: Skill name mismatch')),
      );
      // Description check was removed from the command
      expect(
        logs,
        isNot(
          contains(contains('Validation Failed: Skill description mismatch')),
        ),
      );
    });

    test('sends source URL header to Gemini during regeneration', () async {
      const skillName = 'header-skill';
      final skillDir = Directory(p.join(skillsDir.path, skillName));
      await skillDir.create();
      final skillFile = File(p.join(skillDir.path, 'SKILL.md'));
      await skillFile.writeAsString('''
name: $skillName
description: Desc
---
Content
''');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skillName,
            'description': 'Desc',
            'resources': ['https://example.com/source'],
          },
        ]),
      );

      final geminiRequests = <String>[];
      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://example.com/source') {
          return http.Response('Source Content', 200);
        }
        if (url.contains('generativelanguage')) {
          geminiRequests.add(request.body);
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Generated Content\nSimilarity Score: 50'},
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

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            httpClient: mockClient,
            validationDir: validationDir,
          ),
        );

      await IOOverrides.runZoned(() async {
        await runner.run(['validate-skill', configFile.path]);
      }, getCurrentDirectory: () => tempDir);

      expect(geminiRequests, isNotEmpty);
      expect(
        geminiRequests.first,
        contains('--- Raw content from https://example.com/source ---'),
      );
    });
    test('fails upfront validation when resources list is empty', () async {
      const skillName = 'empty-fetch-val';
      final skillDir = Directory(p.join(skillsDir.path, skillName));
      await skillDir.create();
      File(
        p.join(skillDir.path, 'SKILL.md'),
      ).writeAsStringSync('name: $skillName\ncontent');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {'name': skillName, 'description': 'Desc', 'resources': <String>[]},
        ]),
      );

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            httpClient: mockClient,
          ),
        );

      await runner.run(['validate-skill', configFile.path]);
      expect(
        logs,
        contains(
          'Skill "empty-fetch-val" field "resources" must not be empty.',
        ),
      );
      expect(logs, contains('Configuration validation failed.'));
    });

    test('logs severe error on generic exception during validation', () async {
      const skillName = 'exception-val';
      final skillDir = Directory(p.join(skillsDir.path, skillName));
      await skillDir.create();
      File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('content');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skillName,
            'description': 'Desc',
            'resources': ['https://example.com/source'],
          },
        ]),
      );

      final mockClient = MockClient(
        (request) async => throw Exception('Generic Error'),
      );

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            httpClient: mockClient,
          ),
        );

      await runner.run(['validate-skill', configFile.path]);
      expect(
        logs,
        contains(
          contains('Error validating $skillName: Exception: Generic Error'),
        ),
      );
    });

    test('validates with missing metadata fallbacks', () async {
      const skillName = 'fallback-meta';
      final skillDir = Directory(p.join(skillsDir.path, skillName));
      await skillDir.create();
      File(
        p.join(skillDir.path, 'SKILL.md'),
      ).writeAsStringSync('name: $skillName\ncontent WITHOUT metadata');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skillName,
            'description': 'Desc',
            'resources': ['https://example.com/source'],
          },
        ]),
      );

      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://example.com/source') {
          return http.Response('# Source', 200);
        }
        if (request.url.toString().contains('generativelanguage')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Generated Content\nGrade: 100'},
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

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            validationDir: validationDir,
            httpClient: mockClient,
          ),
        );

      await runner.run(['validate-skill', configFile.path]);
      expect(logs, contains(contains('Validation report written to')));
    });

    test('dry run fetches content but skips gemini and file writes', () async {
      const skillName = 'dry-validate';
      final skillDir = Directory(p.join(skillsDir.path, skillName));
      await skillDir.create();
      File(
        p.join(skillDir.path, 'SKILL.md'),
      ).writeAsStringSync('name: $skillName\nExisting content');

      final configFile = File(p.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(
        jsonEncode([
          {
            'name': skillName,
            'description': 'Desc',
            'resources': ['https://example.com/source'],
          },
        ]),
      );

      var geminiCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://example.com/source') {
          return http.Response('# Source', 200);
        }
        if (request.url.toString().contains('generativelanguage')) {
          geminiCalled = true;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Generated Content\nGrade: 100'},
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

      runner = CommandRunner<void>('skills', 'Test runner')
        ..addCommand(
          ValidateSkillCommand(
            environment: {'GEMINI_API_KEY': 'test-key'},
            outputDir: skillsDir,
            validationDir: validationDir,
            httpClient: mockClient,
          ),
        );

      await runner.run(['validate-skill', '--dry-run', configFile.path]);

      expect(geminiCalled, isFalse);
      expect(
        logs,
        contains(contains('[DRY RUN] Would validate skill: $skillName')),
      );

      final valDir = Directory(p.join(validationDir.path, skillName));
      expect(valDir.existsSync(), isFalse);
    });
  });
}
