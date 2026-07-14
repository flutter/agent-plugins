// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'config_parser.dart';
import 'fixable_rule.dart';
import 'models/analysis_severity.dart';
import 'models/ignore_entry.dart';
import 'models/skill_context.dart';
import 'models/skill_rule.dart';
import 'models/skills_ignores.dart';
import 'models/validation_error.dart';
import 'models/validation_result.dart';
import 'path_utils.dart';
import 'skills_ignores_storage.dart';
import 'validator.dart';

final _log = Logger('dart_skills_lint');

/// Default filename for the per-run ignore baseline file.
///
/// Referenced both by production code (the `--generate-baseline` help text in
/// the CLI) and by tests, so this is intentionally not `@visibleForTesting`.
const defaultIgnoreFileName = 'dart_skills_lint_ignore.json';

@visibleForTesting
const skillIsValidMsg = '  Skill is valid.';
@visibleForTesting
const skillIsInvalidMsg = '  Skill is invalid:';
@visibleForTesting
const warningsMsg = 'Warnings:';

@visibleForTesting
const evaluatingDirMsg = 'Evaluating directory:';

@visibleForTesting
const directoryErrorMsg = 'Directory error:';

/// Per-invocation state and orchestration for skill validation.
///
/// One session is constructed per CLI invocation (or embedded call). The
/// session aggregates configuration options, custom rules, ignores, and CLI overrides,
/// then orchestrates the validation of multiple target skill directories.
///
/// Callers invoke [processIndividualSkill] for each `--skill` path and
/// [processSkillRoot] for each `--skills-directory` path, then optionally
/// [reportNoSkillsValidated] to emit the "no skills found" diagnostics.
/// The failure state of the session is exposed via [anyFailed] and [anySkillsValidated].
class ValidationSession {
  /// Creates a validation session with the specified configuration, overrides, and rules.
  ///
  /// * [config] is the parsed YAML configuration file settings.
  /// * [resolvedRuleSeverities] maps rule names to custom severities override mapping.
  /// * [resolvedRuleOptions] maps rule names to rule-specific custom options overrides (e.g., CLI-passed options).
  /// * [ignoreFileOverride] specifies a custom file path containing lint ignores to load.
  /// * [customRules] contains programmatically injected custom skill rule checks.
  /// * [printWarnings] controls whether warnings are printed to stdout.
  /// * [fastFail] controls whether validation stops immediately on the first error.
  /// * [quiet] controls whether success messages and other info logs are silenced.
  /// * [generateBaseline] controls whether the validation should output/update baseline ignores.
  /// * [fix] controls whether to apply fixable rule modifications directly to files.
  /// * [fixApply] is the deprecated flag indicating if fixes should be automatically applied.
  ValidationSession({
    required this.config,
    this.resolvedRuleSeverities = const {},
    this.resolvedRuleOptions = const {},
    required this.ignoreFileOverride,
    required this.customRules,
    required this.printWarnings,
    required this.fastFail,
    required this.quiet,
    required this.generateBaseline,
    required this.fix,
    required this.fixApply,
  }) : _normalizedDirectoryConfigs = [
         for (final dc in [...config.directoryConfigs, ...config.individualSkillConfigs])
           (normalizedPath: p.absolute(p.normalize(expandPath(dc.path))), config: dc),
       ];

  final Configuration config;
  final Map<String, AnalysisSeverity> resolvedRuleSeverities;
  final Map<String, Map<String, dynamic>> resolvedRuleOptions;
  final String? ignoreFileOverride;
  final List<SkillRule> customRules;
  final bool printWarnings;
  final bool fastFail;
  final bool quiet;
  final bool generateBaseline;
  final bool fix;
  final bool fixApply;

  /// [config.directoryConfigs] with each `path` pre-normalized once.
  ///
  /// `config` is static for the lifetime of a session, so we pay the
  /// `p.normalize` cost up front instead of once per skill in
  /// [_resolveRulesForPath] and [_resolveIgnoreFile].
  final List<({String normalizedPath, LintTargetConfig config})> _normalizedDirectoryConfigs;

  bool _anyFailed = false;
  bool _anySkillsValidated = false;

