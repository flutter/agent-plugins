// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Checks if a file path points to a Dart file that should be processed by hooks.
///
/// Excludes generated files like `.g.dart` and `.mocks.dart`.
bool filterGeneratedFiles(String filePath) {
  return filePath.endsWith('.dart') &&
      !filePath.endsWith('.g.dart') &&
      !filePath.endsWith('.mocks.dart');
}
