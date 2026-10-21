// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:retry/retry.dart';

import 'prompts.dart';
import 'skill_instructions.dart';

/// Service for interacting with the Gemini API to generate and validate skills.
class GeminiService {
  /// Creates a new [GeminiService].
  GeminiService({
    required String apiKey,
    http.Client? httpClient,
    String? model,
  }) : _model = model ?? defaultModel,
       _client = _ApiKeyClient(httpClient ?? http.Client(), apiKey);

  /// Default temperature for legacy models.
  ///
  /// Note: For Gemini 4 models (such as `gemini-4-argon`), sampling parameters
  /// such as temperature, top_p, and top_k should be omitted, as the model
  /// optimizes its own reasoning path and setting them can degrade performance
  /// or is ignored by the API.
  ///
  /// See: https://ai.google.dev/gemini-api/docs/latest-model#migrate-to-gemini-4-argon
  static const double defaultTemperature = 0.2;

  /// The default model to use for generation.
  ///
  /// Defaults to Gemini 4 Argon (`models/gemini-4-argon`), Google's flagship
  /// model for software engineering, deep reasoning, and autonomous agents,
  /// featuring a 1M unified context window.
  ///
  /// See:
  /// - https://ai.google.dev/gemini-api/docs/models/gemini-4-argon
  /// - https://ai.google.dev/gemini-api/docs/latest-model
  static const String defaultModel = 'models/gemini-4-argon';

  /// The default token budget for thinking.
  ///
  /// Gemini 4 Argon engages in dynamic reasoning by default (using thinking
  /// levels: low, medium, high). When communicating via GenerativeLanguage API,
  /// thinking budget controls reasoning depth.
  ///
  /// See:
  /// - https://ai.google.dev/gemini-api/docs/thinking
  /// - https://ai.google.dev/gemini-api/docs/latest-model#understanding-thinking-levels
  static const int defaultThinkingBudget = 4096;

  /// The default max output tokens for generation.
  ///
  /// For Gemini 4 Argon (and thinking models), thinking tokens and response
  /// tokens share the same output budget and context window. In synchronous
  /// mode, Gemini 4 Argon supports a maximum output limit of 65,536 tokens.
  /// Setting a limit lower than 32K (such as 8192) can cause reasoning to be
  /// truncated.
  ///
  /// See:
  /// - https://ai.google.dev/gemini-api/docs/models/gemini-4-argon
  /// - https://ai.google.dev/gemini-api/docs/latest-model#setting-output-token-limits
  static const int defaultMaxOutputLimit = 65536;

  /// The default safety settings to use for generation.
  static final List<SafetySetting> defaultSafetySettings = [
    SafetySetting(
      category: HarmCategory.harmCategoryDangerousContent,
      threshold: SafetySetting_HarmBlockThreshold.blockOnlyHigh,
    ),
    SafetySetting(
      category: HarmCategory.harmCategoryHateSpeech,
      threshold: SafetySetting_HarmBlockThreshold.blockOnlyHigh,
    ),
    SafetySetting(
      category: HarmCategory.harmCategoryHarassment,
      threshold: SafetySetting_HarmBlockThreshold.blockOnlyHigh,
    ),
    SafetySetting(
      category: HarmCategory.harmCategorySexuallyExplicit,
      threshold: SafetySetting_HarmBlockThreshold.blockOnlyHigh,
    ),
  ];

  final String _model;
  final http.Client _client;
  final Logger _logger = Logger('GeminiService');

  /// Generates the content for a skill based on raw markdown input.
  Future<String?> generateSkillContent(
    String rawMarkdown,
    String skillName,
    String description, {
    String? instructions,
    int thinkingBudget = defaultThinkingBudget,
  }) async {
    final service = GenerativeService(client: _client);
    final lastModified = io.HttpDate.format(DateTime.now());
    final prompt = Prompts.createSkillPrompt(rawMarkdown, instructions);

    final request = _createRequest(
      prompt,
      systemInstruction: skillInstructions,
      thinkingBudget: thinkingBudget,
    );

    _logger.info(
      '  Model: $_model, Max Output Tokens: $defaultMaxOutputLimit, Thinking Budget: $thinkingBudget',
    );

    try {
      const r = RetryOptions(maxAttempts: 3);
      final response = await r.retry(() async {
        final res = await service.generateContent(request);
        final text = res.candidates.first.content?.parts
            .where((part) => !part.thought)
            .map((part) => part.text)
            .where((text) => text != null)
            .join('\n');

        if (text == null || text.isEmpty) {
          throw const FormatException('Empty response from Gemini');
        }

        return text;
      }, onRetry: (e) => _logger.warning('Retrying Gemini generation: $e'));

      final content = response;

      final frontmatter =
          '''---
name: $skillName
description: $description
metadata:
  model: $_model
  last_modified: $lastModified
---
''';

      return frontmatter + (cleanContent(content) ?? '');
    } on Object catch (e) {
      _logger.severe('Gemini generation failed: $e');
      return null;
    }
  }