  bool get anyFailed => _anyFailed;
  bool get anySkillsValidated => _anySkillsValidated;

  /// Validates a single skill directory passed via `--skill` / `-s`.
  ///
  /// Returns `true` if the caller should continue iterating, `false` to
  /// stop. Only a real validation failure under [fastFail] returns `false`;
  /// a missing directory contributes to [anyFailed] but still allows the
  /// caller to continue.
  Future<bool> processIndividualSkill(String skillPath) async {
    final String normalizedSkillPath = p.normalize(expandPath(skillPath));
    if (!quiet) {
      _log.info('$evaluatingDirMsg $normalizedSkillPath');
    }
    final skillDir = Directory(normalizedSkillPath);

    if (!skillDir.existsSync()) {
      _log.severe('Specified skill directory does not exist: $normalizedSkillPath');
      _anyFailed = true;
      return true;
    }

    final Map<String, AnalysisSeverity> localRuleSeverities = resolveRuleSeveritiesForPath(
      normalizedSkillPath,
    );
    final Map<String, Map<String, dynamic>> localRuleOptions = resolveRuleOptionsForPath(
      normalizedSkillPath,
    );
    final String? localIgnoreFile = resolveIgnoreFile(normalizedSkillPath);
    final validator = Validator(
      customRuleSeverities: localRuleSeverities,
      customRules: customRules,
      ruleOptions: localRuleOptions,
    );

    final ({SkillsIgnores ignores, String ignorePath}) loaded = await _loadIgnores(
      localIgnoreFile,
      skillDir,
    );
    final SkillsIgnores ignores = loaded.ignores;
    final String skillName = p.basename(skillDir.path);
    final List<IgnoreEntry> skillIgnores = ignores.skills[skillName] ?? [];

    _anySkillsValidated = true;
    final ValidationResult finalResult = await _runValidationWorkflow(
      skillDir: skillDir,
      validator: validator,
      ignores: ignores,
    );

    if (generateBaseline) {
      await _saveBaseline(loaded.ignorePath, ignores);
    } else {
      final String fullPath = p.absolute(skillDir.path);
      for (final ignore in skillIgnores) {
        if (!ignore.used) {
          _log.info(
            "Stale ignore entry found for rule '${ignore.ruleId}' in skill "
            "'$skillName' at '$fullPath'. Consider removing it.",
          );
        }
      }
    }

    if (!finalResult.isValid) {
      _anyFailed = true;
      if (fastFail) {
        return false;
      }
    }
    return true;
  }

