// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: unused_local_variable, prefer_final_locals, avoid_print, use_raw_strings

// Violates placement hygiene (in tmp/ instead of bin/ or lib/)
// Violates cross-platform compatibility (hardcoded Windows path)
// Violates effective Dart idioms (raw strings instead of interpolation)

void main() {
  var user = 'Test';

  // Anti-pattern: Raw string concatenation instead of interpolation
  print(r'Hello ' + user);

  // Anti-pattern: Hardcoded platform specific path
  var path = 'C:\\my\\path\\data.txt';
}
