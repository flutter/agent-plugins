// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../rule_registry.dart';
import 'check_type.dart';
import 'custom_rule_options.dart';
import 'skill_rule.dart';

/// Intermediate abstract class for rules that support configuration options.
///
/// Concrete subclasses of [ConfigurableSkillRule] are compile-time required to pass
/// their custom options to the base class constructor. Option keys and types are
/// automatically validated against the rule's defined schema in [RuleRegistry].
abstract class ConfigurableSkillRule extends SkillRule {
  ConfigurableSkillRule(this.customRuleOptions) {
    _validateOptions();
  }

  /// The parsed custom configuration options for this rule.
  final CustomRuleOptions? customRuleOptions;

  void _validateOptions() {
    final CustomRuleOptions? opts = customRuleOptions;
    if (opts == null) {
      return;
    }
    // Rules must have a unique name so we can assume one match.
    final Iterable<CheckType> checkMatches = RuleRegistry.allChecks.where((c) => c.name == name);
    if (checkMatches.isEmpty) {
      return;
    }
    final CheckType check = checkMatches.first;
    final List<String> errors = check.validateOptions(opts);
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.join('\n'));
    }
  }
}
