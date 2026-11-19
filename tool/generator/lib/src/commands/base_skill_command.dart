// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../models/skill_params.dart';
import '../services/gemini_service.dart';
import '../utils/text_metrics.dart';
import 'base_yaml_command.dart';

/// Base command for skill operations requiring AI generation.
abstract class BaseSkillCommand extends BaseYamlCommand {
  /// Creates a new [BaseSkillCommand].
  BaseSkillCommand({
    required this.httpClient,
    required super.logger,
    super.outputDir,
    this.environment,
  }) {
    argParser
      ..addOption(
        'model',
        help:
            'The Gemini model to use for generation. Defaults to ${GeminiService.defaultModel}.',
        defaultsTo: GeminiService.defaultModel,
      )
      ..addOption(
        'thinking-budget',
        help:
            'The token budget for the model to "think". Defaults to ${GeminiService.defaultThinkingBudget} (recommended for technical documentation).',
        defaultsTo: GeminiService.defaultThinkingBudget.toString(),
      )
      ..addFlag(
        'dry-run',
        abbr: 'n',
        help:
            'Simulate the command without making API calls or modifying files.',
        negatable: false,
      );
  }

  /// The HTTP client used for fetching resources.
  final http.Client httpClient;

  /// Optional override for the environment variables, for testing.
  final Map<String, String>? environment;

  @override
  Future<void> runWithSkills(
    List<SkillParams> skills,
    Directory outputDir, {
    Directory? configDir,
  }) async {
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final apiKey = (environment ?? Platform.environment)['GEMINI_API_KEY'];
    if (!dryRun && (apiKey == null || apiKey.trim().isEmpty)) {
      logger.severe('GEMINI_API_KEY environment variable not set.');
      return;
    }

    final rawBudget = argResults!['thinking-budget'] as String;
    final thinkingBudget = int.tryParse(rawBudget);
    if (thinkingBudget == null || thinkingBudget < 0) {
      logger.severe('Invalid thinking-budget: $rawBudget. Skipping.');
      return;
    }

    final model = argResults?['model'] as String?;
    final gemini = GeminiService(
      apiKey: (apiKey != null && apiKey.trim().isNotEmpty) ? apiKey : 'dry-run',
      httpClient: httpClient,
      model: model,
    );

    for (final skill in skills) {
      await runSkill(
        skill,
        gemini,
        outputDir,
        thinkingBudget,
        configDir: configDir,
      );
    }
  }

  /// Logs a warning when [content] exceeds [maxRecommendedSkillLines] lines per
  /// the Agent Skills standard.
  @protected
  void warnIfExceedsLineLimit(String content, {required String prefix}) {
    final lines = content.lineCount;
    if (lines > maxRecommendedSkillLines) {
      logger.warning(
        '  $prefix has $lines lines. '
        'The Agent Skills standard (https://agentskills.io) recommends keeping '
        'SKILL.md under $maxRecommendedSkillLines lines.',
      );
    }
  }

  /// Executes the command for a specific skill.
  Future<void> runSkill(
    SkillParams skill,
    GeminiService gemini,
    Directory outputDir,
    int thinkingBudget, {
    Directory? configDir,
  });
}
