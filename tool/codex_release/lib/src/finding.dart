/// A problem found while validating a plugin package.
///
/// [code] matches the error name in OpenAI's plugin submission errors
/// reference (https://developers.openai.com/plugins/deploy/submission-errors)
/// where one exists. Checks specific to this repository's release process use
/// codes that start with `release_`.
class Finding {
  const Finding(this.code, this.message, {this.path});

  /// The OpenAI error name, or a `release_` code for repo-specific checks.
  final String code;

  /// A human-readable description of the problem.
  final String message;

  /// The archive path or manifest field the finding refers to, if any.
  final String? path;

  @override
  String toString() =>
      path == null ? '$code: $message' : '$code: $message ($path)';
}