  /// Validates every skill directory under a root passed via
  /// `--skills-directory` / `-d`.
  ///
  /// Returns `true` if the caller should continue iterating, `false` to
  /// stop. Missing-root and listing-failure errors contribute to [anyFailed]
  /// but allow the caller to continue. After a successful iteration, returns
  /// `false` if [fastFail] is set and any failure has accumulated across the
  /// run so far.
  Future<bool> processSkillRoot(String rootPath) async {
    final String normalizedRootPath = p.normalize(expandPath(rootPath));
    if (!quiet) {
      _log.info('$evaluatingDirMsg $normalizedRootPath');
    }
    final rootDir = Directory(normalizedRootPath);

    if (!rootDir.existsSync()) {
      _log.severe('Specified root directory does not exist: $normalizedRootPath');
      _anyFailed = true;
      return true;
    }

    List<FileSystemEntity> entities;
    try {
      entities = await rootDir.list().toList();
    } catch (_) {
      _log.severe('  $directoryErrorMsg');
      _log.severe('    - Failed to list children of: $normalizedRootPath');
      _anyFailed = true;
      return true;
    }
    entities.sort((a, b) => a.path.compareTo(b.path));

    // Keep a cache of loaded ignores to avoid loading/saving the same ignore file multiple times,
    // and to accumulate ignore usages correctly across all skills.
    final Map<String, SkillsIgnores> loadedIgnoresCache = {};

    for (final entity in entities) {
      if (entity is! Directory) {
        continue;
      }
      if (p.basename(entity.path).startsWith('.')) {
        continue;
      }

      final String normalizedSkillPath = p.normalize(entity.path);
      final Map<String, AnalysisSeverity> localRuleSeverities = resolveRuleSeveritiesForPath(
        normalizedSkillPath,
      );
      final Map<String, Map<String, dynamic>> localRuleOptions = resolveRuleOptionsForPath(
        normalizedSkillPath,
      );
      final String? localIgnoreFile = resolveIgnoreFile(normalizedSkillPath);
      final validator = Validator(
        customRuleSeverities: localRuleSeverities,
        customRules: customRules,
        ruleOptions: localRuleOptions,
      );

      final String ignorePath = localIgnoreFile != null
          ? p.normalize(expandPath(localIgnoreFile))
          : p.join(rootDir.path, defaultIgnoreFileName);

      final SkillsIgnores ignores;
      if (loadedIgnoresCache.containsKey(ignorePath)) {
        ignores = loadedIgnoresCache[ignorePath]!;
      } else {
        final ({SkillsIgnores ignores, String ignorePath}) loaded = await _loadIgnores(
          localIgnoreFile,
          rootDir,
        );
        ignores = loaded.ignores;
        loadedIgnoresCache[ignorePath] = ignores;
      }

      _anySkillsValidated = true;
      final ValidationResult finalResult = await _runValidationWorkflow(
        skillDir: entity,
        validator: validator,
        ignores: ignores,
      );

      if (!finalResult.isValid) {
        _anyFailed = true;
        if (fastFail) {
          break;
        }
      }
    }

    // Save baselines and report stale entries for each loaded ignore file
    for (final MapEntry<String, SkillsIgnores> entry in loadedIgnoresCache.entries) {
      final String ignorePath = entry.key;
      final SkillsIgnores ignores = entry.value;

      if (generateBaseline) {
        await _saveBaseline(ignorePath, ignores);
      } else {
        for (final MapEntry<String, List<IgnoreEntry>> skillEntry in ignores.skills.entries) {
          final String skillName = skillEntry.key;
          for (final IgnoreEntry ignore in skillEntry.value) {
            if (!ignore.used) {
              final String fullPath = p.absolute(p.join(rootDir.path, skillName));
              _log.info(
                "Stale ignore entry found for rule '${ignore.ruleId}' in skill "
                "'$skillName' at '$fullPath'. Consider removing it.",
              );
            }
          }
        }
      }
    }

    return !(_anyFailed && fastFail);
  }

  /// If no skills were validated across the whole run, emit appropriate
  /// diagnostics and mark the session as failed.
  void reportNoSkillsValidated(List<String> rootPaths) {
    if (_anySkillsValidated) {
      return;
    }

    var foundSingleSkillPassedToD = false;
    for (final rootPath in rootPaths) {
      final String expandedRootPath = expandPath(rootPath);
      final skillMdFile = File(p.join(expandedRootPath, SkillContext.skillFileName));
      if (skillMdFile.existsSync()) {
        _log.severe(
          'Directory "$expandedRootPath" appears to be an individual skill. '
          'Use --skill / -s instead of -d / --skills-directory.',
        );
        foundSingleSkillPassedToD = true;
      }
    }
    if (!foundSingleSkillPassedToD) {
      _log.severe('No skills found to validate in the specified directories.');
    }
    _anyFailed = true;
  }

  @visibleForTesting
  Map<String, AnalysisSeverity> resolveRuleSeveritiesForPath(String path) {
    final String normalizedPath = p.absolute(path);
    final localRules = <String, AnalysisSeverity>{};

    // 1. Global Config (from YAML)
    localRules.addAll(config.ruleSeverities);

    // 2. Path-Specific Config (from YAML)
    for (final ({String normalizedPath, LintTargetConfig config}) entry
        in _normalizedDirectoryConfigs) {
      final String configPath = entry.normalizedPath;
      if (p.equals(configPath, normalizedPath) || p.isWithin(configPath, normalizedPath)) {
        localRules.addAll(entry.config.ruleSeverities);
      }
    }

    // 3. Overrides (CLI flags or API caller) take highest precedence
    localRules.addAll(resolvedRuleSeverities);

    return localRules;
  }

