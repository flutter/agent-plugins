// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'models/skill_rule.dart';

/// Interface for rules that support fixes.
/// Kept internal to the package.
abstract class FixableRule extends SkillRule {
  /// Returns the updated content of the file at [filePath].
  /// [currentContent] is the content after previous fixes have been applied.
  /// If the rule does not support fixing the file at [filePath], it should return [currentContent].
  ///
  /// Rules should rely on [currentContent] for the current state of the file.
  /// If a rule needs structured access (like parsed YAML), it should parse
  /// [currentContent] itself, as structured data in [SkillContext] may be stale
  /// if previous rules applied fixes.
  Future<String> fix(String filePath, String currentContent, Directory directory);
}
