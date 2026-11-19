// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:retry/retry.dart';
import 'package:yaml/yaml.dart';

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
       _ownsClient = httpClient == null,
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

  static final RegExp _leadingCodeFenceRegExp = RegExp(
    r'^\s*(`{3,})[^\r\n`]*\r?\n',
  );
  static final RegExp _yamlFenceLineRegExp = RegExp(
    r'^---[ \t]*$',
    multiLine: true,
  );
  static final RegExp _markdownPrefixStartRegExp = RegExp(
    r'^(?:[-#>*+_~`]|\d+\.)',
  );
  static final RegExp _leadingBlankLineRegExp = RegExp(
    r'^[ \t]*\r?\n[ \t]*\r?\n',
  );
  static final RegExp _trailingBlankLineRegExp = RegExp(
    r'\r?\n[ \t]*\r?\n[ \t]*$',
  );
  static final RegExp _yamlFrontmatterKeyRegExp = RegExp(
    r'^[a-z][a-zA-Z0-9_-]*$',
  );
  static const Set<String> _knownFrontmatterKeys = {
    'name',
    'description',
    'metadata',
    'license',
    'compatibility',
    'allowed-tools',
  };

  final String _model;
  final bool _ownsClient;
  final http.Client _client;
  final Logger _logger = Logger('GeminiService');

  /// Closes the underlying HTTP client if it was created internally by this
  /// [GeminiService].
  ///
  /// Does not close an external `httpClient` passed into the constructor.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

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
      final cleanedBody = await r.retry(() async {
        final res = await service.generateContent(request);
        final text = _extractVerifiedText(res);
        final cleaned = cleanContent(text);
        if (cleaned == null || cleaned.trim().isEmpty) {
          throw const FormatException('Empty markdown body from Gemini');
        }
        return cleaned;
      }, onRetry: (e) => _logger.warning('Retrying Gemini generation: $e'));

      final frontmatter =
          '''---
name: $skillName
description: $description
metadata:
  model: $_model
  last_modified: $lastModified
---
''';

      return frontmatter + cleanedBody;
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
      final cleanedBody = await r.retry(() async {
        final res = await service.generateContent(request);
        final text = _extractVerifiedText(res);
        final cleaned = cleanContent(text);
        if (cleaned == null || cleaned.trim().isEmpty) {
          throw const FormatException('Empty markdown body from Gemini');
        }
        return cleaned;
      }, onRetry: (e) => _logger.warning('Retrying Gemini generation: $e'));

      final frontmatter =
          '''---
name: $skillName
description: $description
metadata:
  model: $_model
  last_modified: $lastModified
---
''';

      return frontmatter + cleanedBody;
    } on Object catch (e) {
      _logger.severe('Gemini update failed: $e');
      return null;
    }
  }

  /// Validates an existing skill.
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
        return _extractVerifiedText(res);
      }, onRetry: (e) => _logger.warning('Retrying Gemini validation: $e'));

      return response;
    } on Object catch (e) {
      _logger.severe('Gemini validation failed: $e');
      return null;
    }
  }

  String _extractVerifiedText(GenerateContentResponse res) {
    if (res.candidates.isEmpty) {
      throw FormatException(
        'No candidates returned from Gemini '
        '(blockReason: ${res.promptFeedback?.blockReason}).',
      );
    }
    final candidate = res.candidates.first;
    final finishReason = candidate.finishReason;
    if (finishReason != Candidate_FinishReason.stop &&
        finishReason != Candidate_FinishReason.finishReasonUnspecified) {
      throw FormatException(
        'Incomplete Gemini response (finishReason: $finishReason).',
      );
    }
    final text = candidate.content?.parts
        .where((part) => !part.thought)
        .map((part) => part.text)
        .where((text) => text != null)
        .join('\n');

    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Empty response from Gemini');
    }
    return text;
  }

  /// Cleans the generated content by removing outer markdown code fences and
  /// leading YAML frontmatter while preserving horizontal rules (`---`) inside
  /// the markdown body.
  @visibleForTesting
  String? cleanContent(String? content) {
    if (content == null) return null;
    var cleaned = content;
    final startMatch = _leadingCodeFenceRegExp.firstMatch(cleaned);
    if (startMatch != null) {
      final fence = startMatch.group(1)!;
      cleaned = cleaned.substring(startMatch.end);
      final trailingFenceRegExp = RegExp(
        '(?:^|\\r?\\n)[ \\t]*${RegExp.escape(fence)}\\s*\$',
      );
      cleaned = cleaned.replaceFirst(trailingFenceRegExp, '');
    }

    cleaned = _stripLeadingFrontmatter(cleaned);

    // Ensure one trailing newline
    return '${cleaned.trim()}\n';
  }

  String _stripLeadingFrontmatter(String input) {
    final firstFence = _yamlFenceLineRegExp.firstMatch(input);
    if (firstFence == null) {
      return input;
    }

    final prefix = input.substring(0, firstFence.start).trim();
    // Allow frontmatter only at the start of the response or immediately after
    // a single-line conversational lead-in ending with ':' (e.g. "Here is the
    // content:"). Reject multi-line prefixes and Markdown block starters
    // (headings, blockquotes, lists, emphasis, or code fences).
    if (prefix.isNotEmpty &&
        (prefix.contains('\n') ||
            prefix.contains('\r') ||
            !prefix.endsWith(':') ||
            _markdownPrefixStartRegExp.hasMatch(prefix))) {
      return input;
    }

    final remainder = input.substring(firstFence.end);
    final secondFence = _yamlFenceLineRegExp.firstMatch(remainder);
    if (secondFence == null) {
      return input;
    }

    final rawCandidate = remainder.substring(0, secondFence.start);
    // YAML frontmatter never starts with a blank line after `---`, whereas
    // Markdown horizontal rules (`---`) and Setext H2 sections do.
    if (_leadingBlankLineRegExp.hasMatch(rawCandidate)) {
      return input;
    }

    final hasTrailingBlankLine = _trailingBlankLineRegExp.hasMatch(
      rawCandidate,
    );
    if (hasTrailingBlankLine && prefix.isNotEmpty) {
      return input;
    }

    final bodyAfterFence = remainder.substring(secondFence.end).trim();
    final candidateYaml = rawCandidate.trim();
    if (candidateYaml.isEmpty) {
      return prefix.isEmpty ? bodyAfterFence : input;
    }

    if (!_isValidFrontmatterBlock(
      candidateYaml,
      allowNullDocument: prefix.isEmpty && bodyAfterFence.isNotEmpty,
      requireKnownKey: prefix.isNotEmpty || hasTrailingBlankLine,
    )) {
      return input;
    }

    return bodyAfterFence;
  }

  bool _isValidFrontmatterBlock(
    String candidateYaml, {
    required bool allowNullDocument,
    required bool requireKnownKey,
  }) {
    try {
      final parsed = loadYaml(candidateYaml);
      if (parsed == null) {
        return allowNullDocument;
      }
      if (parsed is! YamlMap || parsed.isEmpty) {
        return false;
      }
      final hasValidKeys = parsed.keys.every(
        (key) => key is String && _yamlFrontmatterKeyRegExp.hasMatch(key),
      );
      if (!hasValidKeys) {
        return false;
      }
      if (requireKnownKey) {
        return parsed.keys.any(_knownFrontmatterKeys.contains);
      }
      return true;
    } on YamlException {
      return false;
    }
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

  @override
  void close() {
    _inner.close();
  }
}
