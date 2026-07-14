// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'custom_rule_options.dart';
import 'skill_rule.dart';

/// Intermediate abstract class for rules that support configuration options.
///
/// Concrete subclasses of [ConfigurableSkillRule] are compile-time required to pass
/// their custom options to the base class constructor. Option keys and types are
/// automatically validated against the rule's defined [allowedOptions] schema.
abstract class ConfigurableSkillRule extends SkillRule {
  ConfigurableSkillRule(this.customRuleOptions) {
    _validateOptions();
  }

  /// The parsed custom configuration options for this rule.
  final CustomRuleOptions? customRuleOptions;

  /// The schema mapping allowed options parameter keys to their expected Types.
  Map<String, Type> get allowedOptions;

  void _validateOptions() {
    final CustomRuleOptions? opts = customRuleOptions;
    if (opts == null) {
      return;
    }
    for (final String key in opts.keys) {
      if (!allowedOptions.containsKey(key)) {
        throw ArgumentError('Rule "$name" does not support option "$key".');
      }
      final Type? expectedType = allowedOptions[key];
      final Object? actualValue = opts[key];
      if (actualValue != null && actualValue.runtimeType != expectedType) {
        throw ArgumentError(
          'Option "$key" for rule "$name" must be of type $expectedType (found ${actualValue.runtimeType}).',
        );
      }
    }
  }
}
