// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:diff_match_patch/diff_match_patch.dart' as dmp;
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
/// caller invokes [processIndividualSkill] for each `--skill` path and
/// [processSkillRoot] for each `--skills-directory` path, then optionally
/// [reportNoSkillsValidated] to emit the "no skills found" diagnostics.
/// Failure state is exposed via [anyFailed] and [anySkillsValidated].
class ValidationSession {
  ValidationSession({
    required this.config,
    required this.resolvedRules,
    required this.ignoreFileOverride,
    required this.customRules,
    required this.printWarnings,
    required this.fastFail,
    required this.quiet,
    required this.generateBaseline,
    required this.fix,
    required this.fixApply,
  }) : _normalizedDirectoryConfigs = [
         for (final dc in config.directoryConfigs)
           (normalizedPath: p.normalize(dc.path), config: dc),
       ];

  final Configuration config;
  final Map<String, AnalysisSeverity> resolvedRules;
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
  final List<({String normalizedPath, DirectoryConfig config})> _normalizedDirectoryConfigs;

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
    final String normalizedSkillPath = p.normalize(_expandPath(skillPath));
    if (!quiet) {
      _log.info('$evaluatingDirMsg $normalizedSkillPath');
    }
    final skillDir = Directory(normalizedSkillPath);

    if (!skillDir.existsSync()) {
      _log.severe('Specified skill directory does not exist: $normalizedSkillPath');
      _anyFailed = true;
      return true;
    }

    final Map<String, AnalysisSeverity> localRules = _resolveRulesForPath(normalizedSkillPath);
    final String? localIgnoreFile = _resolveIgnoreFile(normalizedSkillPath);
    final validator = Validator(ruleOverrides: localRules, customRules: customRules);

    final ({SkillsIgnores ignores, String ignorePath}) loaded = await _loadIgnores(
      localIgnoreFile,
      skillDir.parent,
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
    final String normalizedRootPath = p.normalize(_expandPath(rootPath));
    if (!quiet) {
      _log.info('$evaluatingDirMsg $normalizedRootPath');
    }
    final rootDir = Directory(normalizedRootPath);

    if (!rootDir.existsSync()) {
      _log.severe('Specified root directory does not exist: $normalizedRootPath');
      _anyFailed = true;
      return true;
    }

    final Map<String, AnalysisSeverity> localRules = _resolveRulesForPath(normalizedRootPath);
    final String? localIgnoreFile = _resolveIgnoreFile(normalizedRootPath);
    final validator = Validator(ruleOverrides: localRules, customRules: customRules);

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

    final ({SkillsIgnores ignores, String ignorePath}) loaded = await _loadIgnores(
      localIgnoreFile,
      rootDir,
    );
    final SkillsIgnores ignores = loaded.ignores;

    for (final entity in entities) {
      if (entity is! Directory) {
        continue;
      }
      if (p.basename(entity.path).startsWith('.')) {
        continue;
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

    if (generateBaseline) {
      await _saveBaseline(loaded.ignorePath, ignores);
    } else {
      for (final MapEntry<String, List<IgnoreEntry>> entry in ignores.skills.entries) {
        final String skillName = entry.key;
        for (final IgnoreEntry ignore in entry.value) {
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
      final String expandedRootPath = _expandPath(rootPath);
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

  Map<String, AnalysisSeverity> _resolveRulesForPath(String normalizedPath) {
    final localRules = Map<String, AnalysisSeverity>.from(resolvedRules);
    for (final ({String normalizedPath, DirectoryConfig config}) entry
        in _normalizedDirectoryConfigs) {
      if (normalizedPath.startsWith(entry.normalizedPath)) {
        localRules.addAll(entry.config.rules);
        break;
      }
    }
    return localRules;
  }

  String? _resolveIgnoreFile(String normalizedPath) {
    if (ignoreFileOverride != null) {
      return ignoreFileOverride;
    }
    for (final ({String normalizedPath, DirectoryConfig config}) entry
        in _normalizedDirectoryConfigs) {
      if (normalizedPath.startsWith(entry.normalizedPath)) {
        return entry.config.ignoreFile;
      }
    }
    return null;
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
        ? p.normalize(_expandPath(localIgnoreFile))
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

  /// Prints a line-level diff between [original] and [modified] to the logger.
  void _printDiff(String original, String modified) {
    computeLineDiff(original, modified).forEach(_log.info);
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

  String _expandPath(String path) {
    if (path.startsWith('~/')) {
      final String? homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (homeDir != null) {
        return p.join(homeDir, path.substring(2));
      }
    }
    return path;
  }
}

/// Computes a line-level diff between [original] and [modified] suitable for
/// dry-run preview output.
///
/// Returns a list of formatted strings, one per changed line:
/// `'- Line N: <text>'` for removed lines (numbered against [original]) and
/// `'+ Line N: <text>'` for added lines (numbered against [modified]).
/// Unchanged lines are not emitted.
///
/// Handles insertions, deletions, and modifications correctly. Each line of
/// each input is treated atomically (no intra-line diffs).
@visibleForTesting
List<String> computeLineDiff(String original, String modified) {
  final lineArray = <String>[];
  final lineToIndex = <String, int>{};

  String tokenize(String text) {
    final buf = StringBuffer();
    for (final String line in text.split('\n')) {
      final int idx = lineToIndex.putIfAbsent(line, () {
        lineArray.add(line);
        return lineArray.length - 1;
      });
      // Offset by 1 so the first line never collides with char code 0 (NUL).
      buf.writeCharCode(idx + 1);
    }
    return buf.toString();
  }

  final String tokenizedOriginal = tokenize(original);
  final String tokenizedModified = tokenize(modified);

  final List<dmp.Diff> diffs = dmp.diff(tokenizedOriginal, tokenizedModified, checklines: false);

  final output = <String>[];
  var originalLineNumber = 1;
  var modifiedLineNumber = 1;

  for (final d in diffs) {
    final List<int> codes = d.text.codeUnits;
    switch (d.operation) {
      case dmp.DIFF_EQUAL:
        originalLineNumber += codes.length;
        modifiedLineNumber += codes.length;
      case dmp.DIFF_DELETE:
        for (final c in codes) {
          output.add('- Line $originalLineNumber: ${lineArray[c - 1]}');
          originalLineNumber++;
        }
      case dmp.DIFF_INSERT:
        for (final c in codes) {
          output.add('+ Line $modifiedLineNumber: ${lineArray[c - 1]}');
          modifiedLineNumber++;
        }
    }
  }
  return output;
}
