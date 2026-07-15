// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A wrapper around raw rule parameters.
///
/// Prevents exposing raw [Map] APIs directly inside rule logic, and provides
/// standard lookups and properties for rule configuration parameters.
class CustomRuleParameters {
  /// Creates a new configuration with the provided [params].
  CustomRuleParameters(Map<String, dynamic> params)
    : params = Map<String, dynamic>.unmodifiable(params);

  /// The underlying map containing the parameters.
  final Map<String, dynamic> params;

  bool get isEmpty => params.isEmpty;

  bool get isNotEmpty => params.isNotEmpty;

  Object? operator [](String key) => params[key];

  Iterable<String> get keys => params.keys;

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
