// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:skills_lint/skills_lint.dart';
import 'package:test/test.dart';

void main() {
  test('Validate skills.sh.json', () {
    final currentPath = Directory.current.path;
    final repoRoot = currentPath.endsWith(p.join('tool', 'generator'))
        ? Directory.current.parent.parent
        : Directory.current;
    final skillsDir = Directory(p.join(repoRoot.path, 'skills'));
    expect(skillsDir.existsSync(), isTrue);

    final actualSkills = skillsDir
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .where((name) => !name.startsWith('.'))
        .toSet();
    expect(actualSkills, isNotEmpty);

    final skillsShFile = File(p.join(repoRoot.path, 'skills.sh.json'));
    expect(skillsShFile.existsSync(), isTrue);

    final skillsShJson =
        jsonDecode(skillsShFile.readAsStringSync()) as Map<String, Object?>;
    expect(
      skillsShJson[r'$schema'],
      'https://skills.sh/schemas/skills.sh.json',
    );
    expect(skillsShJson['notGrouped'], 'bottom');

    final groups = (skillsShJson['groups'] as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(groups, isNotEmpty);

    final groupedSkills = <String>{};
    for (final group in groups) {
      final title = group['title'];
      expect(
        title,
        isA<String>().having(
          (s) =>
              s.trim().isNotEmpty && s.trim().split(RegExp(r'\s+')).length <= 3,
          '1-3 words',
          isTrue,
        ),
      );
      expect(
        group['description'],
        isA<String>().having((s) => s.isNotEmpty, 'non-empty', isTrue),
      );
      final skills = (group['skills'] as List<Object?>).cast<String>();
      expect(skills, isNotEmpty);
      for (final skill in skills) {
        expect(
          groupedSkills.add(skill),
          isTrue,
          reason: 'Duplicate skill "$skill" in skills.sh.json',
        );
      }
    }

    expect(groupedSkills, equals(actualSkills));

    final readmeFile = File(p.join(repoRoot.path, 'README.md'));
    expect(readmeFile.existsSync(), isTrue);
    final readmeMatches = RegExp(
      r'\| \[([^\]]+)\]\(skills/\1/SKILL\.md\) \|',
    ).allMatches(readmeFile.readAsStringSync());
    final readmeSkills = readmeMatches.map((m) => m.group(1)!).toSet();
    final actualFlutterSkills = actualSkills
        .where((s) => s.startsWith('flutter-'))
        .toSet();
    expect(readmeSkills, equals(actualFlutterSkills));
  });

  test('Run skills linter', () async {
    final lintErrors = <String>[];
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen((record) {
      if (record.level >= Level.WARNING) {
        lintErrors.add('${record.level.name}: ${record.message}');
      }
      printOnFailure('${record.level.name}: ${record.message}');
    });

    final originalDir = Directory.current;
    final isGenerator = originalDir.path.endsWith(p.join('tool', 'generator'));
    final isRoot = File(
      p.join(originalDir.path, 'tool', 'generator', 'skills_lint.yaml'),
    ).existsSync();

    if (!isGenerator && isRoot) {
      Directory.current = Directory(
        p.join(originalDir.path, 'tool', 'generator'),
      );
    }

    try {
      final configFile = File('skills_lint.yaml');
      expect(
        configFile.existsSync(),
        isTrue,
        reason:
            'skills_lint.yaml configuration file must exist in ${Directory.current.path}',
      );

      final skills = Directory(
        p.join('..', '..', 'skills'),
      ).listSync().whereType<Directory>();
      expect(
        skills,
        isNotEmpty,
        reason: 'Expected skills directory to contain skills.',
      );

      final config = await ConfigParser.loadConfig();
      expect(
        config.directoryConfigs,
        isNotEmpty,
        reason: 'Configuration directoryConfigs should not be empty.',
      );

      final isValid = await validateSkills(config: config);
      expect(
        isValid,
        isTrue,
        reason:
            'Skills linting failed with the following issues:\n${lintErrors.join('\n')}',
      );
    } finally {
      if (!isGenerator && isRoot) {
        Directory.current = originalDir;
      }
      await subscription.cancel();
    }
  });
}
