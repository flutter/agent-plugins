// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'analysis_severity.dart';
import 'custom_rule_parameters.dart';
import 'rule_parameter_type.dart';

/// Encapsulates metadata and severity state for a specific validation rule.
class CheckType {
  const CheckType({
    required this.name,
    required this.defaultSeverity,
    required this.help,
    this.parameterSchema = const {},
  });
  final String name;

  /// The default severity if not overridden by config or flags.
  final AnalysisSeverity defaultSeverity;

  /// The help message displayed by the CLI.
  final String help;

  /// Custom configuration options supported by this check.
  final Map<String, RuleParameterType> parameterSchema;

  /// Validates the given [options] against this check's [parameterSchema] schema.
  ///
  /// Returns a list of error messages for any unrecognized options or type mismatches.
  List<String> validateParameters(CustomRuleParameters parameters) {
    final List<String> errors = [];
    for (final String key in parameters.params.keys) {
      if (!parameterSchema.containsKey(key)) {
        errors.add('Unrecognized parameter "$key" for rule "$name".');
        continue;
      }
      final RuleParameterType expectedType = parameterSchema[key]!;
      final Object? actualValue = parameters.params[key];
      if (actualValue != null && !expectedType.isValid(actualValue)) {
        errors.add(
          'Invalid value/type for parameter "$key" in rule "$name". '
          'Expected ${expectedType.description}, got "$actualValue".',
        );
      }
    }
    return errors;
  }
}
