// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: specify_nonobvious_local_variable_types yaml parsing has dynamic types.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';

import 'models/analysis_severity.dart';
import 'models/check_type.dart';
import 'models/custom_rule_parameters.dart';
import 'models/rule_config.dart';
import 'path_utils.dart';
import 'rule_registry.dart';

final _log = Logger('dart_skills_lint');

class ConfigParser {
  static const _dartSkillsLintKey = 'dart_skills_lint';
  static const _rulesKey = 'rules';
  static const _directoriesKey = 'directories';
  static const _individualSkillsKey = 'individual_skills';
  static const _pathKey = 'path';
  static const _ignoreFileKey = 'ignore_file';
  static const _severityKey = 'severity';

  static const Set<String> _allowedTopLevelKeys = {
    _rulesKey,
    _directoriesKey,
    _individualSkillsKey,
  };
  static const Set<String> _allowedDirectoryKeys = {_pathKey, _rulesKey, _ignoreFileKey};

  static AnalysisSeverity _parseSeverity(String value) {
    if (value == 'error') {
      return AnalysisSeverity.error;
    }
    if (value == 'warning') {
      return AnalysisSeverity.warning;
    }
    if (value == 'disabled') {
      return AnalysisSeverity.disabled;
    }
    return AnalysisSeverity.disabled; // Default if unknown
  }

  /// Loads the configuration from the specified [path], or from the default
  /// `dart_skills_lint.yaml` if no path is provided.
  ///
  /// If a [path] is explicitly provided and the file does not exist, this
  /// method throws a [FileSystemException]. If no path is provided and the
  /// default file is missing, it returns an empty [Configuration].
  static Future<Configuration> loadConfig({String? path}) async {
    final String resolvedPath = expandPath(path ?? 'dart_skills_lint.yaml');
    final configFile = File(resolvedPath);

    if (!configFile.existsSync()) {
      if (path != null) {
        throw FileSystemException('Configuration file not found', resolvedPath);
      }
      return Configuration();
    }

    try {
      final String content = await configFile.readAsString();
      final yaml = loadYaml(content);
      if (yaml is YamlMap && yaml.containsKey(_dartSkillsLintKey)) {
        final toolConfig = yaml[_dartSkillsLintKey];
        if (toolConfig is YamlMap) {
          final parsingErrors = <String>[];

          _validateTopLevelKeys(toolConfig, parsingErrors);
          final rulesResult = _parseDefaultRules(toolConfig, parsingErrors);
          final directoryConfigs = _parseConfigList(toolConfig, _directoriesKey, parsingErrors);
          final individualSkillConfigs = _parseConfigList(
            toolConfig,
            _individualSkillsKey,
            parsingErrors,
          );

          return Configuration(
            directoryConfigs: directoryConfigs,
            individualSkillConfigs: individualSkillConfigs,
            ruleConfigs: rulesResult,
            parsingErrors: parsingErrors,
          );
        }
      }
    } catch (e) {
      final message = 'Failed to parse $resolvedPath: $e';
      _log.severe(message);
      return Configuration(parsingErrors: [message]);
    }
    return Configuration();
  }

  /// Validates that all keys at the top level of the `dart_skills_lint` configuration map are recognized.
  /// Appends error messages to `parsingErrors` for any unrecognized keys.
  static void _validateTopLevelKeys(YamlMap toolConfig, List<String> parsingErrors) {
    for (final key in toolConfig.keys) {
      if (!_allowedTopLevelKeys.contains(key.toString())) {
        parsingErrors.add('Unrecognized top-level key "$key" in dart_skills_lint configuration.');
      }
    }
  }

  /// Parses the project-wide default rule configurations from the top-level `rules` map.
  ///
  /// The settings parsed here serve as the global defaults that apply to all
  /// validated skills in the project. Any target-specific settings defined
  /// under `directories` or `individual_skills` will override these global defaults.
  ///
  /// Extracts both default severities and parameters, appending any parameter type or key
  /// validation errors to [parsingErrors].
  static Map<String, RuleConfigPatch> _parseDefaultRules(
    YamlMap toolConfig,
    List<String> parsingErrors,
  ) {
    if (toolConfig.containsKey(_rulesKey)) {
      final rules = toolConfig[_rulesKey];
      if (rules is YamlMap) {
        return _parseRulesMap(rules, parsingErrors, 'Global rules');
      }
    }
    return const {};
  }

