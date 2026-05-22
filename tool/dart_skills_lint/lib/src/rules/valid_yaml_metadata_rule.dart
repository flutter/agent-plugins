import 'package:yaml/yaml.dart';
import '../cutoff_excerpt.dart';
import '../models/analysis_severity.dart';
import '../models/skill_context.dart';
import '../models/skill_rule.dart';
import '../models/validation_error.dart';

/// Enforces that SKILL.md has valid YAML frontmatter and required fields.
class ValidYamlMetadataRule extends SkillRule {
  ValidYamlMetadataRule({this.severity = defaultSeverity});

  static const String ruleName = 'valid-yaml-metadata';
  static const AnalysisSeverity defaultSeverity = AnalysisSeverity.error;

  @override
  String get name => ruleName;

  @override
  final AnalysisSeverity severity;

  static const _requiredFields = {'name', 'description'};
  static const _skillFileName = 'SKILL.md';
  static const _metadataUrl = 'https://agentskills.io/specification#frontmatter';
  static const maxCompatibilityLength = 500;
  static const _compatibilityFieldUrl = 'https://agentskills.io/specification#compatibility-field';

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
              'Invalid YAML metadata: ${context.yamlParsingError ?? 'Missing or invalid'} (see $_metadataUrl)',
        ),
      );
      return errors;
    }

    final YamlMap yaml = context.parsedYaml!;
    for (final String field in _requiredFields) {
      if (!yaml.containsKey(field)) {
        errors.add(
          ValidationError(
            ruleId: name,
            severity: severity,
            file: _skillFileName,
            message: 'Missing required field: $field (see $_metadataUrl)',
          ),
        );
      }
    }

    if (yaml.containsKey('compatibility')) {
      final String compatibility = yaml['compatibility']?.toString() ?? '';
      if (compatibility.length > maxCompatibilityLength) {
        errors.add(
          ValidationError(
            ruleId: name,
            severity: severity,
            file: _skillFileName,
            message: buildLengthDiagnostic(
              fieldName: 'Compatibility',
              value: compatibility,
              maxLength: maxCompatibilityLength,
              docUrl: _compatibilityFieldUrl,
            ),
          ),
        );
      }
    }

    return errors;
  }
}
