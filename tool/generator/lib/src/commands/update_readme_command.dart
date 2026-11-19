// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../models/skill_params.dart';
import 'base_yaml_command.dart';

/// Command to update the README.md file with a table of available skills.
class UpdateReadmeCommand extends BaseYamlCommand {
  /// Creates a new [UpdateReadmeCommand].
  UpdateReadmeCommand({super.outputDir})
    : super(logger: Logger('UpdateReadmeCommand')) {
    argParser.addOption(
      'readme',
      help: 'Path to the README.md file to update.',
    );
  }

  static final RegExp _tableLineRegExp = RegExp(
    r'^\| \[([^\]]+)\]\([^)]+\) \| [^|]+ \| ([^|]+) \|',
    multiLine: true,
  );
  static final RegExp _sectionHeaderRegExp = RegExp(
    '^## (Available Skills|List of Skills|Skills List|Skill Index)',
    caseSensitive: false,
    multiLine: true,
  );
  static final RegExp _nextSectionRegExp = RegExp(r'\n##\s');

  @override
  String get name => 'update-readme';

  @override
  String get description =>
      'Updates the README.md with a table of available skills from the configuration.';

  @override
  Future<void> runWithSkills(
    List<SkillParams> skills,
    Directory outputDir, {
    Directory? configDir,
  }) async {
    String readmePath;
    if (argResults?['readme'] != null) {
      readmePath = argResults!['readme'] as String;
    } else if (argResults!.rest.length > 1) {
      readmePath = argResults!.rest[1];
    } else {
      final dirReadme = File(p.join(outputDir.path, 'README.md'));
      final parentReadme = File(p.join(outputDir.parent.path, 'README.md'));

      if (dirReadme.existsSync()) {
        readmePath = dirReadme.path;
      } else if (parentReadme.existsSync()) {
        readmePath = parentReadme.path;
      } else {
        readmePath = 'README.md';
      }
    }

    final readmeFile = File(readmePath);

    if (!readmeFile.existsSync()) {
      logger.severe('README file not found at $readmePath');
      return;
    }

    logger.info('Updating README at ${readmeFile.path}...');

    final content = readmeFile.readAsStringSync();

    // Parse existing example prompts from the README if they exist
    final existingPrompts = <String, String>{};
    for (final match in _tableLineRegExp.allMatches(content)) {
      final skillName = match.group(1)!;
      final prompt = match.group(2)!.trim();
      if (prompt.isNotEmpty) {
        existingPrompts[skillName] = prompt;
      }
    }

    // Generate the table
    final buffer = StringBuffer()
      ..writeln('| Skill | Description | Example prompt |')
      ..writeln('|---|---|---|');

    // Sort skills by name for consistency
    final sortedSkills = List<SkillParams>.from(skills)
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final skill in sortedSkills) {
      // Calculate relative link from README to the SKILL.md file
      final skillFile = File(p.join(outputDir.path, skill.name, 'SKILL.md'));
      var relativeLink = p.relative(
        skillFile.path,
        from: readmeFile.parent.path,
      );

      // Ensure the link contains the skills/ directory in the URL.
      if (!relativeLink.contains('skills/')) {
        relativeLink = p.join('skills', relativeLink);
      }

      // Ensure we use forward slashes for the markdown link.
      relativeLink = relativeLink.replaceAll('\\', '/');

      final prompt = skill.examplePrompt ?? existingPrompts[skill.name] ?? '';

      buffer.writeln(
        '| [${skill.name}]($relativeLink) | ${skill.description} | $prompt |',
      );
    }

    final newTable = buffer.toString();

    // Find where to insert the table
    final match = _sectionHeaderRegExp.firstMatch(content);

    String updatedContent;
    if (match != null) {
      // Find the end of the line with the header
      final headerEnd = content.indexOf('\n', match.start);
      // Find the next section header or end of file
      final nextSectionIndex = content.indexOf(
        _nextSectionRegExp,
        headerEnd + 1,
      );

      final prefix = content.substring(
        0,
        headerEnd == -1 ? content.length : headerEnd + 1,
      );
      final suffix = nextSectionIndex != -1
          ? content.substring(nextSectionIndex)
          : '';

      updatedContent = '${prefix.trimRight()}\n\n$newTable${suffix.trimLeft()}';
    } else {
      // Add a new section at the end
      updatedContent =
          '${content.trimRight()}\n\n## Available Skills\n\n$newTable';
    }

    readmeFile.writeAsStringSync('${updatedContent.trimRight()}\n');
    logger.info('Successfully updated $readmePath');
  }
}