  /// Iterates a YAML rules map and converts each entry into a [RuleConfigPatch].
  ///
  /// Validates that parameter keys and value types match their definitions in the registry,
  /// appending any validation errors to [parsingErrors] labeled by [contextLabel].
  static Map<String, RuleConfigPatch> _parseRulesMap(
    YamlMap rulesMap,
    List<String> parsingErrors,
    String contextLabel,
  ) {
    final ruleConfigs = <String, RuleConfigPatch>{};

    for (final key in rulesMap.keys) {
      final ruleName = key.toString();
      final value = rulesMap[key];

      // Rules must have a unique name so we can assume one match.
      final checkMatches = RuleRegistry.allChecks.where((c) => c.name == ruleName);
      final CheckType? check = checkMatches.isEmpty ? null : checkMatches.first;

      ruleConfigs[ruleName] = _parseRuleConfigPatch(value, check, parsingErrors, contextLabel);
    }

    return ruleConfigs;
  }

  /// Parses a single rule's configuration value into a [RuleConfigPatch].
  ///
  /// Supports simple scalar severity declarations (e.g., `rule-name: error`) as
  /// well as map declarations containing custom parameter overrides and severity
  /// settings (e.g., `rule-name: { severity: error, param: value }`). Validates
  /// any custom parameters against [check], appending schema validation errors
  /// to [parsingErrors] labeled with [contextLabel].
  static RuleConfigPatch _parseRuleConfigPatch(
    Object? value,
    CheckType? check,
    List<String> parsingErrors,
    String contextLabel,
  ) {
    if (value is! YamlMap) {
      final severity = _parseSeverity(value?.toString() ?? '');
      return RuleConfigPatch(severity: severity);
    }

    final severity = value.containsKey(_severityKey)
        ? _parseSeverity(value[_severityKey]?.toString() ?? '')
        : null;

    final parameters = <String, dynamic>{};
    for (final paramKey in value.keys) {
      final paramName = paramKey.toString();
      if (paramName != _severityKey) {
        parameters[paramName] = value[paramKey];
      }
    }

    final customParams = parameters.isNotEmpty ? CustomRuleParameters(parameters) : null;

    if (customParams != null && check != null) {
      final errors = check.validateParameters(customParams);
      for (final error in errors) {
        parsingErrors.add('$contextLabel: $error');
      }
    }

    return RuleConfigPatch(severity: severity, parameters: customParams);
  }

  /// Iterates a top-level YAML target list (`directories` or `individual_skills`)
  /// and parses each element into a [LintTargetConfig].
  ///
  /// Delegates validation of an individual list element to [_parseTargetEntry].
  /// Returns an empty list if [configKey] is omitted or not a list.
  static List<LintTargetConfig> _parseConfigList(
    YamlMap toolConfig,
    String configKey,
    List<String> parsingErrors,
  ) {
    if (!toolConfig.containsKey(configKey)) {
      return const [];
    }
    final items = toolConfig[configKey];
    if (items is! YamlList) {
      return const [];
    }

    final entryLabelCap = configKey == _directoriesKey
        ? 'Directory entry'
        : 'Individual skill entry';
    final entryLabelLower = configKey == _directoriesKey
        ? 'directory entry'
        : 'individual skill entry';

    final configs = <LintTargetConfig>[];
    for (final dir in items) {
      if (dir is! YamlMap || !dir.containsKey(_pathKey)) {
        continue;
      }
      final config = _parseTargetEntry(dir, entryLabelCap, entryLabelLower, parsingErrors);
      if (config != null) {
        configs.add(config);
      }
    }
    return configs;
  }

  /// Parses a single dictionary element from a target list (`directories` or `individual_skills`).
  ///
  /// Validates the `path` string and checks for unrecognized keys. Delegates
  /// parsing of sub-keys to [_parseLocalRulesForTarget] (`rules`) and
  /// [_parseIgnoreFileForTarget] (`ignore_file`). Returns `null` if `path` is
  /// invalid or missing.
  static LintTargetConfig? _parseTargetEntry(
    YamlMap dir,
    String entryLabelCap,
    String entryLabelLower,
    List<String> parsingErrors,
  ) {
    final pathValue = dir[_pathKey];
    if (pathValue is! String) {
      parsingErrors.add(
        '$entryLabelCap "$_pathKey" must be a string; got "$pathValue" '
        '(${pathValue.runtimeType}). Skipping entry.',
      );
      return null;
    }
    final String path = pathValue;

    for (final key in dir.keys) {
      if (!_allowedDirectoryKeys.contains(key.toString())) {
        parsingErrors.add('Unrecognized key "$key" in $entryLabelLower for "$path".');
      }
    }

    final ruleConfigs = _parseLocalRulesForTarget(dir, path, entryLabelCap, parsingErrors);

    final ignoreFile = _parseIgnoreFileForTarget(dir, path, entryLabelCap, parsingErrors);

    return LintTargetConfig(path: path, ruleConfigs: ruleConfigs, ignoreFile: ignoreFile);
  }

