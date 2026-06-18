// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: specify_nonobvious_local_variable_types yaml parsing has dynamic types.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';

import 'models/analysis_severity.dart';
import 'path_utils.dart';

final _log = Logger('dart_skills_lint');

class ConfigParser {
  static const _dartSkillsLintKey = 'dart_skills_lint';
  static const _rulesKey = 'rules';
  static const _directoriesKey = 'directories';
  static const _individualSkillsKey = 'individual_skills';
  static const _pathKey = 'path';
  static const _ignoreFileKey = 'ignore_file';

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
          final configuredRules = _parseRules(toolConfig);
          final directoryConfigs = _parseConfigList(toolConfig, _directoriesKey, parsingErrors);
          final individualSkillConfigs = _parseConfigList(
            toolConfig,
            _individualSkillsKey,
            parsingErrors,
          );

          return Configuration(
            directoryConfigs: directoryConfigs,
            individualSkillConfigs: individualSkillConfigs,
            configuredRules: configuredRules,
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

  /// Parses the global rules configuration from the `dart_skills_lint` map.
  /// Returns a map of rule names to their resolved `AnalysisSeverity`.
  static Map<String, AnalysisSeverity> _parseRules(YamlMap toolConfig) {
    final configuredRules = <String, AnalysisSeverity>{};
    if (toolConfig.containsKey(_rulesKey)) {
      final rules = toolConfig[_rulesKey];
      if (rules is YamlMap) {
        for (final key in rules.keys) {
          configuredRules[key.toString()] = _parseSeverity(rules[key]?.toString() ?? '');
        }
      }
    }
    return configuredRules;
  }

  /// Parses a list of targets (directories or individual skills) from the configuration.
  /// Validates keys for each entry and resolves path-specific rule overrides.
  /// Appends any parsing errors to `parsingErrors`.
  ///
  /// Each entry is parsed defensively: a bad `path:` / `ignore_file:` /
  /// `rules:` type emits a parsingErrors entry naming the offending field
  /// and the entry is skipped, but later entries in the same list
  /// still parse normally.
  static List<LintTargetConfig> _parseConfigList(
    YamlMap toolConfig,
    String configKey,
    List<String> parsingErrors,
  ) {
    final entryLabelCap = configKey == _directoriesKey
        ? 'Directory entry'
        : 'Individual skill entry';
    final entryLabelLower = configKey == _directoriesKey
        ? 'directory entry'
        : 'individual skill entry';
    final configs = <LintTargetConfig>[];
    if (toolConfig.containsKey(configKey)) {
      final items = toolConfig[configKey];
      if (items is YamlList) {
        for (final dir in items) {
          if (dir is! YamlMap || !dir.containsKey(_pathKey)) {
            continue;
          }

          final pathValue = dir[_pathKey];
          if (pathValue is! String) {
            parsingErrors.add(
              '$entryLabelCap "$_pathKey" must be a string; got "$pathValue" '
              '(${pathValue.runtimeType}). Skipping entry.',
            );
            continue;
          }
          final String path = pathValue;

          for (final key in dir.keys) {
            if (!_allowedDirectoryKeys.contains(key.toString())) {
              parsingErrors.add('Unrecognized key "$key" in $entryLabelLower for "$path".');
            }
          }

          final rules = <String, AnalysisSeverity>{};
          if (dir.containsKey(_rulesKey)) {
            final localRules = dir[_rulesKey];
            if (localRules is YamlMap) {
              for (final key in localRules.keys) {
                rules[key.toString()] = _parseSeverity(localRules[key]?.toString() ?? '');
              }
            } else {
              parsingErrors.add(
                '$entryLabelCap "$_rulesKey" for "$path" must be a map; '
                'got "$localRules" (${localRules.runtimeType}). Ignoring local rules.',
              );
            }
          }

          String? ignoreFile;
          if (dir.containsKey(_ignoreFileKey)) {
            final ignoreFileValue = dir[_ignoreFileKey];
            if (ignoreFileValue is String) {
              ignoreFile = ignoreFileValue;
            } else if (ignoreFileValue != null) {
              parsingErrors.add(
                '$entryLabelCap "$_ignoreFileKey" for "$path" must be a string; '
                'got "$ignoreFileValue" (${ignoreFileValue.runtimeType}). '
                'Falling back to the default ignore file.',
              );
            }
          }

          configs.add(LintTargetConfig(path: path, rules: rules, ignoreFile: ignoreFile));
        }
      }
    }
    return configs;
  }
}

/// Configuration for a specific directory containing skills, or an individual skill.
///
/// Allows overriding rules and specifying a custom ignore file for skills
/// located within or at this path.
class LintTargetConfig {
  LintTargetConfig({required this.path, required this.rules, this.ignoreFile});

  /// The path to the directory containing skills.
  ///
  /// Can be absolute or relative to the current working directory.
  /// Supports tilde expansion (e.g., `~/...`).
  final String path;
  final Map<String, AnalysisSeverity> rules;
  final String? ignoreFile;
}

/// Structured configuration for the linter.
class Configuration {
  Configuration({
    this.directoryConfigs = const [],
    this.individualSkillConfigs = const [],
    this.configuredRules = const {},
    this.parsingErrors = const [],
  });
  final List<LintTargetConfig> directoryConfigs;
  final List<LintTargetConfig> individualSkillConfigs;
  final Map<String, AnalysisSeverity> configuredRules;
  final List<String> parsingErrors;
}
