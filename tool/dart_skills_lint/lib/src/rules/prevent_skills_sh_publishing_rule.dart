// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart';
import '../models/analysis_severity.dart';
import '../models/skill_context.dart';
import '../models/skill_rule.dart';
import '../models/validation_error.dart';

/// Enforces that skills are marked as internal to prevent accidental publishing to the public skills.sh registry.
/// This rule requires `metadata.internal` to be explicitly set to `true` in the SKILL.md YAML frontmatter.
class PreventSkillsShPublishingRule extends SkillRule {
  PreventSkillsShPublishingRule({this.severity = defaultSeverity});

  static const String ruleName = 'prevent-skills-sh-publishing';
  static const AnalysisSeverity defaultSeverity = AnalysisSeverity.disabled;

  @override
  String get name => ruleName;

  @override
  final AnalysisSeverity severity;

  static const _skillFileName = 'SKILL.md';

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];

    if (context.parsedYaml == null) {
      errors.add(
        ValidationError(
          ruleId: name,
          severity: severity,
          file: _skillFileName,
          message:
              'Missing YAML frontmatter. Expected:\n'
              'metadata:\n'
              '  internal: true',
        ),
      );
      return errors;
    }

    final YamlMap yaml = context.parsedYaml!;
    final Object? metadata = yaml['metadata'];

    if (metadata == null) {
      errors.add(
        ValidationError(
          ruleId: name,
          severity: severity,
          file: _skillFileName,
          message:
              'Missing "metadata" block in YAML frontmatter. Expected:\n'
              'metadata:\n'
              '  internal: true',
        ),
      );
      return errors;
    }

    if (metadata is! YamlMap) {
      errors.add(
        ValidationError(
          ruleId: name,
          severity: severity,
          file: _skillFileName,
          message:
              '"metadata" must be a YAML mapping (dictionary). Expected:\n'
              'metadata:\n'
              '  internal: true',
        ),
      );
      return errors;
    }

    final Object? internalVal = metadata['internal'];

    if (internalVal is String && internalVal.trim().toLowerCase() == 'true') {
      errors.add(
        ValidationError(
          ruleId: name,
          severity: severity,
          file: _skillFileName,
          message:
              'The "internal" field under "metadata" is set to a string "$internalVal". Please remove the quotes so it is parsed as a boolean.',
        ),
      );
      return errors;
    }

    if (internalVal != true) {
      errors.add(
        ValidationError(
          ruleId: name,
          severity: severity,
          file: _skillFileName,
          message:
              'The "internal" field under "metadata" must be explicitly set to boolean true to prevent accidental publishing. Expected:\n'
              'metadata:\n'
              '  internal: true',
        ),
      );
    }

    return errors;
  }
}
