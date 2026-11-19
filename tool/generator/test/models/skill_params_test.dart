// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:skills/src/models/skill_params.dart';
import 'package:test/test.dart';

void main() {
  group('SkillParams', () {
    test('fromJson parses correctly without instructions', () {
      final json = {
        'name': 'test-skill',
        'description': 'Test Description',
        'resources': ['http://example.com'],
      };
      final skill = SkillParams.fromJson(json);
      expect(skill.name, 'test-skill');
      expect(skill.description, 'Test Description');
      expect(skill.resources, ['http://example.com']);
      expect(skill.instructions, isNull);
    });

    test('fromJson parses correctly with instructions', () {
      final json = {
        'name': 'test-skill',
        'description': 'Test Description',
        'instructions': 'Do not hallucinate.',
        'resources': ['http://example.com'],
      };
      final skill = SkillParams.fromJson(json);
      expect(skill.name, 'test-skill');
      expect(skill.description, 'Test Description');
      expect(skill.resources, ['http://example.com']);
      expect(skill.instructions, 'Do not hallucinate.');
    });

    test('fromYamlMap parses untyped YAML maps including examplePrompt', () {
      final yamlMap = <Object?, Object?>{
        'name': 'yaml-skill',
        'description': 'YAML Description',
        'resources': <Object?>['https://example.com/doc'],
        'instructions': 'Keep under 500 lines.',
        'examplePrompt': 'Build a responsive layout.',
      };
      final skill = SkillParams.fromYamlMap(yamlMap);
      expect(skill.name, 'yaml-skill');
      expect(skill.description, 'YAML Description');
      expect(skill.resources, ['https://example.com/doc']);
      expect(skill.instructions, 'Keep under 500 lines.');
      expect(skill.examplePrompt, 'Build a responsive layout.');
    });

    test('fromYamlMap throws FormatException on invalid field types', () {
      expect(
        () => SkillParams.fromYamlMap(<Object?, Object?>{}),
        throwsFormatException,
      );
      expect(
        () => SkillParams.fromYamlMap(<Object?, Object?>{
          'name': 'foo',
          'description': 123,
          'resources': <Object?>['https://example.com'],
        }),
        throwsFormatException,
      );
      expect(
        () => SkillParams.fromYamlMap(<Object?, Object?>{
          'name': 'foo',
          'description': 'desc',
          'resources': <Object?>[123],
        }),
        throwsFormatException,
      );
      expect(
        () => SkillParams.fromYamlMap(<Object?, Object?>{
          'name': '   ',
          'description': 'desc',
          'resources': <Object?>['https://example.com'],
        }),
        throwsFormatException,
      );
      expect(
        () => SkillParams.fromYamlMap(<Object?, Object?>{
          'name': 'foo',
          'description': 'desc',
          'resources': <Object?>['https://example.com'],
          'examplePrompt': 456,
        }),
        throwsFormatException,
      );
    });
  });
}
