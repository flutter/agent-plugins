// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Defines the expected schema types for custom rule configuration options.
enum RuleOptionType {
  string,
  integer,
  boolean,
  stringList,
  regExp;

  /// Returns whether [value] matches this schema type constraint and syntax format.
  bool isValid(Object? value) {
    switch (this) {
      case RuleOptionType.string:
        return value is String;
      case RuleOptionType.integer:
        return value is int;
      case RuleOptionType.boolean:
        return value is bool;
      case RuleOptionType.stringList:
        return value is List && value.every((e) => e is String);
      case RuleOptionType.regExp:
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
      case RuleOptionType.string:
        return 'String';
      case RuleOptionType.integer:
        return 'int';
      case RuleOptionType.boolean:
        return 'bool';
      case RuleOptionType.stringList:
        return 'List<String>';
      case RuleOptionType.regExp:
        return 'RegExp (valid regular expression string)';
    }
  }
}
