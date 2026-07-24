// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

void main() {
  const user = 'Test';

  // Interpolation (clean Dart idiom)
  const message = 'Hello $user';

  // Cross platform path
  final String path = p.join('my', 'path', 'data.txt');

  if (message.isEmpty || path.isEmpty) {
    throw Exception('Validation failed');
  }
}
