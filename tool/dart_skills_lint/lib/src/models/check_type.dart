// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'analysis_severity.dart';

/// Encapsulates metadata and severity state for a specific validation rule.
class CheckType {
  const CheckType({
    required this.name,
    required this.defaultSeverity,
    required this.help,
    this.allowedOptions = const {},
  });
  final String name;

  /// The default severity if not overridden by config or flags.
  final AnalysisSeverity defaultSeverity;

  /// The help message displayed by the CLI.
  final String help;

  /// Custom configuration options supported by this check.
  final Map<String, Type> allowedOptions;
}
