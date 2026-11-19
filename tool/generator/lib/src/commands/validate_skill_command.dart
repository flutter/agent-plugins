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
import '../utils/text_metrics.dart';
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

  static final RegExp _kebabCaseRegExp = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
  static final RegExp _lastModifiedRegExp = RegExp('last_modified: (.*)');
  static final RegExp _modelRegExp = RegExp('model: (.*)');
  static final RegExp _gradeRegExp = RegExp(r'Grade:\s*(\d+)');

  /// The directory to output validation reports.
  final Directory? validationDir;

  @override
  String get name => 'validate-skill';

  @override
  String get description =>
      'Validates skills using existing skill files and YAML configuration.';

  @override
  bool validateYamlList(YamlList yamlList, String fileName) {
    if (yamlList.isEmpty) {
      logger.severe('Configuration list must not be empty.');
      return false;
    }

    var isValid = true;
    final seenNames = <String>{};

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
      } else if (rawDescription.length > maxSkillDescriptionLength) {
        logger.warning(
          'Skill "$name" description exceeds $maxSkillDescriptionLength characters (${rawDescription.length} chars). '
          'The Agent Skills standard (https://agentskills.io) limits descriptions to $maxSkillDescriptionLength characters.',
        );
      }

      if (item['resources'] == null) {
        logger.severe('Skill "$name" is missing required field "resources".');
        isValid = false;
      }

      if (item['instructions'] != null && item['instructions'] is! String) {
        logger.severe('Skill "$name" field "instructions" must be a string.');
        isValid = false;
      }

      if (item['examplePrompt'] != null && item['examplePrompt'] is! String) {
        logger.severe('Skill "$name" field "examplePrompt" must be a string.');
        isValid = false;
      }

      if (rawName is String) {
        if (!seenNames.add(name)) {
          logger.severe('Duplicate skill name "$name" in $fileName.');
          isValid = false;
        }

        if (!_kebabCaseRegExp.hasMatch(name)) {
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
    int? thinkingBudget, {
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

      // Check file length per agentskills.io recommendation (< 500 lines)
      warnIfExceedsLineLimit(
        existingSkillFileContent,
        prefix: 'Validation Warning: ${existingSkillFile.path}',
      );

      // Extract metadata from existing content
      final generationDate =
          _lastModifiedRegExp.firstMatch(existingSkillFileContent)?.group(1) ??
          'Unknown';
      final modelName =
          _modelRegExp.firstMatch(existingSkillFileContent)?.group(1) ??
          'Unknown';

      // Compare
      final dryRun = argResults?['dry-run'] as bool? ?? false;
      if (dryRun) {
        final existWords = existingSkillFileContent.wordCount;
        final existTokens = existingSkillFileContent.approximateTokenCount;
        final rawWords = markdown.wordCount;
        final rawTokens = markdown.approximateTokenCount;
        logger
          ..info('  [DRY RUN] Would validate skill: ${skill.name}')
          ..info(
            '  [DRY RUN] Existing file size: ~$existWords words (~$existTokens tokens) -> Fetched content size: ~$rawWords words (~$rawTokens tokens).',
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
        final gradeMatch = _gradeRegExp.firstMatch(result);
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
