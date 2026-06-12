// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';
import '../fixable_rule.dart';
import '../models/analysis_severity.dart';
import '../models/skill_context.dart';
import '../models/skill_rule.dart';
import '../models/validation_error.dart';

/// Enforces constraints on the skill name field.
class NameFormatRule extends SkillRule implements FixableRule {
  NameFormatRule({this.severity = defaultSeverity});

  static const String ruleName = 'invalid-skill-name';
  static const AnalysisSeverity defaultSeverity = AnalysisSeverity.error;

  @override
  String get name => ruleName;

  @override
  final AnalysisSeverity severity;

  static const maxNameLength = 64;
  static final _validNameRegex = RegExp(r'^[a-z0-9\-]+$');
  static const String _skillFileName = SkillContext.skillFileName;
  static const _nameFieldUrl = 'https://agentskills.io/specification#name-field';

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];

    if (context.parsedYaml == null) {
      return errors;
    }

    final YamlMap yaml = context.parsedYaml!;
    final String skillName = getNameNode(yaml)?.value.toString() ?? '';

    if (skillName.isEmpty) {
      return errors; // Handled by required fields check
    }

    final String suggestion = suggestNormalizedName(skillName);

    if (skillName != skillName.toLowerCase()) {
      errors.add(
        _buildNameFormatError(
          'Frontmatter `name` "$skillName" must be lowercase. '
          'Suggested: "$suggestion"',
        ),
      );
    }

    if (skillName.length > maxNameLength) {
      errors.add(
        _buildNameFormatError(
          'Frontmatter `name` is ${skillName.length} characters; '
          'maximum is $maxNameLength. '
          'Shorten the `name:` field in SKILL.md.',
        ),
      );
    }

    if (!_validNameRegex.hasMatch(skillName)) {
      errors.add(
        _buildNameFormatError(
          'Frontmatter `name` "$skillName" contains invalid characters. '
          'Only lowercase letters, digits, and hyphens are allowed. '
          'Suggested: "$suggestion"',
        ),
      );
    }

    if (skillName.startsWith('-') || skillName.endsWith('-')) {
      errors.add(
        _buildNameFormatError(
          'Frontmatter `name` "$skillName" has leading or trailing hyphens. '
          'Suggested: "$suggestion"',
        ),
      );
    }

    if (skillName.contains('--')) {
      errors.add(
        _buildNameFormatError(
          'Frontmatter `name` "$skillName" has consecutive hyphens. '
          'Suggested: "$suggestion"',
        ),
      );
    }

    final String dirName = basename(context.directory.path);
    if (skillName != dirName) {
      errors.add(
        _buildNameFormatError(
          'Frontmatter `name` "$skillName" does not match the parent '
          'directory name "$dirName". '
          'Fix by either setting `name: $dirName` in SKILL.md '
          'or renaming the directory from "$dirName" to "$skillName".',
        ),
      );
    }

    return errors;
  }

  ValidationError _buildNameFormatError(String message) => ValidationError(
    ruleId: name,
    severity: severity,
    file: _skillFileName,
    message: '$message (see $_nameFieldUrl)',
  );

  /// Returns a best-effort normalization of [input] that conforms to the
  /// skill name format: lowercase, hyphens only, no consecutive/leading/
  /// trailing hyphens, truncated to [maxNameLength].
  ///
  /// This is intentionally a *suggestion* — the author still picks the final
  /// name. The output is not guaranteed to match a directory name.
  @visibleForTesting
  static String suggestNormalizedName(String input) {
    String s = input.toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9\-]+'), '-');
    s = s.replaceAll(RegExp(r'-+'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.length > maxNameLength) {
      s = s.substring(0, maxNameLength);
      s = s.replaceAll(RegExp(r'-+$'), '');
    }
    return s;
  }

  @override
  Future<String> fix(String filePath, String currentContent, Directory directory) async {
    if (filePath != SkillContext.skillFileName) {
      return currentContent;
    }

    final RegExpMatch? match = SkillContext.skillStartRegex.firstMatch(currentContent);
    if (match == null) {
      return currentContent;
    }
    final String yamlStr = match.group(1)!;

    final Object? yamlObj;
    try {
      yamlObj = loadYaml(yamlStr);
    } catch (e) {
      return currentContent;
    }

    if (yamlObj is! YamlMap) {
      return currentContent;
    }

    final YamlMap yaml = yamlObj;
    final YamlNode? nameNode = getNameNode(yaml);
    if (nameNode == null) {
      return currentContent;
    }

    final String dirName = basename(directory.path);

    final currentName = nameNode.value.toString();
    if (currentName == dirName) {
      return currentContent;
    }

    final int yamlOffset = currentContent.indexOf(yamlStr, match.start);

    // ignore: specify_nonobvious_local_variable_types
    final span = nameNode.span;
    final String before = currentContent.substring(0, yamlOffset + span.start.offset);
    final String after = currentContent.substring(yamlOffset + span.end.offset);

    return '$before$dirName$after';
  }

  /// Returns the YAML node for the skill name.
  @visibleForTesting
  static YamlNode? getNameNode(YamlMap yaml) {
    return yaml.nodes['name'];
  }
}
