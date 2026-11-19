// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Recommended maximum line count for a `SKILL.md` file per the Agent Skills
/// standard (https://agentskills.io).
const int maxRecommendedSkillLines = 500;

/// Maximum `description` length in characters per the Agent Skills standard
/// (https://agentskills.io).
const int maxSkillDescriptionLength = 1024;

/// Approximate ratio of LLM tokens per whitespace-delimited word.
///
/// Subword tokenizers used by Gemini (SentencePiece/BPE) average roughly
/// 4 characters per token, or 100 tokens per 60–80 English words (~0.75 words
/// per token, whose reciprocal is ~1.33 tokens per word). We use `1.3` as a
/// fast offline dry-run heuristic without making network calls to `countTokens`.
///
/// See: https://ai.google.dev/gemini-api/docs/tokens
const double tokensPerWordEstimate = 1.3;

final RegExp _nonWhitespaceWordRegExp = RegExp(r'\S+');

/// Extension methods on [RegExp] for match counting without allocating
/// intermediate substring lists.
extension RegExpMatchCount on RegExp {
  /// Returns the number of non-overlapping matches of this pattern in [input]
  /// without allocating intermediate substring lists.
  int countMatches(String input) => allMatches(input).length;
}

/// Extension methods on [String] for document size and token estimation.
extension StringMetrics on String {
  /// Number of whitespace-delimited words in this string.
  int get wordCount => _nonWhitespaceWordRegExp.countMatches(this);

  /// Approximate LLM token count using [tokensPerWordEstimate] (~1.3 tokens
  /// per whitespace-delimited word).
  int get approximateTokenCount => (wordCount * tokensPerWordEstimate).round();

  /// Number of lines in this string without allocating intermediate substrings.
  ///
  /// Matches `LineSplitter` semantics for `\n`, `\r`, and `\r\n`, ignoring a
  /// single trailing line terminator at the end of the string.
  int get lineCount {
    if (isEmpty) return 0;
    var lines = 0;
    for (var i = 0; i < length; i++) {
      final unit = codeUnitAt(i);
      if (unit == 0x0D) {
        lines++;
        if (i + 1 < length && codeUnitAt(i + 1) == 0x0A) {
          i++;
        }
        if (i == length - 1) {
          return lines;
        }
      } else if (unit == 0x0A) {
        lines++;
        if (i == length - 1) {
          return lines;
        }
      }
    }
    return lines + 1;
  }
}