  /// Parses path-specific rule overrides under a target entry's `rules` key.
  ///
  /// Unlike [_parseDefaultRules], which sets global baselines, configurations
  /// parsed here apply only to skills within this specific target path.
  /// Delegates to [_parseRulesMap].
  static Map<String, RuleConfigPatch> _parseLocalRulesForTarget(
    YamlMap dir,
    String path,
    String entryLabelCap,
    List<String> parsingErrors,
  ) {
    if (!dir.containsKey(_rulesKey)) {
      return const {};
    }
    final localRules = dir[_rulesKey];
    if (localRules is YamlMap) {
      return _parseRulesMap(localRules, parsingErrors, '$entryLabelCap rules for "$path"');
    }
    parsingErrors.add(
      '$entryLabelCap "$_rulesKey" for "$path" must be a map; '
      'got "$localRules" (${localRules.runtimeType}). Ignoring local rules.',
    );
    return const {};
  }

  /// Parses the custom ignore file path under a target entry's `ignore_file` key.
  ///
  /// Returns `null` if omitted. If present but not a string, appends a type
  /// error to [parsingErrors] and returns `null` to fall back to the default
  /// ignore file.
  static String? _parseIgnoreFileForTarget(
    YamlMap dir,
    String path,
    String entryLabelCap,
    List<String> parsingErrors,
  ) {
    if (!dir.containsKey(_ignoreFileKey)) {
      return null;
    }
    final ignoreFileValue = dir[_ignoreFileKey];
    if (ignoreFileValue is String) {
      return ignoreFileValue;
    }
    if (ignoreFileValue != null) {
      parsingErrors.add(
        '$entryLabelCap "$_ignoreFileKey" for "$path" must be a string; '
        'got "$ignoreFileValue" (${ignoreFileValue.runtimeType}). '
        'Falling back to the default ignore file.',
      );
    }
    return null;
  }
}

/// Configuration for a specific directory containing skills, or an individual skill.
///
/// Allows overriding rules and specifying a custom ignore file for skills
/// located within or at this path.
class LintTargetConfig {
  LintTargetConfig({required this.path, required this.ruleConfigs, this.ignoreFile});

  /// The path to the directory containing skills.
  ///
  /// Can be absolute or relative to the current working directory.
  /// Supports tilde expansion (e.g., `~/...`).
  final String path;
  final Map<String, RuleConfigPatch> ruleConfigs;
  final String? ignoreFile;

  // TODO(reidbaker): https://github.com/flutter/agent-plugins/issues/179
  @Deprecated('Use ruleConfigs instead')
  Map<String, AnalysisSeverity> get rules {
    final resolvedSeverities = <String, AnalysisSeverity>{};
    for (final entry in ruleConfigs.entries) {
      final AnalysisSeverity? severity = entry.value.severity;
      if (severity != null) {
        resolvedSeverities[entry.key] = severity;
      }
    }
    return resolvedSeverities;
  }
}

/// Structured configuration for the linter.
class Configuration {
  Configuration({
    this.directoryConfigs = const [],
    this.individualSkillConfigs = const [],
    this.ruleConfigs = const {},
    this.parsingErrors = const [],
  });
  final List<LintTargetConfig> directoryConfigs;
  final List<LintTargetConfig> individualSkillConfigs;
  final Map<String, RuleConfigPatch> ruleConfigs;
  final List<String> parsingErrors;

  // TODO(reidbaker): https://github.com/flutter/agent-plugins/issues/179
  @Deprecated('Use ruleConfigs instead')
  Map<String, AnalysisSeverity> get configuredRules {
    final resolvedSeverities = <String, AnalysisSeverity>{};
    for (final entry in ruleConfigs.entries) {
      final AnalysisSeverity? severity = entry.value.severity;
      if (severity != null) {
        resolvedSeverities[entry.key] = severity;
      }
    }
    return resolvedSeverities;
  }
}
