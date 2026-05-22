import 'package:yaml/yaml.dart';
import '../models/analysis_severity.dart';
import '../models/skill_context.dart';
import '../models/skill_rule.dart';
import '../models/validation_error.dart';

/// Enforces that the description field is not too long.
class DescriptionLengthRule extends SkillRule {
  DescriptionLengthRule({this.severity = defaultSeverity});

  static const String ruleName = 'description-too-long';
  static const AnalysisSeverity defaultSeverity = AnalysisSeverity.error;

  @override
  String get name => ruleName;

  @override
  final AnalysisSeverity severity;

  static const maxDescriptionLength = 1024;
  static const _skillFileName = 'SKILL.md';
  static const _descriptionFieldUrl = 'https://agentskills.io/specification#description-field';

  /// Number of characters of context to show on each side of the cutoff
  /// in the excerpt.
  static const int _excerptContextChars = 40;

  @override
  Future<List<ValidationError>> validate(SkillContext context) async {
    final errors = <ValidationError>[];

    if (context.parsedYaml == null) {
      return errors;
    }

    final YamlMap yaml = context.parsedYaml!;
    final String description = yaml['description']?.toString() ?? '';

    if (description.length > maxDescriptionLength) {
      final String excerpt = _buildCutoffExcerpt(description);
      errors.add(
        ValidationError(
          ruleId: name,
          severity: severity,
          file: _skillFileName,
          message:
              'Description field is ${description.length} characters; '
              'maximum is $maxDescriptionLength. '
              'Cutoff at character $maxDescriptionLength: $excerpt '
              '(see $_descriptionFieldUrl)',
        ),
      );
    }

    return errors;
  }

  /// Builds an inline excerpt showing characters on either side of the
  /// max-length cutoff with a `|HERE|` marker. Deterministic and
  /// substring-based (no rewriting).
  static String _buildCutoffExcerpt(String description) {
    final int start = (maxDescriptionLength - _excerptContextChars).clamp(0, description.length);
    final int end = (maxDescriptionLength + _excerptContextChars).clamp(0, description.length);
    final String before = description.substring(start, maxDescriptionLength);
    final String after = description.substring(maxDescriptionLength, end);
    final leadingEllipsis = start > 0 ? '...' : '';
    final trailingEllipsis = end < description.length ? '...' : '';
    final String escapedBefore = _escapeForOneLine(before);
    final String escapedAfter = _escapeForOneLine(after);
    return '$leadingEllipsis$escapedBefore|HERE|$escapedAfter$trailingEllipsis';
  }

  static String _escapeForOneLine(String s) {
    return s.replaceAll('\n', r'\n').replaceAll('\r', r'\r');
  }
}
