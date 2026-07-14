// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'config_parser.dart';
import 'missing_defaults_exception.dart';
import 'models/analysis_severity.dart';
import 'models/check_type.dart';
import 'models/custom_rule_options.dart';
import 'models/skill_rule.dart';
import 'rule_registry.dart';
import 'validation_session.dart';

export 'validation_session.dart';

final _log = Logger('dart_skills_lint');

const _printWarningsFlag = 'print-warnings';
const _fastFailFlag = 'fast-fail';
const _quietFlag = 'quiet';
const _skillsDirectoryFlag = 'skills-directory';
const _skillOption = 'skill';
const _ignoreFileOption = 'ignore-file';
const _ignoreConfigFlag = 'ignore-config';
const _generateBaselineFlag = 'generate-baseline';
const _fixFlag = 'fix';
const _dryRunFlag = 'dry-run';
const _fixApplyFlag = 'fix-apply';
const _allowMisconfiguredKeysFlag = 'allow-misconfigured-keys';
const _configOption = 'config';

/// User-visible deprecation notice for the legacy `--fix-apply` alias.
///
/// Exposed (not `_`-prefixed) so integration tests can assert it appears on
/// stderr when the alias is used.
const fixApplyDeprecationMsg =
    '--fix-apply is deprecated; use --fix instead. '
    'Pass --fix --dry-run to preview changes without writing.';

/// Welcoming first-run guide shown when no args are passed and no default
/// skills directory exists. Exposed so integration tests can assert the
/// exact greeting (drift here changes the new-user experience).
const firstRunGuideMsg = '''
dart_skills_lint: a linter for Agent Skills (SKILL.md).

No skills were found to validate. Get started in one of three ways:

  1. Lint a single skill directory:
       dart run dart_skills_lint --skill ./path/to/my-skill

  2. Lint every skill under a root directory:
       dart run dart_skills_lint --skills-directory ./path/to/skills-root

  3. Drop a skill into one of the auto-discovered default paths
     (relative to the current directory) and re-run with no flags:
       .claude/skills/<my-skill>/SKILL.md
       .agents/skills/<my-skill>/SKILL.md

For repo-wide config, create dart_skills_lint.yaml with a
`dart_skills_lint.directories` entry.

Spec: https://agentskills.io/specification
Run with --help to see every flag.''';

/// Main entrypoint execution logic for the CLI tool.
///
/// Parses arguments and runs validation on the specified directory.
Future<void> runApp(List<String> args) async {
  // Setup logger to print to stdout/stderr
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (record.level >= Level.SEVERE) {
      stderr.writeln(record.message);
    } else {
      stdout.writeln(record.message);
    }
  });

  const helpFlag = 'help';

  final ArgParser parser = _createArgParser(helpFlag);

  final ArgResults results;
  final Map<String, AnalysisSeverity> resolvedRuleSeverities;
  final Map<String, CustomRuleOptions> resolvedRuleOptions;

  try {
    results = parser.parse(args);
    if (results[helpFlag] as bool) {
      _printUsage(parser);
      return;
    }
    resolvedRuleSeverities = resolveRuleSeverities(results);
    resolvedRuleOptions = resolveRuleOptionsOverrides(results);
  } catch (e) {
    _printUsage(parser, e.toString());
    exitCode = 64; // Bad usage
    return;
  }

  final Configuration? config = await _loadConfig(results);
  if (config == null) {
    exitCode = 1;
    return;
  }

  final skillDirPaths = results[_skillsDirectoryFlag] as List<String>;
  final individualSkillPaths = results[_skillOption] as List<String>;

  final printWarnings = results[_printWarningsFlag] as bool;
  final fastFail = results[_fastFailFlag] as bool;
  final quiet = results[_quietFlag] as bool;
  final generateBaseline = results[_generateBaselineFlag] as bool;
  final fixFlag = results[_fixFlag] as bool;
  final dryRun = results[_dryRunFlag] as bool;
  final fixApplyAlias = results[_fixApplyFlag] as bool;

  if (fixApplyAlias) {
    stderr.writeln(fixApplyDeprecationMsg);
  }

  // --fix writes fixes to disk; pair with --dry-run to preview without
  // writing. --fix-apply is a deprecated alias for --fix that still
  // writes (with a deprecation notice on stderr above).
  final bool fix = fixFlag && dryRun;
  final bool fixApply = (fixFlag && !dryRun) || fixApplyAlias;

  String? ignoreFileOverride;
  if (results.wasParsed(_ignoreFileOption)) {
    ignoreFileOverride = results[_ignoreFileOption] as String?;
  } else {
    ignoreFileOverride = null;
  }

  var success = false;
  try {
    success = await validateSkillsInternal(
      skillDirPaths: skillDirPaths,
      individualSkillPaths: individualSkillPaths,
      resolvedRuleSeverities: resolvedRuleSeverities,
      resolvedRuleOptions: resolvedRuleOptions,
      printWarnings: printWarnings,
      fastFail: fastFail,
      quiet: quiet,
      generateBaseline: generateBaseline,
      fix: fix,
      fixApply: fixApply,
      ignoreFileOverride: ignoreFileOverride,
      config: config,
    );
    if (success) {
      exitCode = 0;
    } else {
      exitCode = 1;
    }
  } on MissingDefaultsException catch (_) {
    stdout.writeln(firstRunGuideMsg);
    exitCode = 64;
  }
}

