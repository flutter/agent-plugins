// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:dart_skills_lint/src/path_utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('expandPath', () {
    test('expands tilde at start of path', () {
      final String? home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        expect(expandPath('~/some/path'), equals(p.join(home, 'some/path')));
      } else {
        // If home is null, it should return the path as is.
        expect(expandPath('~/some/path'), equals('~/some/path'));
      }
    });

    test('does not expand tilde not at start of path', () {
      expect(expandPath('some/~/path'), equals('some/~/path'));
    });

    test('returns path as is if it does not start with tilde', () {
      expect(expandPath('some/path'), equals('some/path'));
      expect(expandPath('/absolute/path'), equals('/absolute/path'));
    });
  });
}
