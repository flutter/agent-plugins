// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:dart_skills_lint/src/rules/absolute_paths_rule.dart';
import 'package:dart_skills_lint/src/rules/description_length_rule.dart';
import 'package:dart_skills_lint/src/rules/disallowed_field_rule.dart';
import 'package:dart_skills_lint/src/rules/name_format_rule.dart';
import 'package:dart_skills_lint/src/rules/relative_paths_rule.dart';
import 'package:dart_skills_lint/src/rules/valid_yaml_metadata_rule.dart';
import 'package:test/test.dart';

void main() {
  group('Rule Naming Conventions', () {
    final List<SkillRule> rules = [
      AbsolutePathsRule(),
      DescriptionLengthRule(),
      DisallowedFieldRule(),
      NameFormatRule(),
      RelativePathsRule(),
      ValidYamlMetadataRule(),
    ];

    final kebabCaseRegex = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

    for (final rule in rules) {
      test('Rule "${rule.runtimeType}" has valid kebab-case name', () {
        expect(rule.name, matches(kebabCaseRegex));
      });
    }
  });
}
