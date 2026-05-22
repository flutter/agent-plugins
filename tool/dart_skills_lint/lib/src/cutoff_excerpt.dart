// Shared helper for "field is N characters; max is M" diagnostics that
// also show a |HERE| cutoff excerpt so the author can see exactly
// where the value went over.
//
// Used by both DescriptionLengthRule and the compatibility-length
// check in ValidYamlMetadataRule. Keep the message shape consistent
// across rules so downstream tooling that parses lint output doesn't
// have to learn two formats.

/// Number of characters of context to show on either side of the cutoff.
const int _excerptContextChars = 40;

/// Builds a length-overflow diagnostic for a frontmatter field whose
/// value is longer than [maxLength].
///
/// Output shape:
///
///   <fieldName> field is <N> characters; maximum is <maxLength>.
///   Cutoff at character <maxLength>: ...<context>|HERE|<context>...
///   (see <docUrl>)
///
/// The `(see ...)` clause is omitted when [docUrl] is null. Newlines in
/// the excerpt are escaped to `\n` so the message stays on one line.
String buildLengthDiagnostic({
  required String fieldName,
  required String value,
  required int maxLength,
  String? docUrl,
}) {
  final String excerpt = _buildCutoffExcerpt(value, maxLength);
  final docsClause = docUrl != null ? ' (see $docUrl)' : '';
  return '$fieldName field is ${value.length} characters; '
      'maximum is $maxLength. '
      'Cutoff at character $maxLength: $excerpt'
      '$docsClause';
}

String _buildCutoffExcerpt(String value, int maxLength) {
  final int start = (maxLength - _excerptContextChars).clamp(0, value.length);
  final int end = (maxLength + _excerptContextChars).clamp(0, value.length);
  final String before = value.substring(start, maxLength);
  final String after = value.substring(maxLength, end);
  final leadingEllipsis = start > 0 ? '...' : '';
  final trailingEllipsis = end < value.length ? '...' : '';
  final String escapedBefore = _escapeForOneLine(before);
  final String escapedAfter = _escapeForOneLine(after);
  return '$leadingEllipsis$escapedBefore|HERE|$escapedAfter$trailingEllipsis';
}

String _escapeForOneLine(String s) {
  return s.replaceAll('\n', r'\n').replaceAll('\r', r'\r');
}
