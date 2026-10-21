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

/// Command to update skills from a configuration file, preserving existing content.
class UpdateSkillCommand extends BaseSkillCommand {
  /// Creates a new [UpdateSkillCommand].
  UpdateSkillCommand({
    required super.httpClient,
    super.outputDir,
    super.environment,
  }) : super(logger: Logger('UpdateSkillCommand'));

  @override
  String get name => 'update-skill';

  @override
  String get description =>
      'Updates an existing skill by combining its current content with fetched resources and new instructions.';

  @override
  Future<void> runSkill(
    SkillParams skill,
    GeminiService gemini,
    Directory outputDir,
    int thinkingBudget, {
    Directory? configDir,
  }) async {
    logger.info('Updating skill: ${skill.name}...');

    final skillFile = File(p.join(outputDir.path, skill.name, 'SKILL.md'));
    if (!skillFile.existsSync()) {
      logger.severe(
        '  Skill file not found at ${skillFile.path}. Cannot update an non-existent skill.',
      );
      return;
    }

    try {
      final existingContent = skillFile.readAsStringSync();

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
        final origWords = existingContent
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length;
        final origTokens = (origWords * 1.3).round();
        final rawWords = combinedMarkdown
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length;
        final rawTokens = (rawWords * 1.3).round();
        logger
          ..info('  [DRY RUN] Would update skill: ${skill.name}')
          ..info(
            '  [DRY RUN] Original file size: ~$origWords words (~$origTokens tokens) -> Raw content size: ~$rawWords words (~$rawTokens tokens).',
          );
        return;
      }

      final generatedContent = await gemini.updateSkillContent(
        existingContent,
        combinedMarkdown,
        skill.name,
        skill.description,
        instructions: skill.instructions,
        thinkingBudget: thinkingBudget,
      );

      if (generatedContent != null && generatedContent.isNotEmpty) {
        skillFile.writeAsStringSync(generatedContent);
        logger.info(
          '  Updated ${p.join(outputDir.path, skill.name, 'SKILL.md')}',
        );

        final lineCount = const LineSplitter().convert(generatedContent).length;
        if (lineCount > 500) {
          logger.warning(
            '  Warning: Updated SKILL.md has $lineCount lines. '
            'The Agent Skills standard (https://agentskills.io) recommends keeping SKILL.md under 500 lines.',
          );
        }
      } else {
        logger.severe('  Failed to update content for ${skill.name}');
      }
    } on Exception catch (e) {
      logger.severe('  Error processing ${skill.name}: $e');
    }
  }
}
