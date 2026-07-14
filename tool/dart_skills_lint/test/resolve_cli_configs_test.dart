// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';
import 'package:dart_skills_lint/src/entry_point.dart';
import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/check_type.dart';
import 'package:dart_skills_lint/src/models/custom_rule_options.dart';
import 'package:dart_skills_lint/src/models/rule_config.dart';
import 'package:dart_skills_lint/src/rule_registry.dart';
import 'package:dart_skills_lint/src/rules/relative_paths_rule.dart';
import 'package:dart_skills_lint/src/rules/valid_yaml_metadata_rule.dart';
import 'package:test/test.dart';

void main() {
  group('resolveRuleConfigsFromCli - severity overrides', () {
    ArgParser createParser() {
      final parser = ArgParser();
      for (final CheckType check in RuleRegistry.allChecks) {
        parser.addFlag(check.name, defaultsTo: check.defaultSeverity != AnalysisSeverity.disabled);
      }
      return parser;
    }

    test('returns empty map when no CLI overrides are provided', () {
      final ArgResults results = createParser().parse([]);

      final Map<String, RuleConfigPatch> resolved = resolveRuleConfigsFromCli(results);

      expect(
        resolved,
        isEmpty,
        reason:
            'resolveRuleConfigsFromCli should return an empty map when no CLI override flags are provided.',
      );
    });

    test('CLI flags override defaults', () {
      final ArgResults results = createParser().parse(['--${RelativePathsRule.ruleName}']);

      final Map<String, RuleConfigPatch> resolved = resolveRuleConfigsFromCli(results);

      expect(resolved[RelativePathsRule.ruleName]?.severity, AnalysisSeverity.error);
    });

    test('CLI flag disabled overrides defaults', () {
      final ArgResults results = createParser().parse(['--no-${ValidYamlMetadataRule.ruleName}']);

      final Map<String, RuleConfigPatch> resolved = resolveRuleConfigsFromCli(results);

      expect(resolved[ValidYamlMetadataRule.ruleName]?.severity, AnalysisSeverity.disabled);
    });
  });

  group('resolveRuleConfigsFromCli - option overrides', () {
    const mockCheckName = 'mock-rule';
    late CheckType mockCheck;

    setUpAll(() {
      mockCheck = const CheckType(
        name: mockCheckName,
        defaultSeverity: AnalysisSeverity.disabled,
        help: 'Mock rule for testing.',
        optionsSchema: {'exclude': String, 'max': int, 'strict': bool, 'items': List},
      );
      RuleRegistry.allChecks.add(mockCheck);
    });

    tearDownAll(() {
      RuleRegistry.allChecks.remove(mockCheck);
    });

    ArgParser createParser() {
      final parser = ArgParser();
      for (final CheckType check in RuleRegistry.allChecks) {
        parser.addFlag(check.name, defaultsTo: check.defaultSeverity != AnalysisSeverity.disabled);
        for (final String optionName in check.optionsSchema.keys) {
          final Type type = check.optionsSchema[optionName]!;
          if (type == List || type == List<String>) {
            parser.addMultiOption('${check.name}-$optionName');
          } else {
            parser.addOption('${check.name}-$optionName');
          }
        }
      }
      return parser;
    }

    test('returns empty map when no options CLI overrides are provided', () {
      final ArgResults results = createParser().parse([]);
      final Map<String, RuleConfigPatch> configs = resolveRuleConfigsFromCli(results);
      expect(configs, isEmpty);
    });

    test('parses and coerces String, int, and bool options correctly', () {
      final ArgResults results = createParser().parse([
        '--$mockCheckName-exclude=.*-workspace',
        '--$mockCheckName-max=75',
        '--$mockCheckName-strict=true',
      ]);

      final Map<String, RuleConfigPatch> configs = resolveRuleConfigsFromCli(results);
      expect(configs, isNotEmpty);
      expect(configs[mockCheckName], isNotNull);

      final CustomRuleOptions? mockOpts = configs[mockCheckName]!.options;
      expect(mockOpts, isNotNull);
      expect(mockOpts!['exclude'], equals('.*-workspace'));
      expect(mockOpts['max'], equals(75));
      expect(mockOpts['strict'], isTrue);
    });

    test('parses and coerces List option correctly', () {
      final ArgResults results = createParser().parse(['--$mockCheckName-items=a,b,c']);

      final Map<String, RuleConfigPatch> configs = resolveRuleConfigsFromCli(results);
      expect(configs, isNotEmpty);
      expect(configs[mockCheckName], isNotNull);

      final CustomRuleOptions? mockOpts = configs[mockCheckName]!.options;
      expect(mockOpts, isNotNull);
      expect(mockOpts!['items'], equals(['a', 'b', 'c']));
    });

    test('clears option (sets to null) when overridden with empty string', () {
      final ArgResults results = createParser().parse(['--$mockCheckName-exclude=']);

      final Map<String, RuleConfigPatch> configs = resolveRuleConfigsFromCli(results);
      expect(configs, isNotEmpty);
      expect(configs[mockCheckName], isNotNull);

      final CustomRuleOptions? mockOpts = configs[mockCheckName]!.options;
      expect(mockOpts, isNotNull);
      expect(mockOpts!.containsKey('exclude'), isTrue);
      expect(mockOpts['exclude'], isNull);
    });

    test('throws FormatException when int option is passed an invalid numeric string', () {
      final ArgResults results = createParser().parse(['--$mockCheckName-max=abc']);
      expect(
        () => resolveRuleConfigsFromCli(results),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Expected an integer'),
          ),
        ),
      );
    });

    test('throws FormatException when bool option is passed a non-boolean string', () {
      final ArgResults results = createParser().parse(['--$mockCheckName-strict=yes']);
      expect(
        () => resolveRuleConfigsFromCli(results),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Expected "true" or "false"'),
          ),
        ),
      );
    });
  });
}