/// Creates the [ArgParser] for the CLI, adding all supported flags and options.
///
/// Dynamically adds flags for all registered rules in [RuleRegistry].
ArgParser _createArgParser(String helpFlag) {
  final parser = ArgParser()
    ..addFlag(helpFlag, abbr: 'h', negatable: false, help: 'Show usage information.')
    ..addFlag(_printWarningsFlag, abbr: 'w', defaultsTo: true, help: 'Print validation warnings.');

  // Dynamically add flags for all registered rules.
  for (final CheckType check in RuleRegistry.allChecks) {
    parser.addFlag(
      check.name,
      defaultsTo: check.defaultSeverity != AnalysisSeverity.disabled,
      help: check.help,
    );

    // Register namespaced delegated options
    for (final String optionName in check.optionsSchema.keys) {
      final Type expectedType = check.optionsSchema[optionName]!;
      if (expectedType == List || expectedType == List<String>) {
        parser.addMultiOption(
          '${check.name}-$optionName',
          help: "Override option '$optionName' list for rule '${check.name}'.",
        );
      } else {
        parser.addOption(
          '${check.name}-$optionName',
          help: "Override option '$optionName' for rule '${check.name}'.",
        );
      }
    }
  }

  parser
    ..addFlag(
      _fastFailFlag,
      negatable: false,
      help: 'Fail immediately on the first skill validation error.',
    )
    ..addFlag(
      _quietFlag,
      abbr: 'q',
      negatable: false,
      help: 'Quiet mode (only print errors and warnings).',
    )
    ..addMultiOption(
      _skillsDirectoryFlag,
      abbr: 'd',
      help: 'Path to a skills directory to validate. Can be specified multiple times.',
    )
    ..addMultiOption(
      _skillOption,
      abbr: 's',
      help: 'Path to an individual skill directory to validate. Can be specified multiple times.',
    )
    ..addOption(_ignoreFileOption, help: 'Path to a JSON file listing lints to ignore for the run.')
    ..addFlag(
      _generateBaselineFlag,
      negatable: false,
      help: 'Write all current errors into $defaultIgnoreFileName to ignore on future runs.',
    )
    ..addFlag(
      _ignoreConfigFlag,
      negatable: false,
      help: 'Ignore the YAML configuration file entirely.',
    )
    ..addFlag(
      _fixFlag,
      negatable: false,
      help: 'Write fixes for failing lints to disk. Combine with --dry-run to preview.',
    )
    ..addFlag(
      _dryRunFlag,
      negatable: false,
      help: 'When passed with --fix, preview proposed changes without writing.',
    )
    // help: omitted — flag is hide: true so --help skips it anyway.
    // Adopters who hit it still get the runtime deprecation notice
    // on stderr (see fixApplyDeprecationMsg above).
    ..addFlag(_fixApplyFlag, negatable: false, hide: true)
    ..addFlag(
      _allowMisconfiguredKeysFlag,
      negatable: false,
      hide: true,
      help: 'Allow misconfigured keys in dart_skills_lint.yaml.',
    )
    ..addOption(
      _configOption,
      abbr: 'c',
      help: 'Path to a custom configuration file (defaults to dart_skills_lint.yaml).',
    );

  return parser;
}

Future<Configuration?> _loadConfig(ArgResults results) async {
  final ignoreConfig = results[_ignoreConfigFlag] as bool;
  final Configuration config;
  if (ignoreConfig) {
    config = Configuration();
  } else {
    try {
      final configPath = results[_configOption] as String?;
      config = await ConfigParser.loadConfig(path: configPath);
    } on FileSystemException catch (e) {
      _log.severe('Error: ${e.message} (${e.path})');
      return null;
    } catch (e) {
      _log.severe('Error loading configuration: $e');
      return null;
    }
  }
  if (ignoreConfig && !(results[_quietFlag] as bool)) {
    _log.info('Ignoring configuration file due to $_ignoreConfigFlag flag');
  }

  if (config.parsingErrors.isNotEmpty) {
    final allowMisconfiguredKeys = results[_allowMisconfiguredKeysFlag] as bool;
    if (allowMisconfiguredKeys) {
      for (final String error in config.parsingErrors) {
        _log.warning('Configuration warning: $error');
      }
    } else {
      for (final String error in config.parsingErrors) {
        _log.severe('Configuration error: $error');
      }
      _log.severe('Use --$_allowMisconfiguredKeysFlag to ignore these errors.');
      return null;
    }
  }
  return config;
}

