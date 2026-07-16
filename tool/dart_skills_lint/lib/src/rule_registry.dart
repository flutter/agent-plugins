// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'models/analysis_severity.dart';
import 'models/check_type.dart';
import 'models/custom_rule_parameters.dart';
import 'models/rule_parameter_type.dart';
import 'models/skill_rule.dart';
import 'rules/absolute_paths_rule.dart';
import 'rules/description_length_rule.dart';
import 'rules/disallowed_field_rule.dart';
import 'rules/name_format_rule.dart';
import 'rules/path_does_not_exist_rule.dart';
import 'rules/prevent_skills_sh_publishing_rule.dart';
import 'rules/relative_paths_rule.dart';
import 'rules/trailing_whitespace_rule.dart';
import 'rules/valid_yaml_metadata_rule.dart';

/// Registry of all built-in rules.
class RuleRegistry {
  /// All registered rules and their default configurations.
  // TODO(reidbaker): Break out flags vs options here so entry_point can generate appropriate CLI arguments.
  static final List<CheckType> allChecks = [
    const CheckType(
      name: PathDoesNotExistRule.ruleName,
      defaultSeverity: AnalysisSeverity.error,
      help: 'Check if SKILL.md and directory structure are correct.',
      parameterSchema: {PathDoesNotExistRule.excludeParameter: RuleParameterType.regExp},
    ),
    const CheckType(
      name: AbsolutePathsRule.ruleName,
      defaultSeverity: AbsolutePathsRule.defaultSeverity,
      help: 'Check if absolute paths exist.',
    ),
    const CheckType(
      name: DescriptionLengthRule.ruleName,
      defaultSeverity: DescriptionLengthRule.defaultSeverity,
      help: 'Check if description is too long.',
    ),
    const CheckType(
      name: DisallowedFieldRule.ruleName,
      defaultSeverity: DisallowedFieldRule.defaultSeverity,
      help: 'Check for disallowed fields in YAML metadata.',
    ),
    const CheckType(
      name: PreventSkillsShPublishingRule.ruleName,
      defaultSeverity: PreventSkillsShPublishingRule.defaultSeverity,
      help: 'Check if skill has metadata: internal: true to prevent publishing.',
    ),
    const CheckType(
      name: NameFormatRule.ruleName,
      defaultSeverity: NameFormatRule.defaultSeverity,
      help: 'Check if skill name is invalid.',
    ),
    const CheckType(
      name: RelativePathsRule.ruleName,
      defaultSeverity: RelativePathsRule.defaultSeverity,
      help: 'Check if relative paths exist.',
    ),
    const CheckType(
      name: TrailingWhitespaceRule.ruleName,
      defaultSeverity: TrailingWhitespaceRule.defaultSeverity,
      help: 'Check for trailing whitespace (allows exactly 2 spaces for line breaks).',
    ),
    const CheckType(
      name: ValidYamlMetadataRule.ruleName,
      defaultSeverity: ValidYamlMetadataRule.defaultSeverity,
      help: 'Check if YAML metadata is valid.',
    ),
  ];

  /// Creates a rule instance by name, or returns null if not a class-based rule.
  static SkillRule? createRule(
    String name,
    AnalysisSeverity severity, [
    CustomRuleParameters? parameters,
  ]) {
    switch (name) {
      case PathDoesNotExistRule.ruleName:
        RegExp? excludeRegExp;
        final String? excludePattern = parameters?.getString(PathDoesNotExistRule.excludeParameter);
        if (excludePattern != null && excludePattern.isNotEmpty) {
          excludeRegExp = RegExp(excludePattern);
        }
        return PathDoesNotExistRule(severity: severity, excludeRegExp: excludeRegExp);
      case AbsolutePathsRule.ruleName:
        return AbsolutePathsRule(severity: severity);
      case DescriptionLengthRule.ruleName:
        return DescriptionLengthRule(severity: severity);
      case DisallowedFieldRule.ruleName:
        return DisallowedFieldRule(severity: severity);
      case PreventSkillsShPublishingRule.ruleName:
        return PreventSkillsShPublishingRule(severity: severity);
      case NameFormatRule.ruleName:
        return NameFormatRule(severity: severity);
      case RelativePathsRule.ruleName:
        return RelativePathsRule(severity: severity);
      case TrailingWhitespaceRule.ruleName:
        return TrailingWhitespaceRule(severity: severity);
      case ValidYamlMetadataRule.ruleName:
        return ValidYamlMetadataRule(severity: severity);
      default:
        return null;
    }
  }
}
