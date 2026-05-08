// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/skill_params.dart';
import '../services/gemini_service.dart';
import '../services/resource_fetcher_service.dart';
import 'base_skill_command.dart';

/// Command to validate skills by re-generating and comparing with existing skills.
class ValidateSkillCommand extends BaseSkillCommand {
  /// Creates a new [ValidateSkillCommand].
  ValidateSkillCommand({
    required super.httpClient,
    super.outputDir,
    super.environment,
    this.validationDir,
  }) : super(logger: Logger('ValidateSkillCommand'));

  /// The directory to output validation reports.
  final Directory? validationDir;

  @override
  String get name => 'validate-skill';

  @override
  String get description =>
      'Validates skills using existing skill files and yaml configuration.';

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
    YamlList yamlList;
    try {
      final decoded = loadYaml(yamlContent);
      if (decoded is! YamlList) {
        logger.severe('Invalid configuration: Root must be a YAML list.');
        return;
      }
      yamlList = decoded;
    } on Object catch (e) {
      logger.severe('Invalid YAML syntax in $inputFile: $e');
      return;
    }

    final isValid = _validateYamlStructure(yamlList, p.basename(file.path));
    if (!isValid) {
      logger.severe('Configuration validation failed.');
      return;
    }

    await super.run();
  }

  bool _validateYamlStructure(YamlList yamlList, String fileName) {
    if (yamlList.isEmpty) {
      logger.severe('Configuration list must not be empty.');
      return false;
    }

    var isValid = true;
    final kabobCase = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

    for (var i = 0; i < yamlList.length; i++) {
      final item = yamlList[i];
      if (item is! Map) {
        logger.severe('Item $i is not a Map.');
        isValid = false;
        continue;
      }

      final rawName = item['name'];
      final name = rawName is String ? rawName : 'Item $i';
      if (rawName == null) {
        logger.severe('Item $i is missing required field "name".');
        isValid = false;
      } else if (rawName is! String) {
        logger.severe('Item $i field "name" must be a string.');
        isValid = false;
      }

      final rawDescription = item['description'];
      if (rawDescription == null) {
        logger.severe('Skill "$name" is missing required field "description".');
        isValid = false;
      } else if (rawDescription is! String) {
        logger.severe('Skill "$name" field "description" must be a string.');
        isValid = false;
      }

      if (item['resources'] == null) {
        logger.severe('Skill "$name" is missing required field "resources".');
        isValid = false;
      }

      if (item['instructions'] != null && item['instructions'] is! String) {
        logger.severe('Skill "$name" field "instructions" must be a string.');
        isValid = false;
      }

      if (rawName is String) {
        if (!kabobCase.hasMatch(name)) {
          logger.severe(
            'Skill name "$name" must be kabob-case (e.g. abc-def).',
          );
          isValid = false;
        }

        if (fileName == 'flutter_skills.yaml') {
          if (!name.startsWith('flutter-')) {
            logger.severe(
              'Skill name "$name" in flutter_skills.yaml must start with "flutter-".',
            );
            isValid = false;
          }
        } else if (fileName == 'dart_skills.yaml') {
          if (!name.startsWith('dart-')) {
            logger.severe(
              'Skill name "$name" in dart_skills.yaml must start with "dart-".',
            );
            isValid = false;
          }
        }
      }

      final resources = item['resources'];
      if (resources != null) {
        if (resources is! List) {
          logger.severe('Skill "$name" field "resources" must be a list.');
          isValid = false;
        } else if (resources.isEmpty) {
          logger.severe('Skill "$name" field "resources" must not be empty.');
          isValid = false;
        } else {
          for (final resource in resources) {
            if (resource is! String) {
              logger.severe('Skill "$name" resource must be a string.');
              isValid = false;
            } else {
              if (resource.contains('://') &&
                  !resource.startsWith('https://')) {
                logger.severe(
                  'Skill "$name" resource URL "$resource" must use secure HTTPS.',
                );
                isValid = false;
              }
            }
          }
        }
      }
    }

    return isValid;
  }

  @override
  Future<void> runSkill(
    SkillParams skill,
    GeminiService gemini,
    Directory outputDir,
    int thinkingBudget, {
    Directory? configDir,
  }) async {
    logger.info('Validating skill: ${skill.name}...');

    try {
      // Re-generate markdown content
      final fetcher = ResourceFetcherService(
        httpClient: httpClient,
        logger: logger,
      );
      final markdown = await fetcher.fetchAndConvertContent(
        skill.resources,
        configDir: configDir,
      );

      if (markdown.isEmpty) {
        logger.warning(
          '  No content fetched for ${skill.name}. Skipping validation.',
        );
        return;
      }

      // Read existing content
      final existingSkillFile = File(
        p.join(outputDir.path, skill.name, 'SKILL.md'),
      );
      if (!existingSkillFile.existsSync()) {
        logger.warning(
          '  Existing skill file not found at ${existingSkillFile.path}',
        );
        return;
      }

      final existingSkillFileContent = existingSkillFile.readAsStringSync();

      // Check for verbatim name
      final namePattern = RegExp(
        'name:\\s*["\']?${RegExp.escape(skill.name)}["\']?',
      );
      if (!namePattern.hasMatch(existingSkillFileContent)) {
        logger.severe(
          '  Validation Failed: Skill name mismatch in ${existingSkillFile.path}. '
          'Expected "name: ${skill.name}" (quotes allowed)',
        );
      }

      // Extract metadata from existing content
      final generationDate =
          RegExp(
            'last_modified: (.*)',
          ).firstMatch(existingSkillFileContent)?.group(1) ??
          'Unknown';
      final modelName =
          RegExp(
            'model: (.*)',
          ).firstMatch(existingSkillFileContent)?.group(1) ??
          'Unknown';

      // Compare
      final dryRun = argResults?['dry-run'] as bool? ?? false;
      if (dryRun) {
        logger
          ..info('  [DRY RUN] Would validate skill: ${skill.name}')
          ..info(
            '  [DRY RUN] existing file size: ${existingSkillFileContent.split(' ').length} tokens -> new fetched content size: ${markdown.split(' ').length} tokens.',
          );
        return;
      }

      logger.info('  Comparing versions...');
      final result = await gemini.validateExistingSkillContent(
        markdown,
        skill.name,
        skill.instructions ?? 'No instructions provided',
        generationDate,
        modelName,
        existingSkillFileContent,
        thinkingBudget: thinkingBudget,
      );

      if (result != null) {
        final valDirBase = validationDir ?? Directory('validation');
        final valDir = Directory(p.join(valDirBase.path, skill.name));
        if (!valDir.existsSync()) {
          valDir.createSync(recursive: true);
        }

        File(p.join(valDir.path, 'validation.md')).writeAsStringSync(result);

        // Extract and log the grade
        final gradeMatch = RegExp(r'Grade:\s*(\d+)').firstMatch(result);
        final grade = gradeMatch?.group(1);

        logger.info(
          '  Validation report written to ${p.join(valDir.path, 'validation.md')} '
          '${grade != null ? '(Grade: $grade)' : ''}',
        );
      } else {
        logger.severe(
          '  Failed to generate validation report for ${skill.name}',
        );
      }
    } on Exception catch (e) {
      logger.severe('  Error validating ${skill.name}: $e');
    }
  }
}
