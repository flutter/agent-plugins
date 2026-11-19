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
            'The Gemini model to use for generation '
            '(e.g., ${GeminiService.knownModels.join(', ')}). '
            'Defaults to ${GeminiService.defaultModel}.',
        defaultsTo: GeminiService.defaultModel,
      )
      ..addOption(
        'thinking-level',
        allowed: GeminiService.supportedThinkingLevels,
        help:
            'Reasoning depth for Gemini 3 and Gemini 4 models '
            '(low, medium, high on Carbon/Argon; +xhigh on Neon/Hydrogen; '
            '+minimal on Gemini 3 Flash-Lite). Defaults to the model default.',
      )
      ..addOption(
        'thinking-budget',
        help:
            'Legacy token budget for model thinking (-1 for dynamic, 0 to disable '
            'where supported, or positive token count; legacy default: '
            '${GeminiService.defaultThinkingBudget}).',
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

    if (argResults!.wasParsed('thinking-level') &&
        argResults!.wasParsed('thinking-budget')) {
      usageException(
        'Cannot specify both --thinking-level and --thinking-budget.',
      );
    }

    int? thinkingBudget;
    final rawBudget = argResults?['thinking-budget'] as String?;
    if (rawBudget != null) {
      final parsed = int.tryParse(rawBudget);
      if (parsed == null || parsed < -1) {
        logger.severe('Invalid thinking-budget: $rawBudget. Skipping.');
        return;
      }
      thinkingBudget = parsed;
    }

    final model = argResults?['model'] as String?;
    final thinkingLevel = argResults?['thinking-level'] as String?;
    final GeminiService gemini;
    try {
      gemini = GeminiService(
        apiKey: (apiKey != null && apiKey.trim().isNotEmpty)
            ? apiKey
            : 'dry-run',
        httpClient: httpClient,
        model: model,
        thinkingLevel: thinkingLevel,
      )..validateThinkingBudget(thinkingBudget);
    } on FormatException catch (e) {
      logger.severe('Invalid model or thinking configuration: ${e.message}');
      return;
    }

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
    int? thinkingBudget, {
    Directory? configDir,
  });
}
