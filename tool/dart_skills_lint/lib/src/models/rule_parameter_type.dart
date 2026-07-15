// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Defines the expected schema types for custom rule configuration parameters.
enum RuleParameterType {
  string,
  integer,
  boolean,
  stringList,
  regExp;

  /// Returns whether [value] matches this schema type constraint and syntax format.
  bool isValid(Object? value) {
    switch (this) {
      case RuleParameterType.string:
        return value is String;
      case RuleParameterType.integer:
        return value is int;
      case RuleParameterType.boolean:
        return value is bool;
      case RuleParameterType.stringList:
        return value is List && value.every((e) => e is String);
      case RuleParameterType.regExp:
        if (value is! String) {
          return false;
        }
        try {
          RegExp(value);
          return true;
        } on FormatException {
          return false;
        }
    }
  }

  /// User-facing type description.
  String get description {
    switch (this) {
      case RuleParameterType.string:
        return 'String';
      case RuleParameterType.integer:
        return 'int';
      case RuleParameterType.boolean:
        return 'bool';
      case RuleParameterType.stringList:
        return 'List<String>';
      case RuleParameterType.regExp:
        return 'RegExp (valid regular expression string)';
    }
  }
}
