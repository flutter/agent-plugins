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
}