/// Validates skills based on the provided configuration.
///
/// This is the public API for validating skills. It does not support fixing
/// lints as that feature is considered internal to the CLI.
///
/// [skillDirPaths] is a list of directories containing multiple skills.
/// [individualSkillPaths] is a list of paths to individual skill directories.
/// [resolvedRules] is a map of rule names to their severity overrides.
/// [printWarnings] controls whether to print validation warnings.
/// [fastFail] causes validation to stop on the first error.
/// [quiet] suppresses non-error/warning output.
/// [generateBaseline] writes current errors to a baseline file instead of reporting them.
/// [ignoreFileOverride] is an optional path to a baseline file to use.
/// [config] is the loaded configuration.
///
/// Returns a [Future] that resolves to `true` if all skills validated successfully
/// (or if [generateBaseline] is true), and `false` if any validation failures
/// were encountered.
Future<bool> validateSkills({
  List<String> skillDirPaths = const [],
  List<String> individualSkillPaths = const [],
  Map<String, AnalysisSeverity> resolvedRuleSeverities = const {},
  Map<String, CustomRuleOptions> resolvedRuleOptions = const {},
  bool printWarnings = true,
  bool fastFail = false,
  bool quiet = false,
  bool generateBaseline = false,
  String? ignoreFileOverride,
  Configuration? config,
  List<SkillRule> customRules = const [],
}) {
  return validateSkillsInternal(
    skillDirPaths: skillDirPaths,
    individualSkillPaths: individualSkillPaths,
    resolvedRuleSeverities: resolvedRuleSeverities,
    resolvedRuleOptions: resolvedRuleOptions,
    printWarnings: printWarnings,
    fastFail: fastFail,
    quiet: quiet,
    generateBaseline: generateBaseline,
    ignoreFileOverride: ignoreFileOverride,
    config: config,
    customRules: customRules,
  );
}

/// Internal implementation of skill validation that supports fixing.
///
/// Kept internal to avoid exposing experimental fix parameters in the public API.
///
/// Returns `true` if all validations passed (or if generating a baseline), `false` otherwise.
@visibleForTesting
Future<bool> validateSkillsInternal({
  List<String> skillDirPaths = const [],
  List<String> individualSkillPaths = const [],
  Map<String, AnalysisSeverity> resolvedRuleSeverities = const {},
  Map<String, CustomRuleOptions> resolvedRuleOptions = const {},
  bool printWarnings = true,
  bool fastFail = false,
  bool quiet = false,
  bool generateBaseline = false,
  bool fix = false,
  bool fixApply = false,
  String? ignoreFileOverride,
  Configuration? config,
  List<SkillRule> customRules = const [],
}) async {
  final bool hasCliTargets = skillDirPaths.isNotEmpty || individualSkillPaths.isNotEmpty;
  final List<String> effectiveIndividualSkillPaths = [
    ...individualSkillPaths,
    if (config != null && !hasCliTargets) ...config.individualSkillConfigs.map((e) => e.path),
  ];

  final List<String> effectiveSkillDirPaths = _getEffectiveSkillDirPaths(
    skillDirPaths: skillDirPaths,
    individualSkillPaths: individualSkillPaths,
    config: config,
  );

  final session = ValidationSession(
    config: config ?? Configuration(),
    resolvedRuleSeverities: resolvedRuleSeverities,
    resolvedRuleOptions: resolvedRuleOptions,
    ignoreFileOverride: ignoreFileOverride,
    customRules: customRules,
    printWarnings: printWarnings,
    fastFail: fastFail,
    quiet: quiet,
    generateBaseline: generateBaseline,
    fix: fix,
    fixApply: fixApply,
  );

  for (final skillPath in effectiveIndividualSkillPaths) {
    final bool keepGoing = await session.processIndividualSkill(skillPath);
    if (!keepGoing) {
      break;
    }
  }
  if (session.anyFailed && fastFail) {
    return false;
  }

  for (final rootPath in effectiveSkillDirPaths) {
    final bool keepGoing = await session.processSkillRoot(rootPath);
    if (!keepGoing) {
      break;
    }
  }

  session.reportNoSkillsValidated(effectiveSkillDirPaths);

  if (generateBaseline) {
    return true;
  }
  return !session.anyFailed;
}

