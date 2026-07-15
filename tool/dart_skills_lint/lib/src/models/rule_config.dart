// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'analysis_severity.dart';
import 'custom_rule_options.dart';

/// Represents the resolved, active configuration for a validation rule,
/// bundling both orchestration (severity) and execution (custom options) parameters.
class RuleConfig {
  RuleConfig({required this.severity, CustomRuleOptions? options})
    : options = options ?? CustomRuleOptions({});

  final AnalysisSeverity severity;

  final CustomRuleOptions options;
}

/// Represents a configuration override patch containing nullable parameters.
/// Used during validation session configuration inheritance to resolve target-specific
/// overrides without wiping out unspecified base/global options.
class RuleConfigPatch {
  const RuleConfigPatch({this.severity, this.options});

  /// The overridden severity value. If null, the base configuration's severity is preserved.
  final AnalysisSeverity? severity;

  /// The overridden options. Keys containing null values (e.g. from YAML `~`) will remove
  /// the option from the base configuration during merging.
  final CustomRuleOptions? options;

  /// Creates a new [RuleConfig] by layering this patch's overrides over a [base] configuration.
  RuleConfig applyTo(RuleConfig base) {
    return RuleConfig(
      severity: severity ?? base.severity,
      options: options != null ? _mergeOptions(base.options, options!) : base.options,
    );
  }

  static CustomRuleOptions _mergeOptions(CustomRuleOptions base, CustomRuleOptions patch) {
    final merged = Map<String, dynamic>.from(base.params);
    for (final MapEntry<String, dynamic> entry in patch.params.entries) {
      if (entry.value == null) {
        merged.remove(entry.key);
      } else {
        merged[entry.key] = entry.value;
      }
    }
    return CustomRuleOptions(merged);
  }
}
