// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
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
  ///
  /// Throws a [FormatException] if [model] is empty or if [thinkingLevel] is
  /// invalid or incompatible with [model].
  factory GeminiService({
    required String apiKey,
    http.Client? httpClient,
    String? model,
    String? thinkingLevel,
  }) {
    final normalizedModel = normalizeModelName(model ?? defaultModel);
    final normalizedLevel = _resolveThinkingLevel(
      model: normalizedModel,
      thinkingLevel: thinkingLevel,
    );
    return GeminiService._(
      model: normalizedModel,
      thinkingLevel: normalizedLevel,
      ownsClient: httpClient == null,
      client: _ApiKeyClient(
        httpClient ?? http.Client(),
        apiKey,
        thinkingLevel: normalizedLevel?.toUpperCase(),
      ),
    );
  }

  GeminiService._({
    required String model,
    required String? thinkingLevel,
    required bool ownsClient,
    required http.Client client,
  }) : _model = model,
       _thinkingLevel = thinkingLevel,
       _ownsClient = ownsClient,
       _client = client;

  /// Gemini 4 Carbon (`models/gemini-4-carbon`): strongest frontier reasoning
  /// model built for complex software engineering, verification, and
  /// source-grounded synthesis.
  static const String gemini4CarbonModel = 'models/gemini-4-carbon';

  /// Gemini 4 Neon (`models/gemini-4-neon`): balanced Gemini 4 frontier model
  /// sitting between Carbon and Hydrogen with faster end-to-end completion than
  /// Carbon and deeper reasoning than Hydrogen.
  static const String gemini4NeonModel = 'models/gemini-4-neon';

  /// Gemini 4 Argon (`models/gemini-4-argon`): predecessor Gemini 4 reasoning
  /// model supporting `low`, `medium`, and `high` thinking levels.
  static const String gemini4ArgonModel = 'models/gemini-4-argon';

  /// Gemini 4 Hydrogen (`models/gemini-4-hydrogen`): fast, cost-efficient
  /// general-purpose Gemini 4 model (also available on the free tier).
  static const String gemini4HydrogenModel = 'models/gemini-4-hydrogen';

  /// Known Gemini model identifiers supported out of the box.
  static const List<String> knownModels = [
    gemini4CarbonModel,
    gemini4NeonModel,
    gemini4ArgonModel,
    gemini4HydrogenModel,
  ];

  /// Default temperature for legacy Gemini 1.x / 2.x models.
  ///
  /// Note: For Gemini 3 and Gemini 4 models, sampling parameters such as
  /// `temperature`, `top_p`, and `top_k` should be omitted, as these models
  /// optimize their own reasoning paths and custom sampling parameters are
  /// ignored or rejected by the API.
  ///
  /// See: https://ai.google.dev/gemini-api/docs/whats-new-gemini-4-carbon#migrate-to-gemini-4-carbon
  static const double defaultTemperature = 0.2;

  /// The default model to use for generation.
  ///
  /// Defaults to [gemini4CarbonModel] (`models/gemini-4-carbon`), Google's
  /// strongest frontier reasoning model for software engineering and dense
  /// technical synthesis, featuring a 1M unified context window.
  ///
  /// See:
  /// - https://ai.google.dev/gemini-api/docs/models/gemini-4-carbon
  /// - https://ai.google.dev/gemini-api/docs/choosing-a-model
  static const String defaultModel = gemini4CarbonModel;

  /// The default token budget for thinking on Gemini 2.5 models that use
  /// `thinkingBudget` instead of `thinkingLevel`.
  ///
  /// Gemini 3 and Gemini 4 models engage in dynamic reasoning by default
  /// (`medium` on Carbon/Argon, `high` on Neon/Hydrogen) controlled via
  /// `thinkingLevel` (`minimal`, `low`, `medium`, `high`, `xhigh`).
  ///
  /// See: https://ai.google.dev/gemini-api/docs/thinking
  static const int defaultThinkingBudget = 4096;

  /// Allowed `thinking_level` values across Gemini 3 and Gemini 4 models.
  static const List<String> supportedThinkingLevels = [
    'minimal',
    'low',
    'medium',
    'high',
    'xhigh',
  ];

  /// The default max output tokens for generation.
  ///
  /// For Gemini 4 models (and thinking models), thinking tokens and response
  /// tokens share the same output budget and 1M unified context window.
  /// Synchronous interactions default to a 65,536-token limit (note that direct
  /// non-streaming REST hops on Carbon and Argon return up to 32,768 tokens per
  /// hop without continuation).
  ///
  /// See:
  /// - https://ai.google.dev/gemini-api/docs/thinking#token-limits
  /// - https://ai.google.dev/gemini-api/docs/long-decode
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

  /// Normalizes a Gemini [model] identifier so it includes the `'models/'`
  /// (or `'tunedModels/'`) resource prefix required by the Generative Language
  /// REST endpoint (`/v1beta/{model}:generateContent`).
  ///
  /// Throws a [FormatException] if the model slug is empty.
  static String normalizeModelName(String model) {
    final trimmed = model.trim();
    final String prefix;
    final String slug;
    if (trimmed.startsWith('models/')) {
      prefix = 'models/';
      slug = trimmed.substring('models/'.length).trim();
    } else if (trimmed.startsWith('tunedModels/')) {
      prefix = 'tunedModels/';
      slug = trimmed.substring('tunedModels/'.length).trim();
    } else {
      prefix = 'models/';
      slug = trimmed;
    }

    if (slug.isEmpty) {
      throw FormatException('Model identifier must not be empty: "$model"');
    }
    return '$prefix$slug';
  }

  static String? _resolveThinkingLevel({
    required String model,
    required String? thinkingLevel,
  }) {
    if (thinkingLevel == null) return null;
    final normalized = thinkingLevel.trim().toLowerCase();
    if (normalized.isEmpty || !supportedThinkingLevels.contains(normalized)) {
      throw FormatException(
        'Unsupported thinking level "$thinkingLevel". Allowed values: '
        '${supportedThinkingLevels.join(', ')}.',
      );
    }
    if (model.startsWith('tunedModels/')) {
      throw FormatException(
        'Thinking level "$normalized" is not supported by tuned model $model.',
      );
    }
    if (model.startsWith('models/gemini-1') ||
        model.startsWith('models/gemini-2')) {
      throw FormatException(
        'Thinking level "$normalized" is not supported by $model; '
        'use --thinking-budget instead.',
      );
    }
    if (normalized == 'minimal' &&
        (model.startsWith('models/gemini-4') ||
            model.startsWith('models/gemini-3.8-flash') ||
            model.startsWith('models/gemini-3.1-pro') ||
            model.startsWith('models/gemini-3-pro'))) {
      throw FormatException(
        'Thinking level "minimal" is not supported by $model.',
      );
    }
    if (normalized == 'medium' && model.startsWith('models/gemini-3-pro')) {
      throw FormatException(
        'Thinking level "medium" is not supported by $model.',
      );
    }
    if (normalized == 'xhigh' &&
        (model.startsWith(gemini4CarbonModel) ||
            model.startsWith(gemini4ArgonModel) ||
            model.startsWith('models/gemini-3'))) {
      throw FormatException(
        'Thinking level "xhigh" is not supported by $model.',
      );
    }
    return normalized;
  }

  final String _model;
  final String? _thinkingLevel;
  final bool _ownsClient;
  final http.Client _client;
  final Logger _logger = Logger('GeminiService');

  bool get _isModernThinkingModel =>
      _model.startsWith('models/gemini-4') ||
      _model.startsWith('models/gemini-3');

  bool get _isTunedModel => _model.startsWith('tunedModels/');

  bool get _supportsThinkingBudget =>
      !_isTunedModel &&
      !_model.startsWith('models/gemini-1') &&
      !_model.startsWith('models/gemini-2.0');

  /// Validates that [thinkingBudget] is compatible with this service's model.
  ///
  /// Throws a [FormatException] if [thinkingBudget] is less than `-1`, if a
  /// non-zero budget is passed for a non-thinking model, or if `0` is passed
  /// for a model where thinking cannot be disabled.
  void validateThinkingBudget(int? thinkingBudget) {
    if (thinkingBudget == null) return;
    if (thinkingBudget < -1) {
      throw FormatException(
        'thinkingBudget must be >= -1 (got $thinkingBudget).',
      );
    }
    if (!_supportsThinkingBudget && thinkingBudget != 0) {
      throw FormatException(
        'Thinking budget $thinkingBudget is not supported by $_model '
        '(only 0 to omit thinkingConfig is allowed).',
      );
    }
    if (thinkingBudget == 0 &&
        (_model.startsWith('models/gemini-4') ||
            _model.startsWith('models/gemini-2.5-pro'))) {
      throw FormatException(
        'Thinking cannot be disabled (thinkingBudget: 0) on $_model.',
      );
    }
  }

  /// Closes the underlying HTTP client if it was created internally by this
  /// [GeminiService].
  ///
  /// Does not close an external `httpClient` passed into the constructor.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  String _formatThinkingSummary(int? thinkingBudget) {
    if (_thinkingLevel != null) {
      return 'Thinking Level: $_thinkingLevel';
    }
    if (thinkingBudget != null) {
      return !_supportsThinkingBudget
          ? 'Thinking: none'
          : 'Thinking Budget: $thinkingBudget';
    }
    if (_isModernThinkingModel) {
      return 'Thinking Level: default';
    }
    if (!_supportsThinkingBudget) {
      return 'Thinking: none';
    }
    return 'Thinking Budget: $defaultThinkingBudget';
  }

  /// Generates the content for a skill based on raw markdown input.
  Future<String?> generateSkillContent(
    String rawMarkdown,
    String skillName,
    String description, {
    String? instructions,
    int? thinkingBudget,
  }) async {
    final request = _createRequest(
      Prompts.createSkillPrompt(rawMarkdown, instructions),
      systemInstruction: skillInstructions,
      thinkingBudget: thinkingBudget,
    );
    final service = GenerativeService(client: _client);
    final lastModified = io.HttpDate.format(DateTime.now());

    _logger.info(
      '  Model: $_model, Max Output Tokens: $defaultMaxOutputLimit, ${_formatThinkingSummary(thinkingBudget)}',
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
    int? thinkingBudget,
  }) async {
    final request = _createRequest(
      Prompts.updateSkillPrompt(existingContent, rawMarkdown, instructions),
      systemInstruction: skillInstructions,
      thinkingBudget: thinkingBudget,
    );
    final service = GenerativeService(client: _client);
    final lastModified = io.HttpDate.format(DateTime.now());

    _logger.info(
      '  Model: $_model, Max Output Tokens: $defaultMaxOutputLimit, ${_formatThinkingSummary(thinkingBudget)}',
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
    int? thinkingBudget,
  }) async {
    final request = _createRequest(
      Prompts.validateExistingSkillContentPrompt(
        markdown,
        instructions,
        generationDate,
        modelName,
        currentSkillContent,
      ),
      systemInstruction: skillInstructions,
      thinkingBudget: thinkingBudget,
    );
    final service = GenerativeService(client: _client);

    _logger.info(
      '  Model: $_model, Max Output Tokens: $defaultMaxOutputLimit, ${_formatThinkingSummary(thinkingBudget)}',
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
    int? thinkingBudget,
  }) {
    validateThinkingBudget(thinkingBudget);

    final ThinkingConfig? resolvedThinkingConfig;
    if (_thinkingLevel != null) {
      resolvedThinkingConfig = ThinkingConfig(includeThoughts: true);
    } else if (thinkingBudget != null) {
      if (!_supportsThinkingBudget) {
        resolvedThinkingConfig = null;
      } else if (thinkingBudget > 0 || thinkingBudget == -1) {
        resolvedThinkingConfig = ThinkingConfig(
          includeThoughts: true,
          thinkingBudget: thinkingBudget,
        );
      } else {
        resolvedThinkingConfig = ThinkingConfig(
          includeThoughts: false,
          thinkingBudget: 0,
        );
      }
    } else if (_isModernThinkingModel) {
      resolvedThinkingConfig = ThinkingConfig(includeThoughts: true);
    } else if (!_supportsThinkingBudget) {
      resolvedThinkingConfig = null;
    } else {
      resolvedThinkingConfig = ThinkingConfig(
        includeThoughts: true,
        thinkingBudget: defaultThinkingBudget,
      );
    }

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
        temperature: _isModernThinkingModel ? null : defaultTemperature,
        maxOutputTokens: defaultMaxOutputLimit,
        thinkingConfig: resolvedThinkingConfig,
      ),
      safetySettings: defaultSafetySettings,
    );
  }
}

class _ApiKeyClient extends http.BaseClient {
  _ApiKeyClient(this._inner, this._apiKey, {this.thinkingLevel});

  final http.Client _inner;
  final String _apiKey;
  final String? thinkingLevel;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['x-goog-api-key'] = _apiKey;
    final path = request.url.path;
    final isGenerateEndpoint =
        path.endsWith(':generateContent') ||
        path.endsWith(':streamGenerateContent');
    if (thinkingLevel != null &&
        isGenerateEndpoint &&
        request is http.Request &&
        request.body.isNotEmpty) {
      final decoded = jsonDecode(request.body);
      if (decoded is Map<String, dynamic>) {
        final genConfig =
            (decoded['generationConfig'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
        final thinkingConfig =
            ((genConfig['thinkingConfig'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})
              ..remove('thinkingBudget')
              ..['thinkingLevel'] = thinkingLevel;
        genConfig['thinkingConfig'] = thinkingConfig;
        decoded['generationConfig'] = genConfig;
        request.body = jsonEncode(decoded);
      }
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