  /// Resolves the final rule options configuration for a specific file or directory path.
  ///
  /// Merges options in order of precedence (highest to lowest):
  /// 1. Command-line overrides (`resolvedRuleOptions`), where a `null` value indicates
  ///    the option is cleared.
  /// 2. Target-specific configurations in `dart_skills_lint.yaml` that match [path].
  /// 3. Global configurations defined in `dart_skills_lint.yaml`.
  ///
  /// Returns a map where:
  /// * The outer key is the rule name (e.g., `'path-does-not-exist'`).
  /// * The inner map contains the resolved key-value options for that rule (e.g., `{'exclude': '.*-workspace'}`).
  @visibleForTesting
  Map<String, Map<String, dynamic>> resolveRuleOptionsForPath(String path) {
    final String targetPath = p.absolute(path);
    final resolved = <String, Map<String, dynamic>>{};

    // Step 1: Initialize with global rule options from configuration file.
    final Map<String, Map<String, dynamic>>? globalOptions = config.globalRuleOptions;
    if (globalOptions != null) {
      for (final MapEntry<String, Map<String, dynamic>> entry in globalOptions.entries) {
        resolved[entry.key] = Map<String, dynamic>.from(entry.value);
      }
    }

    // Step 2: Merge in path-specific rule options for matching targets.
    for (final ({String normalizedPath, LintTargetConfig config}) entry
        in _normalizedDirectoryConfigs) {
      final String configPath = entry.normalizedPath;
      final bool isMatch = p.equals(configPath, targetPath) || p.isWithin(configPath, targetPath);

      if (isMatch && entry.config.ruleOptions != null) {
        for (final MapEntry<String, Map<String, dynamic>> ruleEntry
            in entry.config.ruleOptions!.entries) {
          resolved[ruleEntry.key] = Map<String, dynamic>.from(ruleEntry.value);
        }
      }
    }

    // Step 3: Apply CLI overrides (command-line options take highest precedence).
    // An override value of `null` explicitly removes/clears the option.
    for (final MapEntry<String, Map<String, dynamic>> ruleOverrideEntry
        in resolvedRuleOptions.entries) {
      final String ruleName = ruleOverrideEntry.key;
      final Map<String, dynamic> overrides = ruleOverrideEntry.value;

      final Map<String, dynamic> currentOptions = resolved[ruleName] ?? <String, dynamic>{};

      for (final MapEntry<String, dynamic> optionEntry in overrides.entries) {
        final String optionName = optionEntry.key;
        final Object? value = optionEntry.value;

        if (value == null) {
          currentOptions.remove(optionName);
        } else {
          currentOptions[optionName] = value;
        }
      }

      if (currentOptions.isNotEmpty) {
        resolved[ruleName] = currentOptions;
      } else {
        resolved.remove(ruleName);
      }
    }

    return resolved;
  }

  @visibleForTesting
  String? resolveIgnoreFile(String path) {
    final String normalizedPath = p.absolute(path);
    if (ignoreFileOverride != null) {
      return ignoreFileOverride;
    }
    String? resolvedIgnoreFile;
    for (final ({String normalizedPath, LintTargetConfig config}) entry
        in _normalizedDirectoryConfigs) {
      final String configPath = entry.normalizedPath;
      if (p.equals(configPath, normalizedPath) || p.isWithin(configPath, normalizedPath)) {
        final String? ignoreFile = entry.config.ignoreFile;
        if (ignoreFile != null) {
          resolvedIgnoreFile = ignoreFile;
        }
      }
    }
    return resolvedIgnoreFile;
  }

