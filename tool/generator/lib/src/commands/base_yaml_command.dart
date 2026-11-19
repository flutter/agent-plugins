// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/skill_params.dart';

/// Base command for operations that read skills from a YAML file.
abstract class BaseYamlCommand extends Command<void> {
  /// Creates a new [BaseYamlCommand].
  BaseYamlCommand({required this.logger, this.outputDir}) {
    argParser
      ..addOption('skill', help: 'Process only the specified skill by name.')
      ..addOption(
        'directory',
        abbr: 'd',
        help: 'The directory to search for skills.',
      );
  }

  /// The logger for this command.
  final Logger logger;

  /// The directory to find generated skills.
  final Directory? outputDir;

  @override
  Future<void> run() async {
    final inputFile = argResults!.rest.isNotEmpty
        ? argResults!.rest.first
        : 'resources/flutter_skills.yaml';

    final file = File(inputFile);
    if (!file.existsSync()) {
      logger.severe('Configuration file not found: $inputFile');
      return;
    }

    final yamlContent = file.readAsStringSync();
    final YamlList yamlList;
    try {
      final decoded = loadYaml(yamlContent);
      if (decoded is! YamlList) {
        logger.severe('Invalid configuration: Root must be a YAML list.');
        return;
      }
      yamlList = decoded;
    } on YamlException catch (e) {
      logger.severe('Invalid YAML syntax in $inputFile: $e');
      return;
    }

    if (!validateYamlList(yamlList, p.basename(file.path))) {
      logger.severe('Configuration validation failed.');
      return;
    }

    final skills = <SkillParams>[];
    for (var i = 0; i < yamlList.length; i++) {
      final item = yamlList[i];
      if (item is! Map<Object?, Object?>) {
        logger.severe('Invalid configuration: Item $i is not a Map.');
        return;
      }
      try {
        skills.add(SkillParams.fromYamlMap(item));
      } on FormatException catch (e) {
        logger.severe('Invalid configuration at item $i: ${e.message}');
        return;
      }
    }

    final skillFilter = argResults?['skill'] as String?;
    final targetSkills = skillFilter != null
        ? skills.where((s) => s.name == skillFilter).toList()
        : skills;

    if (targetSkills.isEmpty) {
      if (skillFilter != null) {
        logger.warning('No skill found with name: $skillFilter');
      } else {
        logger.warning('No skills found in configuration file.');
      }
      return;
    }

    final directoryArg = argResults?['directory'] as String?;
    final outDir = directoryArg != null
        ? Directory(directoryArg)
        : (outputDir ?? Directory('skills'));

    await runWithSkills(targetSkills, outDir, configDir: file.parent);
  }

  /// Validates the raw [yamlList] before converting entries to [SkillParams].
  ///
  /// Subclasses such as `ValidateSkillCommand` can override this method to
  /// perform schema checks without reading or parsing the YAML file twice.
  @protected
  bool validateYamlList(YamlList yamlList, String fileName) => true;

  /// Executes the command with the parsed and filtered list of skills.
  Future<void> runWithSkills(
    List<SkillParams> skills,
    Directory outputDir, {
    Directory? configDir,
  });
}
