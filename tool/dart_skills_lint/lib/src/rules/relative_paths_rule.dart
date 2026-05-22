import 'dart:io';
import 'package:path/path.dart';
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
        final String? suggestion = findSiblingSuggestion(resolvedPath);
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

/// Finds the existing sibling file most similar to the (missing) basename
/// of [resolvedPath], using Levenshtein distance over case-folded names.
///
/// Returns the suggested path as it would have appeared in the link (parent
/// directory of the original link joined to the matched basename), or `null`
/// if the parent directory does not exist or no close match was found.
///
/// The distance threshold is `max(1, basename.length ~/ 3)` — tight enough to
/// avoid surfacing unrelated files in a busy directory, loose enough to catch
/// typos in moderately long filenames.
String? findSiblingSuggestion(String resolvedPath) {
  final String parentPath = dirname(resolvedPath);
  final parentDir = Directory(parentPath);
  if (!parentDir.existsSync()) {
    return null;
  }

  final String missingBase = basename(resolvedPath).toLowerCase();
  if (missingBase.isEmpty) {
    return null;
  }

  final int threshold = (missingBase.length ~/ 3).clamp(1, missingBase.length);

  String? best;
  int bestDistance = threshold + 1;
  for (final FileSystemEntity entity in parentDir.listSync()) {
    final String candidate = basename(entity.path);
    if (candidate == basename(resolvedPath)) {
      continue;
    }
    final int distance = _levenshtein(missingBase, candidate.toLowerCase());
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }

  if (best == null || bestDistance > threshold) {
    return null;
  }
  return best;
}

/// Plain Levenshtein edit distance over runes. O(n*m) time, O(m) space.
int _levenshtein(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }

  final List<int> aCodes = a.runes.toList();
  final List<int> bCodes = b.runes.toList();

  var previous = List<int>.generate(bCodes.length + 1, (j) => j);
  var current = List<int>.filled(bCodes.length + 1, 0);
  for (var i = 1; i <= aCodes.length; i++) {
    current[0] = i;
    for (var j = 1; j <= bCodes.length; j++) {
      final cost = aCodes[i - 1] == bCodes[j - 1] ? 0 : 1;
      final int del = previous[j] + 1;
      final int ins = current[j - 1] + 1;
      final int sub = previous[j - 1] + cost;
      current[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[bCodes.length];
}