  /// Updates the content for a skill based on raw markdown input and existing content.
  Future<String?> updateSkillContent(
    String existingContent,
    String rawMarkdown,
    String skillName,
    String description, {
    String? instructions,
    int thinkingBudget = defaultThinkingBudget,
  }) async {
    final service = GenerativeService(client: _client);
    final lastModified = io.HttpDate.format(DateTime.now());
    final prompt = Prompts.updateSkillPrompt(
      existingContent,
      rawMarkdown,
      instructions,
    );

    final request = _createRequest(
      prompt,
      systemInstruction: skillInstructions,
      thinkingBudget: thinkingBudget,
    );

    _logger.info(
      '  Model: $_model, Max Output Tokens: $defaultMaxOutputLimit, Thinking Budget: $thinkingBudget',
    );

    try {
      const r = RetryOptions(maxAttempts: 3);
      final response = await r.retry(() async {
        final res = await service.generateContent(request);
        final text = res.candidates.first.content?.parts
            .where((part) => !part.thought)
            .map((part) => part.text)
            .where((text) => text != null)
            .join('\n');

        if (text == null || text.isEmpty) {
          throw const FormatException('Empty response from Gemini');
        }

        return text;
      }, onRetry: (e) => _logger.warning('Retrying Gemini generation: $e'));

      final content = response;

      final frontmatter =
          '''---
name: $skillName
description: $description
metadata:
  model: $_model
  last_modified: $lastModified
---
''';

      return frontmatter + (cleanContent(content) ?? '');
    } on Object catch (e) {
      _logger.severe('Gemini update failed: $e');
      return null;
    }
  }

  /// Validates an existing skill
  Future<String?> validateExistingSkillContent(
    String markdown,
    String skillName,
    String instructions,
    String generationDate,
    String modelName,
    String currentSkillContent, {
    int thinkingBudget = defaultThinkingBudget,
  }) async {
    final service = GenerativeService(client: _client);
    final validationPrompt = Prompts.validateExistingSkillContentPrompt(
      markdown,
      instructions,
      generationDate,
      modelName,
      currentSkillContent,
    );

    final request = _createRequest(
      validationPrompt,
      systemInstruction: skillInstructions,
      thinkingBudget: thinkingBudget,
    );

    _logger.info(
      '  Model: $_model, Max Output Tokens: $defaultMaxOutputLimit, Thinking Budget: $thinkingBudget',
    );

    try {
      const r = RetryOptions(maxAttempts: 3);
      final response = await r.retry(() async {
        final res = await service.generateContent(request);
        final text = res.candidates.first.content?.parts
            .where((part) => !part.thought)
            .map((part) => part.text)
            .where((text) => text != null)
            .join('\n');

        if (text == null || text.isEmpty) {
          throw const FormatException('Empty response from Gemini');
        }

        return text;
      }, onRetry: (e) => _logger.warning('Retrying Gemini validation: $e'));

      return response;
    } on Object catch (e) {
      _logger.severe('Gemini validation failed: $e');
      return null;
    }
  }

  /// Cleans the generated content by removing markdown code blocks and frontmatter.
  @visibleForTesting
  String? cleanContent(String? content) {
    if (content == null) return null;
    var cleaned = content;
    final startMatch = RegExp(
      r'^\s*```[a-zA-Z]*\s*\n',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (startMatch != null) {
      cleaned = cleaned.substring(startMatch.end);
      // Remove the last triple backticks if they exist
      cleaned = cleaned.replaceAll(RegExp(r'\n```\s*$'), '');
    }

    final yamlStartIndex = cleaned.indexOf('---');
    if (yamlStartIndex == 0) {
      // Possible frontmatter, skip it
      final end = cleaned.indexOf('---', 3);
      if (end != -1) {
        cleaned = cleaned.substring(end + 3).trim();
      }
    } else if (yamlStartIndex > 0) {
      // Maybe noise before frontmatter, try to strip it if it looks like frontmatter
      final end = cleaned.indexOf('---', yamlStartIndex + 3);
      if (end != -1) {
        cleaned = cleaned.substring(end + 3).trim();
      }
    }

    // Ensure one trailing newline
    return '${cleaned.trim()}\n';
  }

  GenerateContentRequest _createRequest(
    String prompt, {
    String? systemInstruction,
    int thinkingBudget = defaultThinkingBudget,
  }) {
    // For Gemini 4 thinking models, sampling parameters (temperature, top_p,
    // top_k) should be omitted per Google best practices.
    final isGemini4 =
        _model.startsWith('models/gemini-4') || _model.startsWith('gemini-4');

    return GenerateContentRequest(
      model: _model,
      systemInstruction: systemInstruction != null
          ? Content(parts: [Part(text: systemInstruction)])
          : null,
      contents: [
        Content(parts: [Part(text: prompt)]),
      ],
      // See [GenerationConfig] in package:google_cloud_ai_generativelanguage_v1beta
      generationConfig: GenerationConfig(
        temperature: isGemini4 ? null : defaultTemperature,
        maxOutputTokens: defaultMaxOutputLimit,
        thinkingConfig: thinkingBudget > 0
            ? ThinkingConfig(
                includeThoughts: true,
                thinkingBudget: thinkingBudget,
              )
            : null,
      ),
      safetySettings: defaultSafetySettings,
    );
  }
}

class _ApiKeyClient extends http.BaseClient {
  _ApiKeyClient(this._inner, this._apiKey);

  final http.Client _inner;
  final String _apiKey;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['x-goog-api-key'] = _apiKey;
    return _inner.send(request);
  }
}
