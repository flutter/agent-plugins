import 'package:skills_lint/skills_lint.dart';

class LastModifiedRule extends SkillRule {
  static const _metadataKey = 'metadata';
  static const _lastModifiedKey = 'last_modified';

  @override
  final String name = 'generator:last-modified';

  @override
  final AnalysisSeverity severity = AnalysisSeverity.error;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];
    final yaml = context.parsedYaml;
    if (yaml == null) return errors;

    final Object? metadata = yaml[_metadataKey];
    if (metadata is! Map || !metadata.containsKey(_lastModifiedKey)) {
      errors.add(
        ValidationError(
          ruleId: name,
          severity: severity,
          file: 'SKILL.md',
          message: 'Missing field: $_metadataKey.$_lastModifiedKey',
        ),
      );
    }
    return errors;
  }
}
