// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'analysis_severity.dart';
import 'custom_rule_options.dart';

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
  final Map<String, Type> optionsSchema;

  /// Validates the given [options] against this check's [optionsSchema] schema.
  ///
  /// Returns a list of error messages for any unrecognized options or type mismatches.
  List<String> validateOptions(CustomRuleOptions options) {
    final List<String> errors = [];
    for (final String key in options.keys) {
      if (!optionsSchema.containsKey(key)) {
        errors.add('Unrecognized option "$key" for rule "$name".');
        continue;
      }
      final Type expectedType = optionsSchema[key]!;
      final Object? actualValue = options[key];
      if (actualValue != null && !_isTypeValid(actualValue, expectedType)) {
        errors.add(
          'Invalid type for option "$key" in rule "$name". '
          'Expected $expectedType, got "$actualValue" (${actualValue.runtimeType}).',
        );
      }
    }
    return errors;
  }

  static bool _isTypeValid(Object value, Type expectedType) {
    if (expectedType == String) {
      return value is String;
    }
    if (expectedType == int) {
      return value is int;
    }
    if (expectedType == bool) {
      return value is bool;
    }
    if (expectedType == List || expectedType == List<String>) {
      return value is List;
    }
    return true;
  }
}
