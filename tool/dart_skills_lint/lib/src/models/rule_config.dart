// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'analysis_severity.dart';
import 'custom_rule_parameters.dart';

/// Represents the resolved, active configuration for a validation rule,
/// bundling both orchestration (severity) and execution parameters.
class RuleConfig {
  RuleConfig({required this.severity, CustomRuleParameters? parameters})
    : parameters = parameters ?? CustomRuleParameters({});

  final AnalysisSeverity severity;

  final CustomRuleParameters parameters;
}

/// Represents a configuration override patch containing nullable parameters.
/// Used during validation session configuration inheritance to resolve target-specific
/// overrides without wiping out unspecified base/global parameters.
class RuleConfigPatch {
  const RuleConfigPatch({this.severity, this.parameters});

  /// The overridden severity value. If null, the base configuration's severity is preserved.
  final AnalysisSeverity? severity;

  /// The overridden parameters. Keys containing null values (e.g. from YAML `~`) will remove
  /// the parameter from the base configuration during merging.
  final CustomRuleParameters? parameters;

  /// Creates a new [RuleConfig] by layering this patch's overrides over a [base] configuration.
  RuleConfig applyTo(RuleConfig base) {
    return RuleConfig(
      severity: severity ?? base.severity,
      parameters: parameters != null
          ? _mergeParameters(base.parameters, parameters!)
          : base.parameters,
    );
  }

  static CustomRuleParameters _mergeParameters(
    CustomRuleParameters base,
    CustomRuleParameters patch,
  ) {
    final merged = Map<String, dynamic>.from(base.params);
    for (final MapEntry<String, dynamic> entry in patch.params.entries) {
      if (entry.value == null) {
        merged.remove(entry.key);
      } else {
        merged[entry.key] = entry.value;
      }
    }
    return CustomRuleParameters(merged);
  }
}
