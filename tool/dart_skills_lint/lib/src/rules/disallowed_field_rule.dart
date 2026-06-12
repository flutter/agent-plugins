// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:yaml/yaml.dart';
import '../models/analysis_severity.dart';
import '../models/skill_context.dart';
import '../models/skill_rule.dart';
import '../models/validation_error.dart';

/// Enforces that only allowed fields are present in YAML metadata.
class DisallowedFieldRule extends SkillRule {
  DisallowedFieldRule({this.severity = defaultSeverity});

  static const String ruleName = 'disallowed-field';
  static const AnalysisSeverity defaultSeverity = AnalysisSeverity.disabled;

  @override
  String get name => ruleName;

  @override
  final AnalysisSeverity severity;

  static const _allowedFields = {
    'name',
    'description',
    'license',
    'allowed-tools',
    'metadata',
    'compatibility',
    'category',
    'tags',
    'version',
    'eval_task',
  };

  static const _skillFileName = 'SKILL.md';
  static const _metadataUrl = 'https://agentskills.io/specification#frontmatter';

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];

    if (context.parsedYaml == null) {
      return errors;
    }

    final YamlMap yaml = context.parsedYaml!;
    for (final Object? key in yaml.keys) {
      final bool isDisallowed = key is! String || !_allowedFields.contains(key);
      if (isDisallowed) {
        errors.add(
          ValidationError(
            ruleId: name,
            severity: severity,
            file: _skillFileName,
            message: 'Disallowed field: $key (see $_metadataUrl)',
          ),
        );
      }
    }

    return errors;
  }
}
