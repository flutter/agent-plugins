// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';
import 'package:dart_skills_lint/src/entry_point.dart';
import 'package:dart_skills_lint/src/models/analysis_severity.dart';
import 'package:dart_skills_lint/src/models/check_type.dart';
import 'package:dart_skills_lint/src/models/custom_rule_options.dart';
import 'package:dart_skills_lint/src/rule_registry.dart';
import 'package:test/test.dart';

void main() {
  group('resolveOptionsOverrides', () {
    const mockCheckName = 'mock-rule';
    late CheckType mockCheck;

    setUpAll(() {
      mockCheck = const CheckType(
        name: mockCheckName,
        defaultSeverity: AnalysisSeverity.disabled,
        help: 'Mock rule for testing.',
        allowedOptions: {'exclude': String, 'max': int, 'strict': bool, 'items': List},
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
        for (final String optionName in check.allowedOptions.keys) {
          final Type type = check.allowedOptions[optionName]!;
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
      final Map<String, CustomRuleOptions> overrides = resolveRuleOptionsOverrides(results);
      expect(overrides, isEmpty);
    });

    test('parses and coerces String, int, and bool options correctly', () {
      final ArgResults results = createParser().parse([
        '--$mockCheckName-exclude=.*-workspace',
        '--$mockCheckName-max=75',
        '--$mockCheckName-strict=true',
      ]);

      final Map<String, CustomRuleOptions> overrides = resolveRuleOptionsOverrides(results);
      expect(overrides, isNotEmpty);
      expect(overrides[mockCheckName], isNotNull);

      final CustomRuleOptions mockOpts = overrides[mockCheckName]!;
      expect(mockOpts['exclude'], equals('.*-workspace'));
      expect(mockOpts['max'], equals(75));
      expect(mockOpts['strict'], isTrue);
    });

    test('parses and coerces List option correctly', () {
      final ArgResults results = createParser().parse(['--$mockCheckName-items=a,b,c']);

      final Map<String, CustomRuleOptions> overrides = resolveRuleOptionsOverrides(results);
      expect(overrides, isNotEmpty);
      expect(overrides[mockCheckName], isNotNull);

      final CustomRuleOptions mockOpts = overrides[mockCheckName]!;
      expect(mockOpts['items'], equals(['a', 'b', 'c']));
    });

    test('clears option (sets to null) when overridden with empty string', () {
      final ArgResults results = createParser().parse(['--$mockCheckName-exclude=']);

      final Map<String, CustomRuleOptions> overrides = resolveRuleOptionsOverrides(results);
      expect(overrides, isNotEmpty);
      expect(overrides[mockCheckName], isNotNull);

      final CustomRuleOptions mockOpts = overrides[mockCheckName]!;
      expect(mockOpts.containsKey('exclude'), isTrue);
      expect(mockOpts['exclude'], isNull);
    });

    test('throws FormatException when int option is passed an invalid numeric string', () {
      final ArgResults results = createParser().parse(['--$mockCheckName-max=abc']);
      expect(
        () => resolveRuleOptionsOverrides(results),
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
        () => resolveRuleOptionsOverrides(results),
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
