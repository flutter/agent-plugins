// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:path/path.dart';
import '../fixable_rule.dart';
import '../models/analysis_severity.dart';
import '../models/skill_context.dart';
import '../models/skill_rule.dart';
import '../models/validation_error.dart';

/// Enforces that links in SKILL.md do not use absolute paths.
class AbsolutePathsRule extends SkillRule implements FixableRule {
  AbsolutePathsRule({this.severity = defaultSeverity});

  static const String ruleName = 'check-absolute-paths';
  static const AnalysisSeverity defaultSeverity = AnalysisSeverity.warning;

  @override
  String get name => ruleName;

  @override
  final AnalysisSeverity severity;

  static const String _skillFileName = SkillContext.skillFileName;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];

    // Extract content after YAML frontmatter
    final RegExpMatch? match = SkillContext.skillStartRegex.firstMatch(context.rawContent);
    final String markdownContent = match != null
        ? context.rawContent.substring(match.end)
        : context.rawContent;

    for (final RegExpMatch linkMatch in SkillContext.markdownLinkRegex.allMatches(
      markdownContent,
    )) {
      final String path = linkMatch.group(1)!;
      if (isAbsolute(path) || windows.isAbsolute(path)) {
        errors.add(
          ValidationError(
            ruleId: name,
            severity: severity,
            file: _skillFileName,
            message:
                'Absolute filepath found in link: $path. '
                'Skills must use paths relative to SKILL.md so they remain '
                'portable across machines.',
          ),
        );
      }
    }

    return errors;
  }

  @override
  Future<String> fix(String filePath, String currentContent, Directory directory) async {
    if (filePath != SkillContext.skillFileName) {
      return currentContent;
    }

    return currentContent.replaceAllMapped(SkillContext.markdownLinkRegex, (match) {
      final String path = match.group(1)!;
      if (isAbsolute(path) || windows.isAbsolute(path)) {
        final file = File(path);
        if (file.existsSync()) {
          final String relativePath = relative(path, from: directory.path);
          final String posixRelativePath = relativePath.replaceAll(r'\', '/');
          final String fullMatch = match.group(0)!;
          final int lastParen = fullMatch.lastIndexOf('(');
          return '${fullMatch.substring(0, lastParen + 1)}$posixRelativePath)';
        }
      }
      return match.group(0)!;
    });
  }
}