  /// Loads the ignore JSON for a root, returning both the parsed
  /// [SkillsIgnores] and the resolved on-disk path it came from (or where it
  /// would be written).
  ///
  /// Returning the [SkillsIgnores] object (not just `.skills`) lets callers
  /// mutate it in memory across all skills in a root and then save it once,
  /// instead of doing a load+save round-trip per skill.
  Future<({SkillsIgnores ignores, String ignorePath})> _loadIgnores(
    String? localIgnoreFile,
    Directory rootDir,
  ) async {
    final String ignorePath = localIgnoreFile != null
        ? p.normalize(expandPath(localIgnoreFile))
        : p.join(rootDir.path, defaultIgnoreFileName);

    final file = File(ignorePath);

    if (file.existsSync()) {
      final storage = SkillsIgnoresStorage();
      final SkillsIgnores ignores = await storage.load(ignorePath);
      return (ignores: ignores, ignorePath: ignorePath);
    }

    // If a custom ignore file was specified but not found, create an empty one
    // so the user can start adding ignores to it.
    if (localIgnoreFile != null) {
      _log.warning('File not found generating-baseline');
      try {
        await file.writeAsString(jsonEncode({SkillsIgnores.skillsKey: <String, dynamic>{}}));
      } catch (_) {
        // Ignore write errors, we will just return empty ignores.
      }
    }

    return (ignores: SkillsIgnores(skills: {}), ignorePath: ignorePath);
  }

  void _applyIgnores(ValidationResult result, List<IgnoreEntry> ignores) {
    // Pre-normalize ignore filenames once so the inner loop below is a
    // straight string comparison instead of repeated path normalization.
    final List<({IgnoreEntry entry, String normalizedFileName})> preNormalizedIgnores = [
      for (final ignore in ignores)
        (entry: ignore, normalizedFileName: p.normalize(ignore.fileName)),
    ];

    for (final ValidationError error in result.validationErrors) {
      if (error.isIgnored) {
        continue;
      }
      final String normalizedErrorFile = p.normalize(error.file);
      for (final pair in preNormalizedIgnores) {
        final IgnoreEntry ignore = pair.entry;
        if (ignore.ruleId == error.ruleId && pair.normalizedFileName == normalizedErrorFile) {
          error.isIgnored = true;
          ignore.used = true;
          break;
        }
      }
    }
  }

  /// Validates [skillDir], applies fixes if requested, and (when
  /// [generateBaseline] is set) updates [ignores] in memory with any new
  /// baseline entries for this skill. The caller is responsible for
  /// persisting [ignores] to disk once after all skills are processed —
  /// see [_saveBaseline].
  Future<ValidationResult> _runValidationWorkflow({
    required Directory skillDir,
    required Validator validator,
    required SkillsIgnores ignores,
  }) async {
    final String skillName = p.basename(skillDir.path);
    final List<IgnoreEntry> skillIgnores = ignores.skills[skillName] ?? [];

    final ValidationResult result = await _validateSingleSkill(
      skillDir: skillDir,
      validator: validator,
      skillIgnores: skillIgnores,
    );

    final ValidationResult finalResult = await _applyFixesIfNeeded(
      skillDir: skillDir,
      result: result,
      validator: validator,
      skillIgnores: skillIgnores,
    );

    if (generateBaseline) {
      _updateBaselineForSkill(ignores, finalResult, skillName);
    }

    return finalResult;
  }

  Future<ValidationResult> _validateSingleSkill({
    required Directory skillDir,
    required Validator validator,
    required List<IgnoreEntry> skillIgnores,
  }) async {
    final String skillName = p.basename(skillDir.path);
    if (!quiet) {
      _log.info('--- Validating skill: $skillName ---');
    }
    final ValidationResult result = await validator.validate(skillDir);
    _applyIgnores(result, skillIgnores);
    _printValidationResult(result);
    return result;
  }

