// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Classifies multi-dot build artifacts using list patterns instead of nested
/// regular expressions.
library;

/// Known build output artifacts for a compiled web entrypoint.
enum BuildArtifact {
  entrypoint,
  sourceMap,
  deferredPart,
  supportRuntime;

  /// Parses [name] into a [BuildArtifact], or returns `null` for unrecognized
  /// files.
  static BuildArtifact? tryParse(String name) => switch (name.split('.')) {
    ['main', 'dart', 'js'] => entrypoint,
    ['main', 'dart', 'js', 'map'] => sourceMap,
    // Matches numbered chunks like 'main.dart.1.part.js' or 'main.dart.1.min.part.js'.
    ['main', 'dart', final part, ..., 'part', 'js']
        when int.tryParse(part) != null =>
      deferredPart,
    // Stays distinct instead of being swallowed by a 'main.dart.*.js' wildcard.
    ['main', 'dart', 'support', 'js'] => supportRuntime,
    _ => null,
  };
}

void main() {
  const samples = [
    'main.dart.js',
    'main.dart.js.map',
    'main.dart.1.part.js',
    'main.dart.12.min.part.js',
    'main.dart.support.js',
    'main.dart.alpha.part.js',
    'main.dart.js.info.json',
  ];

  for (final sample in samples) {
    print('$sample -> ${BuildArtifact.tryParse(sample)}');
  }
}
