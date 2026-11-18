// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/skill_params.dart';
import '../services/gemini_service.dart';
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
    final apiKey = (environment ?? Platform.environment)['GEMINI_API_KEY'];
    if (apiKey == null) {
      logger.severe('GEMINI_API_KEY environment variable not set.');
      return;
    }

    final model = argResults?['model'] as String?;
    final gemini = GeminiService(
      apiKey: apiKey,
      httpClient: httpClient,
      model: model,
    );

    int thinkingBudget;
    try {
      thinkingBudget = int.parse(argResults!['thinking-budget'] as String);
    } on FormatException {
      logger.warning(
        'Invalid thinking-budget: ${argResults!['thinking-budget']}. Skipping.',
      );
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

  /// Executes the command for a specific skill.
  Future<void> runSkill(
    SkillParams skill,
    GeminiService gemini,
    Directory outputDir,
    int thinkingBudget, {
    Directory? configDir,
  });
}
