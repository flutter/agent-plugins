// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

/// Drift guard for the `example/valid` and `example/invalid` fixtures.
///
/// The fixtures and `example/README.md` make precise claims about which
/// rules fire and what their diagnostics look like. This test pins both:
///
/// - `example/valid` must exit 0 with no error output under default rules.
/// - `example/invalid` must exit 1 with `invalid-skill-name` under default
///   rules, and must surface all three intended rules when the other two
///   are escalated.
///
/// Failures here mean either the fixtures have drifted from the README,
/// or a rule's diagnostic wording has changed without the README catching
/// up. Fix one or the other — do not silence the test.
void main() {
  group('example fixtures', () {
    final String cliPath = p.normalize(p.absolute('bin/cli.dart'));
    final String validPath = p.normalize(p.absolute('example/valid'));
    final String invalidPath = p.normalize(p.absolute('example/invalid'));

    test('example/valid passes with default rules', () async {
      final TestProcess process = await TestProcess.start('dart', [
        cliPath,
        '--skill',
        validPath,
      ]);

      final List<String> stdout = await process.stdout.rest.toList();
      final String stdoutStr = stdout.join('\n');
      expect(stdoutStr, contains('--- Validating skill: valid ---'));
      expect(stdoutStr, contains('Skill is valid.'));
      await process.shouldExit(0);
    });

    test('example/invalid fails on invalid-skill-name with default rules', () async {
      final TestProcess process = await TestProcess.start('dart', [
        cliPath,
        '--skill',
        invalidPath,
      ]);

      final List<String> stderr = await process.stderr.rest.toList();
      final String stderrStr = stderr.join('\n');

      // DT4 wording — disambiguated frontmatter-vs-dir + suggestion.
      expect(stderrStr, contains('Frontmatter `name` "NotInvalid" must be lowercase'));
      expect(stderrStr, contains('does not match the parent directory name "invalid"'));
      expect(stderrStr, contains('Suggested: "notinvalid"'));

      await process.shouldExit(1);
    });

    test(
      'example/invalid surfaces disallowed-field and check-absolute-paths when escalated',
      () async {
        final TestProcess process = await TestProcess.start('dart', [
          cliPath,
          '--skill',
          invalidPath,
          '--disallowed-field',
          '--check-absolute-paths',
        ]);

        final List<String> stderr = await process.stderr.rest.toList();
        final String stderrStr = stderr.join('\n');

        // disallowed-field
        expect(stderrStr, contains('Disallowed field: secret_field'));
        // check-absolute-paths — DT5 wording includes the rationale.
        expect(stderrStr, contains('Absolute filepath found in link: /tmp/this/does/not/exist.md'));
        expect(stderrStr, contains('portable'));
        // invalid-skill-name still fires.
        expect(stderrStr, contains('Frontmatter `name`'));

        await process.shouldExit(1);
      },
    );
  });
}
