// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'analysis_severity.dart';
import 'custom_rule_options.dart';
import 'option_type.dart';

/// Encapsulates metadata and severity state for a specific validation rule.
class CheckType {
  const CheckType({
    required this.name,
    required this.defaultSeverity,
    required this.help,
    this.optionsSchema = const {},
  });
  final String name;

  /// The default severity if not overridden by config or flags.
  final AnalysisSeverity defaultSeverity;

  /// The help message displayed by the CLI.
  final String help;

  /// Custom configuration options supported by this check.
  final Map<String, RuleOptionType> optionsSchema;

  /// Validates the given [options] against this check's [optionsSchema] schema.
  ///
  /// Returns a list of error messages for any unrecognized options or type mismatches.
  List<String> validateOptions(CustomRuleOptions options) {
    final List<String> errors = [];
    for (final String key in options.params.keys) {
      if (!optionsSchema.containsKey(key)) {
        errors.add('Unrecognized option "$key" for rule "$name".');
        continue;
      }
      final RuleOptionType expectedType = optionsSchema[key]!;
      final Object? actualValue = options.params[key];
      if (actualValue != null && !expectedType.isValid(actualValue)) {
        errors.add(
          'Invalid value/type for option "$key" in rule "$name". '
          'Expected ${expectedType.description}, got "$actualValue".',
        );
      }
    }
    return errors;
  }
}