  Future<ValidationResult> _applyFixesIfNeeded({
    required Directory skillDir,
    required ValidationResult result,
    required Validator validator,
    required List<IgnoreEntry> skillIgnores,
  }) async {
    if (!fix && !fixApply) {
      return result;
    }

    final SkillContext? context = result.context;
    if (context == null) {
      return result;
    }

    final String skillName = p.basename(skillDir.path);
    final skillMdFile = File(p.join(skillDir.path, SkillContext.skillFileName));
    if (!skillMdFile.existsSync()) {
      return result;
    }

    String currentContent = context.rawContent;
    final originalContent = currentContent;
    var modified = false;

    for (final SkillRule rule in validator.rules) {
      if (rule is FixableRule) {
        final bool hasErrors = result.validationErrors.any(
          (e) => e.ruleId == rule.name && !e.isIgnored,
        );
        if (hasErrors) {
          try {
            final String newContent = await rule.fix(
              SkillContext.skillFileName,
              currentContent,
              context.directory,
            );
            if (newContent != currentContent) {
              currentContent = newContent;
              modified = true;
            }
          } catch (e) {
            _log.severe("  Failed to apply fix for rule '${rule.name}': $e");
          }
        }
      }
    }

    if (modified) {
      if (fixApply) {
        await skillMdFile.writeAsString(currentContent);
        if (!quiet) {
          _log.info('  Applied fixes for $skillName');
        }
        final ValidationResult newResult = await validator.validate(skillDir);
        _applyIgnores(newResult, skillIgnores);
        return newResult;
      } else if (fix) {
        if (!quiet) {
          _log.info('  [Dry Run] Proposed changes for $skillName (SKILL.md):');
          _printDiff(originalContent, currentContent);
        }
      }
    }

    return result;
  }

  /// Prints a simple line-by-line diff between [original] and [modified].
  ///
  /// **Limitation**: This naive diff algorithm does not handle line additions
  /// or removals well, as it compares lines at the same index. It is
  /// sufficient for current fixers that only modify existing lines, but
  /// should be replaced with a more robust diffing solution (e.g.,
  /// `package:diff`) if future fixers add or remove lines.
  void _printDiff(String original, String modified) {
    final List<String> origLines = original.split('\n');
    final List<String> modLines = modified.split('\n');
    final int maxLines = origLines.length > modLines.length ? origLines.length : modLines.length;
    for (var i = 0; i < maxLines; i++) {
      final String orig = i < origLines.length ? origLines[i] : '';
      final String mod = i < modLines.length ? modLines[i] : '';
      if (orig != mod) {
        if (orig.isNotEmpty) {
          _log.info('- Line ${i + 1}: $orig');
        }
        if (mod.isNotEmpty) {
          _log.info('+ Line ${i + 1}: $mod');
        }
      }
    }
  }

  /// Mutates [ignores] in place to add baseline entries for any non-ignored
  /// errors in [result] under the [skillName] key. Pure in-memory operation
  /// — pair with [_saveBaseline] to persist changes.
  void _updateBaselineForSkill(SkillsIgnores ignores, ValidationResult result, String skillName) {
    final List<IgnoreEntry> currentSkillIgnores = ignores.skills[skillName] ?? [];
    final currentSkillSeen = <String>{};
    for (final ignore in currentSkillIgnores) {
      currentSkillSeen.add('${ignore.ruleId}:${ignore.fileName}');
    }

    for (final ValidationError error in result.validationErrors) {
      if (!error.isIgnored) {
        final key = '${error.ruleId}:${error.file}';
        if (currentSkillSeen.contains(key)) {
          continue;
        }
        currentSkillSeen.add(key);

        currentSkillIgnores.add(IgnoreEntry(ruleId: error.ruleId, fileName: error.file));
      }
    }

    if (currentSkillIgnores.isNotEmpty) {
      ignores.skills[skillName] = currentSkillIgnores;
    } else {
      ignores.skills.remove(skillName);
    }
  }

  /// Writes [ignores] to [ignorePath]. Write failures are logged at warning
  /// level and otherwise swallowed so a single I/O error does not abort the
  /// rest of the run.
  Future<void> _saveBaseline(String ignorePath, SkillsIgnores ignores) async {
    try {
      await SkillsIgnoresStorage().save(ignorePath, ignores);
    } catch (e) {
      _log.warning('Failed to generate baseline file at $ignorePath: $e');
    }
  }

  void _printValidationResult(ValidationResult result) {
    if (result.isValid) {
      if (!quiet) {
        _log.info('  $skillIsValidMsg');
      }
    } else {
      _log.severe('  $skillIsInvalidMsg');
      for (final String error in result.errors) {
        _log.severe('    - $error');
      }
    }

    if (printWarnings && result.warnings.isNotEmpty) {
      _log.warning('  $warningsMsg');
      for (final String warning in result.warnings) {
        _log.warning('    - $warning');
      }
    }
  }
}
