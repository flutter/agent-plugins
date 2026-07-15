// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_skills_lint/src/models/custom_rule_options.dart';
import 'package:test/test.dart';

void main() {
  test('CustomRuleOptions params map is unmodifiable', () {
    final options = CustomRuleOptions({'key': 'value'});

    expect(() => options.params['new_key'] = 'new_value', throwsA(isUnsupportedError));
    expect(() => options.params.remove('key'), throwsA(isUnsupportedError));
    expect(() => options.params.clear(), throwsA(isUnsupportedError));
  });
}
