// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';
import 'package:dart_skills_lint/src/entry_point.dart';
import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/check_type.dart';
import 'package:dart_skills_lint/src/rule_registry.dart';
import 'package:dart_skills_lint/src/rules/relative_paths_rule.dart';
import 'package:dart_skills_lint/src/rules/valid_yaml_metadata_rule.dart';
import 'package:test/test.dart';

void main() {
  group('resolveRuleSeverities', () {
    ArgParser createParser() {
      final parser = ArgParser();
      for (final CheckType check in RuleRegistry.allChecks) {
        parser.addFlag(check.name, defaultsTo: check.defaultSeverity != AnalysisSeverity.disabled);
      }
      return parser;
    }

    test('returns empty map when no CLI overrides are provided', () {
      final ArgResults results = createParser().parse([]);

      final Map<String, AnalysisSeverity> resolved = resolveRuleSeverities(results);

      expect(
        resolved,
        isEmpty,
        reason:
            'resolveRuleSeverities should return an empty map when no CLI override flags are provided.',
      );
    });

    test('CLI flags override defaults', () {
      final ArgResults results = createParser().parse(['--${RelativePathsRule.ruleName}']);

      final Map<String, AnalysisSeverity> resolved = resolveRuleSeverities(results);

      expect(resolved[RelativePathsRule.ruleName], AnalysisSeverity.error);
    });

    test('CLI flag disabled overrides defaults', () {
      final ArgResults results = createParser().parse(['--no-${ValidYamlMetadataRule.ruleName}']);

      final Map<String, AnalysisSeverity> resolved = resolveRuleSeverities(results);

      expect(resolved[ValidYamlMetadataRule.ruleName], AnalysisSeverity.disabled);
    });
  });
}
