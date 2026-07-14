// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'analysis_severity.dart';
import 'skill_context.dart';
import 'validation_error.dart';

/// Abstract base class for all skill validation rules.
///
/// Custom rules should follow these guidelines to play nice with others:
/// 1. **Unique Name**: The [name] must be unique to allow for overrides in
///    configuration.
/// 2. **Statelessness**: Rules should not maintain state between [validate] calls.
/// 3. **Use Context**: Prefer using data in [SkillContext] (like [context.parsedYaml])
///    rather than reading files manually to avoid duplicate I/O.
/// 4. **Handle Parsing Errors**: If [context.parsedYaml] is null, check
///    [context.yamlParsingError]. Rules that require valid YAML should return
///    quickly if parsing failed.
/// 5. **Respect Severity**: The rule should use its [severity] when creating
///    [ValidationError]s unless there is a good reason not to.
abstract class SkillRule {
  /// The unique name of the rule (e.g., 'check-relative-paths').
  /// Used in configuration and flags.
  String get name;

  AnalysisSeverity get severity;

  /// Custom configuration options supported by this rule (mapping option name to expected Type).
  Map<String, Type> get allowedOptions => const {};

  /// Validates the skill provided in [context].
  Future<List<ValidationError>> validate(SkillContext context);
}
