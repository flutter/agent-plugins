// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'models/analysis_severity.dart';
import 'models/check_type.dart';
import 'models/custom_rule_options.dart';
import 'models/skill_context.dart';
import 'models/skill_rule.dart';
import 'models/validation_error.dart';
import 'models/validation_result.dart';
import 'rule_registry.dart';
import 'rules/path_does_not_exist_rule.dart';

final _log = Logger('dart_skills_lint');

/// Validates agent skill directories against the Agent Skills specification.
class Validator {
  /// Creates a validator with optional rule severities, custom rules, and rule options.
  ///
  /// * [customRuleSeverities] overrides default severities of rules (e.g. mapping a rule to [AnalysisSeverity.disabled] or [AnalysisSeverity.warning]).
  /// * [customRules] specifies custom rules to be included in the validation.
  /// * [ruleOptions] maps rule names to their rule-specific custom options maps (e.g. passing regex patterns, thresholds, lists).
  Validator({
    Map<String, AnalysisSeverity>? customRuleSeverities,
    List<SkillRule>? customRules,
    Map<String, CustomRuleOptions>? ruleOptions,
  }) : _customRuleSeverities = customRuleSeverities ?? {},
       _rules = _buildRules(customRuleSeverities ?? {}, customRules ?? [], ruleOptions ?? {});
  static const String _skillFileName = SkillContext.skillFileName;

  /// The name of the special check for missing files or directories.
  static const String pathDoesNotExist = 'path-does-not-exist';

  /// The name of the special check for inaccessible files.
  static const String skillFileInaccessible = 'skill-file-inaccessible';

  /// The name of the special check for unexpected errors.
  static const String unexpectedError = 'unexpected-error';

  final Map<String, AnalysisSeverity> _customRuleSeverities;
  final List<SkillRule> _rules;

  /// Returns the rules used by this validator.
  List<SkillRule> get rules => _rules;

  AnalysisSeverity _getSeverity(String name, AnalysisSeverity defaultSeverity) {
    return _customRuleSeverities[name] ?? defaultSeverity;
  }

  /// Validates a single skill directory.
  ///
  /// Scans the directory for `SKILL.md`, parses its YAML metadata, and validates
  /// constraints like name format and field lengths using registered rules.
  Future<ValidationResult> validate(Directory dir) async {
    final validationErrors = <ValidationError>[];
    final skillMdFile = File(p.join(dir.path, _skillFileName));
    final bool skillMdExists = dir.existsSync() && skillMdFile.existsSync();

    var content = '';
    YamlMap? parsedYaml;
    String? yamlParsingError;

    if (skillMdExists) {
      try {
        content = await skillMdFile.readAsString();
      } on FileSystemException catch (e) {
        validationErrors.add(
          ValidationError(
            ruleId: skillFileInaccessible,
            file: skillMdFile.path,
            message: 'Failed to read $_skillFileName: $e',
            severity: _getSeverity(skillFileInaccessible, AnalysisSeverity.error),
          ),
        );
        return ValidationResult(validationErrors: validationErrors);
      } catch (e) {
        validationErrors.add(
          ValidationError(
            ruleId: unexpectedError,
            file: skillMdFile.path,
            message: 'Unexpected error reading $_skillFileName: $e',
            severity: _getSeverity(unexpectedError, AnalysisSeverity.error),
          ),
        );
        return ValidationResult(validationErrors: validationErrors);
      }

      try {
        final RegExpMatch? match = SkillContext.skillStartRegex.firstMatch(content);
        if (match != null) {
          final String yamlStr = match.group(1)!;
          final Object? doc = loadYaml(yamlStr);
          if (doc is YamlMap) {
            parsedYaml = doc;
          } else {
            yamlParsingError = 'YAML frontmatter is not a map';
          }
        } else {
          yamlParsingError = 'Missing YAML metadata in $_skillFileName';
        }
      } catch (e) {
        yamlParsingError = 'Failed to parse YAML: $e';
      }
    }

    final context = SkillContext(
      directory: dir,
      rawContent: content,
      parsedYaml: parsedYaml,
      yamlParsingError: yamlParsingError,
    );

    for (final SkillRule rule in _rules) {
      if (!skillMdExists && rule.name != PathDoesNotExistRule.ruleName) {
        continue;
      }
      final List<ValidationError> errors = await rule.validate(context);
      for (final error in errors) {
        if (error.severity != rule.severity) {
          _log.warning(
            'Rule "${rule.name}" used severity ${error.severity} instead of defined ${rule.severity}.',
          );
        }
      }
      validationErrors.addAll(errors);
    }

    return ValidationResult(validationErrors: validationErrors, context: context);
  }

  /// Compiles the final list of active rules for the validator.
  ///
  /// * [customRuleSeverities] overrides default severities of rules (e.g. mapping a rule to [AnalysisSeverity.disabled] or [AnalysisSeverity.warning]).
  /// * [customRules] specifies custom rules to be included in the validation.
  /// * [ruleOptions] maps rule names to their rule-specific custom options maps (e.g. passing regex patterns, thresholds, lists).
  ///
  /// Rules configured with [AnalysisSeverity.disabled] are excluded.
  /// Throws an [ArgumentError] if a duplicate rule name is encountered.
  static List<SkillRule> _buildRules(
    Map<String, AnalysisSeverity> customRuleSeverities,
    List<SkillRule> customRules,
    Map<String, CustomRuleOptions> ruleOptions,
  ) {
    final rules = <SkillRule>[];
    final seenNames = <String>{};

    void addRule(SkillRule rule) {
      if (rule.severity != AnalysisSeverity.disabled) {
        if (seenNames.contains(rule.name)) {
          throw ArgumentError('Duplicate rule name detected: ${rule.name}');
        }
        seenNames.add(rule.name);
        rules.add(rule);
      }
    }

    for (final CheckType check in RuleRegistry.allChecks) {
      final AnalysisSeverity severity = customRuleSeverities[check.name] ?? check.defaultSeverity;
      final CustomRuleOptions? options = ruleOptions[check.name];
      final SkillRule? rule = RuleRegistry.createRule(check.name, severity, options);
      if (rule != null) {
        addRule(rule);
      }
    }

    customRules.forEach(addRule);

    return rules;
  }
}
