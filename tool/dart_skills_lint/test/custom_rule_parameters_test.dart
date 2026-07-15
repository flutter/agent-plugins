// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_skills_lint/src/models/custom_rule_parameters.dart';
import 'package:test/test.dart';

void main() {
  test('CustomRuleParameters params map is unmodifiable', () {
    final parameters = CustomRuleParameters({'key': 'value'});

    expect(() => parameters.params['new_key'] = 'new_value', throwsA(isUnsupportedError));
    expect(() => parameters.params.remove('key'), throwsA(isUnsupportedError));
    expect(() => parameters.params.clear(), throwsA(isUnsupportedError));
  });
}
