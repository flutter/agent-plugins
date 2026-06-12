// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Pins the BSD copyright header to every Dart source file in the package.
///
/// Every `.dart` file in `lib/`, `bin/`, and `test/` must begin with the
/// standard three-line copyright block. The year is not pinned — any four-digit
/// year is accepted — but the rest of the text is matched exactly.
void main() {
  test('every Dart file has a BSD copyright header', () {
    final String packageRoot = p.normalize(p.absolute('.'));
    final List<String> missing = [];

    for (final dir in ['bin', 'lib', 'test']) {
      final source = Directory(p.join(packageRoot, dir));
      if (!source.existsSync()) {
        continue;
      }
      for (final FileSystemEntity entity in source.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final String content = entity.readAsStringSync();
          if (!_hasCopyrightHeader(content)) {
            missing.add(p.relative(entity.path, from: packageRoot));
          }
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'The following Dart files are missing the BSD copyright header:\n'
          '  ${missing.join('\n  ')}\n\n'
          'Add the following block as the first three lines of each file:\n'
          '  // Copyright (c) <year>, the Dart project authors.  Please see the AUTHORS file\n'
          '  // for details. All rights reserved. Use of this source code is governed by a\n'
          '  // BSD-style license that can be found in the LICENSE file.',
    );
  });
}

final RegExp _copyrightPattern = RegExp(
  r'^// Copyright \(c\) \d{4}, the Dart project authors\. {2}Please see the AUTHORS file\n'
  r'// for details\. All rights reserved\. Use of this source code is governed by a\n'
  r'// BSD-style license that can be found in the LICENSE file\.',
);

bool _hasCopyrightHeader(String content) {
  // Allow an optional shebang line (and any following blank lines) before the
  // copyright header.
  final String checkContent = content.startsWith('#!')
      ? content.substring(content.indexOf('\n') + 1).replaceFirst(RegExp(r'^\n*'), '')
      : content;
  return _copyrightPattern.hasMatch(checkContent);
}
