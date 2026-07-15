// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/analysis_severity.dart';
import '../models/skill_context.dart';
import '../models/skill_rule.dart';
import '../models/validation_error.dart';

/// Checks that a skill directory exists and contains a SKILL.md file.
///
/// If [excludeRegExp] is specified, it skips validation if the normalized
/// directory path matches the pattern.
/// Note on `exclude` regular expressions: To guarantee cross-platform portability across macOS, Linux, and Windows, path separators across evaluated absolute paths are **always normalized to forward slashes (`/`) prior to matching**. Always write `/` instead of `\` when separating directories within your regular expression exclusions.
class PathDoesNotExistRule extends SkillRule {
  PathDoesNotExistRule({required this.severity, this.excludeRegExp});

  static const String ruleName = 'path-does-not-exist';
  static const String excludeParameter = 'exclude';
  static const String _skillFileName = SkillContext.skillFileName;
  static const String _dirStructureUrl = 'https://agentskills.io/specification#directory-structure';

  @override
  final AnalysisSeverity severity;

  /// Optional regex pattern to exclude matching directories.
  /// Note: Target paths evaluated against this regex always normalize path
  /// separators to forward slashes (`/`), even on Windows.
  final RegExp? excludeRegExp;

  @override
  String get name => ruleName;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final List<ValidationError> errors = [];
    final Directory dir = context.directory;
    final String normalizedPath = dir.path.replaceAll(r'\', '/');

    if (excludeRegExp != null && excludeRegExp!.hasMatch(normalizedPath)) {
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
