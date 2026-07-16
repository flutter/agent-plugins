// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'analysis_severity.dart';
import 'skill_context.dart';
import 'validation_error.dart';

/// The result of a skill directory validation attempt.
class ValidationResult {
  ValidationResult({
    this.validationErrors = const [],
    List<String> warnings = const [],
    this.context,
  }) : _manualWarnings = warnings;

  /// The context used during validation.
  final SkillContext? context;

  /// Whether the skill directory is valid according to the specification.
  bool get isValid =>
      !validationErrors.any((e) => e.severity == AnalysisSeverity.error && !e.isIgnored);

  /// A list of structured validation errors found.
  final List<ValidationError> validationErrors;

  final List<String> _manualWarnings;

  /// A list of error messages for failing checks (excluding ignored ones).
  List<String> get errors => validationErrors
      .where((e) => e.severity == AnalysisSeverity.error && !e.isIgnored)
      .map((e) => e.message)
      .toList();

  /// A list of warning messages for suboptimal setups or recommendations.
  List<String> get warnings => [
    ..._manualWarnings,
    ...validationErrors
        .where((e) => e.severity == AnalysisSeverity.warning && !e.isIgnored)
        .map((e) => e.message),
  ];
}
