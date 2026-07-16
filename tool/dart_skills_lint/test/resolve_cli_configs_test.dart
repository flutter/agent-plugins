// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';
import 'package:dart_skills_lint/src/entry_point.dart';
import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/check_type.dart';
import 'package:dart_skills_lint/src/models/custom_rule_parameters.dart';
import 'package:dart_skills_lint/src/models/rule_config.dart';
import 'package:dart_skills_lint/src/models/rule_parameter_type.dart';
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

  group('resolveRuleConfigsFromCli - parameter overrides', () {
    const mockCheckName = 'mock-rule';
    late CheckType mockCheck;

    setUpAll(() {
      mockCheck = const CheckType(
        name: mockCheckName,
        defaultSeverity: AnalysisSeverity.disabled,
        help: 'Mock rule for testing.',
        parameterSchema: {
          'exclude': RuleParameterType.string,
          'max': RuleParameterType.integer,
          'strict': RuleParameterType.boolean,
          'items': RuleParameterType.stringList,
          'pattern': RuleParameterType.regExp,
        },
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
        for (final String paramName in check.parameterSchema.keys) {
          final RuleParameterType type = check.parameterSchema[paramName]!;
          if (type == RuleParameterType.stringList) {
            parser.addMultiOption('${check.name}-$paramName');
          } else {
            parser.addOption('${check.name}-$paramName');
          }
        }
      }
      return parser;
    }

    test('returns empty map when no parameter CLI overrides are provided', () {
      final ArgResults results = createParser().parse([]);
      final Map<String, RuleConfigPatch> configs = resolveRuleConfigsFromCli(results);
      expect(configs, isEmpty);
    });

    test('parses and coerces String, RegExp, int, and bool parameters correctly', () {
      final ArgResults results = createParser().parse([
        '--$mockCheckName-exclude=.*-workspace',
        '--$mockCheckName-max=75',
        '--$mockCheckName-strict=true',
        '--$mockCheckName-pattern=^[a-z]+\$',
      ]);

      final Map<String, RuleConfigPatch> configs = resolveRuleConfigsFromCli(results);
      expect(configs, isNotEmpty);
      expect(configs[mockCheckName], isNotNull);

      final CustomRuleParameters? mockParams = configs[mockCheckName]!.parameters;
      expect(mockParams, isNotNull);
      expect(mockParams!['exclude'], equals('.*-workspace'));
      expect(mockParams['max'], equals(75));
      expect(mockParams['strict'], isTrue);
      expect(mockParams['pattern'], equals(r'^[a-z]+$'));
    });

    test('parses and coerces List parameter correctly', () {
      final ArgResults results = createParser().parse(['--$mockCheckName-items=a,b,c']);

      final Map<String, RuleConfigPatch> configs = resolveRuleConfigsFromCli(results);
      expect(configs, isNotEmpty);
      expect(configs[mockCheckName], isNotNull);

      final CustomRuleParameters? mockParams = configs[mockCheckName]!.parameters;
      expect(mockParams, isNotNull);
      expect(mockParams!['items'], equals(['a', 'b', 'c']));
    });

    test('clears parameter (sets to null) when overridden with empty string', () {
      final ArgResults results = createParser().parse(['--$mockCheckName-exclude=']);

      final Map<String, RuleConfigPatch> configs = resolveRuleConfigsFromCli(results);
      expect(configs, isNotEmpty);
      expect(configs[mockCheckName], isNotNull);

      final CustomRuleParameters? mockParams = configs[mockCheckName]!.parameters;
      expect(mockParams, isNotNull);
      expect(mockParams!.containsKey('exclude'), isTrue);
      expect(mockParams['exclude'], isNull);
    });

    test('throws FormatException when int parameter is passed an invalid numeric string', () {
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

    test('throws FormatException when bool parameter is passed a non-boolean string', () {
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
