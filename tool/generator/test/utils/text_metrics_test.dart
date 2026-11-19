// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:skills/src/utils/text_metrics.dart';
import 'package:test/test.dart';

void main() {
  group('Agent Skills standard constants', () {
    test('exposes expected Agent Skills limits and token ratio', () {
      expect(maxRecommendedSkillLines, 500);
      expect(maxSkillDescriptionLength, 1024);
      expect(tokensPerWordEstimate, 1.3);
    });
  });

  group('RegExpMatchCount', () {
    test('returns 0 when input is empty or has no matches', () {
      final digits = RegExp(r'\d+');
      expect(digits.countMatches(''), 0);
      expect(digits.countMatches('no numbers here'), 0);
    });

    test('counts non-overlapping matches across single and multiple lines', () {
      final digits = RegExp(r'\d+');
      expect(digits.countMatches('1 22 333\n4444'), 4);

      final headings = RegExp(r'^#+\s+', multiLine: true);
      expect(headings.countMatches('# Title\nBody\n## Section 1\n### Sub'), 3);
    });
  });

  group('StringMetrics', () {
    group('wordCount', () {
      test('returns 0 for empty and whitespace-only strings', () {
        expect(''.wordCount, 0);
        expect('   '.wordCount, 0);
        expect('\t\n\r\n  '.wordCount, 0);
      });

      test('counts single and multiple whitespace-delimited words', () {
        expect('hello'.wordCount, 1);
        expect('  hello   world  '.wordCount, 2);
        expect('one\ttwo\nthree\r\nfour'.wordCount, 4);
      });

      test('counts markdown tokens and punctuation-attached words', () {
        const markdown = '# Heading\n\n- `code_symbol`: value (v1.2.3)';
        // Tokens: #, Heading, -, `code_symbol`:, value, (v1.2.3)
        expect(markdown.wordCount, 6);
      });
    });

    group('approximateTokenCount', () {
      test('returns 0 for empty and whitespace-only strings', () {
        expect(''.approximateTokenCount, 0);
        expect('  \n\t '.approximateTokenCount, 0);
      });

      test('multiplies wordCount by 1.3 and rounds to nearest integer', () {
        // 1 * 1.3 = 1.3 -> 1
        expect('one'.approximateTokenCount, 1);
        // 2 * 1.3 = 2.6 -> 3
        expect('one two'.approximateTokenCount, 3);
        // 4 * 1.3 = 5.2 -> 5
        expect('one two three four'.approximateTokenCount, 5);
        // 7 * 1.3 = 9.1 -> 9
        expect('a b c d e f g'.approximateTokenCount, 9);
        // 8 * 1.3 = 10.4 -> 10
        expect('a b c d e f g h'.approximateTokenCount, 10);
        // 10 * 1.3 = 13.0 -> 13
        expect('a b c d e f g h i j'.approximateTokenCount, 13);
      });
    });

    group('lineCount', () {
      test('returns 0 for empty string', () {
        expect(''.lineCount, 0);
      });

      test('counts single and multi-line LF, CR, and CRLF strings', () {
        expect('single line'.lineCount, 1);
        expect('line 1\nline 2\nline 3'.lineCount, 3);
        expect('line 1\rline 2\rline 3'.lineCount, 3);
        expect('line 1\r\nline 2\r\nline 3'.lineCount, 3);
      });

      test('matches LineSplitter across trailing newline edge cases', () {
        const samples = <String>[
          '',
          '\n',
          '\r',
          '\r\n',
          '\n\n',
          '\r\n\r\n',
          'a',
          'a\n',
          'a\r',
          'a\r\n',
          'line 1\nline 2\n',
          'line 1\nline 2\n\n',
          'line 1\rline 2\r\nline 3\n',
        ];
        for (final sample in samples) {
          expect(
            sample.lineCount,
            const LineSplitter().convert(sample).length,
            reason: 'Mismatch for ${jsonEncode(sample)}',
          );
        }
      });
    });
  });
}
