import 'dart:io';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import '../levenshtein.dart';
import '../models/analysis_severity.dart';
import '../models/skill_context.dart';
import '../models/skill_rule.dart';
import '../models/validation_error.dart';

/// Enforces that relative links in SKILL.md point to existing files.
class RelativePathsRule extends SkillRule {
  RelativePathsRule({this.severity = defaultSeverity});

  static const String ruleName = 'check-relative-paths';
  static const AnalysisSeverity defaultSeverity = AnalysisSeverity.disabled;

  @override
  String get name => ruleName;

  @override
  final AnalysisSeverity severity;

  static const _skillFileName = 'SKILL.md';

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
      final String fullPath = linkMatch.group(1)!;
      // Markdown links can have a title after the URL, separated by spaces.
      // e.g. [text](url "title")
      final String path = fullPath.trim().split(RegExp(r'\s+')).first;

      // Skip absolute paths (handled by AbsolutePathsRule)
      if (isAbsolute(path) || windows.isAbsolute(path)) {
        continue;
      }

      var effectivePath = path;
      try {
        final Uri uri = Uri.parse(path);
        if (uri.hasScheme || path.startsWith('#')) {
          continue; // Ignore web URLs, email links, anchors, etc.
        }
        effectivePath = uri.path;
      } catch (_) {
        // If Uri parsing fails, treat it as a potential filepath.
      }

      final String resolvedPath = absolute(normalize(join(context.directory.path, effectivePath)));
      final linkedFile = File(resolvedPath);
      if (!linkedFile.existsSync()) {
        final String? suggestion = findSiblingSuggestion(
          originalLink: path,
          resolvedPath: resolvedPath,
        );
        final suggestionClause = suggestion != null ? ' Did you mean "$suggestion"?' : '';
        errors.add(
          ValidationError(
            ruleId: name,
            severity: severity,
            file: _skillFileName,
            message:
                'Linked file does not exist: $path (resolved to $resolvedPath).'
                '$suggestionClause',
          ),
        );
      }
    }

    return errors;
  }
}

/// Looks for a near-miss sibling **file** next to the missing
/// [resolvedPath] and, if one exists, returns the full suggested link as
/// it should appear in the SKILL.md author's markdown — the original
/// link's directory prefix joined to the matched basename, normalized to
/// forward slashes so the suggestion is portable across platforms.
///
/// Returns `null` when:
/// - the original link has no parent dir on disk,
/// - the parent dir can't be listed (e.g. permission error),
/// - or no candidate is close enough to the missing basename.
///
/// [originalLink] is the link text as written in the SKILL.md
/// (`docs/DEATILS.md`); [resolvedPath] is the same link resolved
/// against the skill directory (`/abs/path/skill/docs/DEATILS.md`).
///
/// Subdirectories of the parent are intentionally excluded from the
/// candidate set — links almost always point at files, and suggesting
/// a directory would be misleading.
@visibleForTesting
String? findSiblingSuggestion({required String originalLink, required String resolvedPath}) {
  final String parentPath = dirname(resolvedPath);
  final parentDir = Directory(parentPath);
  if (!parentDir.existsSync()) {
    return null;
  }

  final String missingBase = basename(resolvedPath).toLowerCase();
  if (missingBase.isEmpty) {
    return null;
  }

  // Tunable; chosen to balance typo recall against false positives.
  final int threshold = (missingBase.length ~/ 3).clamp(1, missingBase.length);

  final List<FileSystemEntity> entries;
  try {
    entries = parentDir.listSync();
  } on FileSystemException {
    return null;
  }

  String? best;
  int bestDistance = threshold + 1;
  for (final entity in entries) {
    if (entity is Directory) {
      continue;
    }
    final String candidate = basename(entity.path);
    if (candidate == basename(resolvedPath)) {
      continue;
    }
    final int distance = levenshtein(missingBase, candidate.toLowerCase());
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }

  if (best == null || bestDistance > threshold) {
    return null;
  }

  final String dir = dirname(originalLink);
  if (dir == '.' || dir.isEmpty) {
    return best;
  }
  return join(dir, best).replaceAll(r'\', '/');
}
