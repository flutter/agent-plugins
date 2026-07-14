// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/analysis_severity.dart';
import '../models/configurable_skill_rule.dart';
import '../models/custom_rule_options.dart';
import '../models/skill_context.dart';
import '../models/validation_error.dart';

/// Checks that a skill directory exists and contains a SKILL.md file.
///
/// If [exclude] is specified, it compiles it as a [RegExp] and skips validation
/// if the directory name matches the pattern.
class PathDoesNotExistRule extends ConfigurableSkillRule {
  PathDoesNotExistRule({required this.severity, CustomRuleOptions? customRuleOptions})
    : super(customRuleOptions) {
    final String? excludeVal = customRuleOptions?.getString(excludeOption);
    if (excludeVal != null && excludeVal.isNotEmpty) {
      _excludeRegExp = RegExp(excludeVal);
    }
  }

  static const String ruleName = 'path-does-not-exist';
  static const String excludeOption = 'exclude';
  static const String _skillFileName = 'SKILL.md';
  static const String _dirStructureUrl = 'https://agentskills.io/specification#directory-structure';

  @override
  final AnalysisSeverity severity;

  RegExp? _excludeRegExp;

  @override
  String get name => ruleName;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final List<ValidationError> errors = [];
    final Directory dir = context.directory;
    final String dirName = p.basename(dir.path);

    if (_excludeRegExp != null && _excludeRegExp!.hasMatch(dirName)) {
      return errors;
    }

    if (!dir.existsSync()) {
      if (File(dir.path).existsSync()) {
        errors.add(
          ValidationError(
            ruleId: ruleName,
            file: dir.path,
            message: 'Path is not a directory: ${dir.path} (see $_dirStructureUrl)',
            severity: severity,
          ),
        );
      } else {
        errors.add(
          ValidationError(
            ruleId: ruleName,
            file: dir.path,
            message: 'Directory does not exist: ${dir.path} (see $_dirStructureUrl)',
            severity: severity,
          ),
        );
      }
      return errors;
    }

    final skillMdFile = File(p.join(dir.path, _skillFileName));
    if (!skillMdFile.existsSync()) {
      errors.add(
        ValidationError(
          ruleId: ruleName,
          file: dir.path,
          message: '$_skillFileName is missing in directory: ${dir.path} (see $_dirStructureUrl)',
          severity: severity,
        ),
      );
    }

    return errors;
  }
}