/// Computes the list of skill directory paths to validate.
///
/// If paths are not explicitly provided, falls back to configured directory
/// paths, and then to default locations (`.claude/skills`, `.agents/skills`).
/// Throws [MissingDefaultsException] if no directories are found.
List<String> _getEffectiveSkillDirPaths({
  required List<String> skillDirPaths,
  required List<String> individualSkillPaths,
  Configuration? config,
}) {
  final effectiveSkillDirPaths = List<String>.from(skillDirPaths);

  if (effectiveSkillDirPaths.isEmpty && individualSkillPaths.isEmpty) {
    // If the config specifies any targets (even if it's only individual_skills
    // and directories is empty), we avoid the default directory fallback.
    if (config != null &&
        (config.directoryConfigs.isNotEmpty || config.individualSkillConfigs.isNotEmpty)) {
      return config.directoryConfigs.map((e) => e.path).toList();
    } else {
      final defaults = ['.claude/skills', '.agents/skills'];
      final existingDefaults = <String>[];
      for (final path in defaults) {
        if (Directory(path).existsSync()) {
          existingDefaults.add(path);
        }
      }
      if (existingDefaults.isEmpty) {
        throw MissingDefaultsException(defaults);
      }
      return existingDefaults;
    }
  }

  return effectiveSkillDirPaths;
}

@visibleForTesting
Map<String, AnalysisSeverity> resolveRuleSeverities(ArgResults results) {
  final resolved = <String, AnalysisSeverity>{};

  // Only load rule severities explicitly set via CLI flags.
  for (final CheckType check in RuleRegistry.allChecks) {
    final String name = check.name;

    if (!results.wasParsed(name)) {
      continue;
    }

    final Object? value = results[name];
    if (value is! bool) {
      continue;
    }

    if (value) {
      resolved[name] = AnalysisSeverity.error;
    } else {
      resolved[name] = AnalysisSeverity.disabled;
    }
  }

  return resolved;
}

/// Resolves rule-specific options overrides from CLI arguments.
///
/// Iterates over all checks in [RuleRegistry.allChecks], looks for parsed command-line
/// flags matches in the format `--[rule-name]-[option-name]` (e.g. `--path-does-not-exist-exclude`),
/// and returns a structured map mapping rule names to their custom key-value parameter overrides.
///
/// Applies type coercion based on the expected type defined in [CheckType.optionsSchema]:
/// * [int]: Coerced using [int.tryParse].
/// * [bool]: Coerced to `true` if matching "true" case-insensitively, `false` otherwise.
/// * Other: Parsed as-is (e.g. [String] or [List] types).
/// * Empty String: If the CLI flag is passed as an empty string `""`, it is parsed
///   as a `null` map entry to explicitly clear/reset the option value.
Map<String, CustomRuleOptions> resolveRuleOptionsOverrides(ArgResults results) {
  final overrides = <String, CustomRuleOptions>{};

  for (final CheckType check in RuleRegistry.allChecks) {
    final Map<String, dynamic> checkOverrides = {};
    for (final String optionName in check.optionsSchema.keys) {
      final optionFlag = '${check.name}-$optionName';
      if (results.wasParsed(optionFlag)) {
        final Type expectedType = check.optionsSchema[optionName]!;
        final Object? rawValue = results[optionFlag];

        if (rawValue == '') {
          // Empty string override clears the option completely
          checkOverrides[optionName] = null;
        } else {
          // Coerce type
          if (expectedType == int) {
            final int? parsedInt = int.tryParse(rawValue.toString());
            if (parsedInt == null) {
              throw FormatException(
                'Invalid value "$rawValue" for option "$optionFlag". Expected an integer.',
              );
            }
            checkOverrides[optionName] = parsedInt;
          } else if (expectedType == bool) {
            final String lower = rawValue.toString().toLowerCase();
            if (lower != 'true' && lower != 'false') {
              throw FormatException(
                'Invalid value "$rawValue" for option "$optionFlag". Expected "true" or "false".',
              );
            }
            checkOverrides[optionName] = lower == 'true';
          } else {
            checkOverrides[optionName] = rawValue;
          }
        }
      }
    }
    if (checkOverrides.isNotEmpty) {
      overrides[check.name] = CustomRuleOptions(checkOverrides);
    }
  }

  return overrides;
}

void _printUsage(ArgParser parser, [String? error]) {
  if (error != null) {
    _log.severe('Error: $error');
  }
  _log.info('Usage: dart_skills_lint [options] --$_skillsDirectoryFlag <$_skillsDirectoryFlag>');
  _log.info(parser.usage);
}
