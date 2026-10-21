// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../models/skill_params.dart';
import '../services/gemini_service.dart';
import '../services/resource_fetcher_service.dart';
import 'base_skill_command.dart';

/// Command to generate skills from a configuration file.
class GenerateSkillCommand extends BaseSkillCommand {
  /// Creates a new [GenerateSkillCommand].
  GenerateSkillCommand({
    required super.httpClient,
    super.outputDir,
    super.environment,
  }) : super(logger: Logger('GenerateSkillCommand'));

  @override
  String get name => 'generate-skill';

  @override
  String get description => 'Generates skills from using yaml configuration.';

  @override
  Future<void> runSkill(
    SkillParams skill,
    GeminiService gemini,
    Directory outputDir,
    int thinkingBudget, {
    Directory? configDir,
  }) async {
    logger.info('Generating skill: ${skill.name}...');

    try {
      final fetcher = ResourceFetcherService(
        httpClient: httpClient,
        logger: logger,
      );
      final combinedMarkdown = await fetcher.fetchAndConvertContent(
        skill.resources,
        configDir: configDir,
      );

      if (combinedMarkdown.isEmpty) {
        logger.warning('  No content fetched for ${skill.name}. Skipping.');
        return;
      }

      final dryRun = argResults?['dry-run'] as bool? ?? false;
      if (dryRun) {
        final words = combinedMarkdown
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length;
        final approxTokens = (words * 1.3).round();
        logger
          ..info('  [DRY RUN] Would generate skill: ${skill.name}')
          ..info(
            '  [DRY RUN] Prompt size: ~$words words (approx. $approxTokens tokens).',
          );
        return;
      }

      final generatedContent = await gemini.generateSkillContent(
        combinedMarkdown,
        skill.name,
        skill.description,
        instructions: skill.instructions,
        thinkingBudget: thinkingBudget,
      );

      if (generatedContent != null && generatedContent.isNotEmpty) {
        final skillDir = Directory(p.join(outputDir.path, skill.name));
        if (!skillDir.existsSync()) {
          skillDir.createSync(recursive: true);
        }

        File(
          p.join(skillDir.path, 'SKILL.md'),
        ).writeAsStringSync(generatedContent);
        logger.info(
          '  Generated ${p.join(outputDir.path, skill.name, 'SKILL.md')}',
        );

        final lineCount = const LineSplitter().convert(generatedContent).length;
        if (lineCount > 500) {
          logger.warning(
            '  Warning: Generated SKILL.md has $lineCount lines. '
            'The Agent Skills standard (https://agentskills.io) recommends keeping SKILL.md under 500 lines.',
          );
        }
      } else {
        logger.severe('  Failed to generate content for ${skill.name}');
      }
    } on Exception catch (e) {
      logger.severe('  Error processing ${skill.name}: $e');
    }
  }
}
