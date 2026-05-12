// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_skills_lint/src/validation_session.dart';
import 'package:test/test.dart';

void main() {
  group('computeLineDiff', () {
    test('returns empty list when texts are identical', () {
      expect(computeLineDiff('a\nb\nc', 'a\nb\nc'), isEmpty);
    });

    test('emits paired - and + lines for a pure modification', () {
      const original = 'line1\nline2  \nline3';
      const modified = 'line1\nline2\nline3';

      expect(computeLineDiff(original, modified), <String>['- Line 2: line2  ', '+ Line 2: line2']);
    });

    test('emits only + lines for a pure insertion at the end', () {
      const original = 'a\nb';
      const modified = 'a\nb\nc';

      expect(computeLineDiff(original, modified), <String>['+ Line 3: c']);
    });

    test('emits only + lines for a pure insertion in the middle', () {
      const original = 'a\nc';
      const modified = 'a\nb\nc';

      expect(computeLineDiff(original, modified), <String>['+ Line 2: b']);
    });

    test('emits only - lines for a pure deletion', () {
      const original = 'a\nb\nc';
      const modified = 'a\nc';

      expect(computeLineDiff(original, modified), <String>['- Line 2: b']);
    });

    test('handles mixed modification + insertion with correct line numbers', () {
      const original = 'header\nbody\nfooter';
      const modified = 'header\nbody-fixed\nextra\nfooter';

      expect(computeLineDiff(original, modified), <String>[
        '- Line 2: body',
        '+ Line 2: body-fixed',
        '+ Line 3: extra',
      ]);
    });

    test('handles deletion followed by modification with correct line numbers', () {
      const original = 'a\nb\nc\nd';
      const modified = 'a\nc-fixed\nd';

      expect(computeLineDiff(original, modified), <String>[
        '- Line 2: b',
        '- Line 3: c',
        '+ Line 2: c-fixed',
      ]);
    });

    test('preserves significant whitespace in line contents', () {
      const original = '\t indented\n  spaced';
      const modified = '\t fixed\n  spaced';

      expect(computeLineDiff(original, modified), <String>[
        '- Line 1: \t indented',
        '+ Line 1: \t fixed',
      ]);
    });
  });
}
