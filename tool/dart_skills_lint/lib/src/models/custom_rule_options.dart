// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A wrapper around raw rule options parameters.
///
/// Prevents exposing raw [Map] APIs directly inside rule logic, and provides
/// standard lookups and properties for rule configuration parameters.
class CustomRuleOptions {
  const CustomRuleOptions(this.params);

  /// The underlying map containing the parameters.
  final Map<String, dynamic> params;

  /// Whether the configuration contains no parameters.
  bool get isEmpty => params.isEmpty;

  /// Whether the configuration contains parameters.
  bool get isNotEmpty => params.isNotEmpty;

  /// Retrieves the value of the parameter associated with [key].
  Object? operator [](String key) => params[key];

  /// The parameter keys defined in this configuration.
  Iterable<String> get keys => params.keys;

  /// Whether the configuration contains the specified [key].
  bool containsKey(String key) => params.containsKey(key);

  /// Retrieves the value of the parameter associated with [key] as a [String].
  ///
  /// Returns `null` if the value is missing or not a [String].
  String? getString(String key) {
    final Object? val = params[key];
    return val is String ? val : null;
  }

  /// Retrieves the value of the parameter associated with [key] as an [int].
  ///
  /// Returns `null` if the value is missing or not an [int].
  int? getInt(String key) {
    final Object? val = params[key];
    return val is int ? val : null;
  }

  /// Retrieves the value of the parameter associated with [key] as a [bool].
  ///
  /// Returns `null` if the value is missing or not a [bool].
  bool? getBool(String key) {
    final Object? val = params[key];
    return val is bool ? val : null;
  }

  /// Retrieves the value of the parameter associated with [key] as a [List] of [String]s.
  ///
  /// Returns `null` if the value is missing or not a [List].
  List<String>? getStringList(String key) {
    final Object? val = params[key];
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return null;
  }
}
