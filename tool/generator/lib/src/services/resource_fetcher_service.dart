// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'markdown_converter.dart';

/// Fetches and converts content from diverse resources.
class ResourceFetcherService {
  /// Creates a new [ResourceFetcherService].
  ResourceFetcherService({
    required http.Client httpClient,
    required Logger logger,
  }) : _httpClient = httpClient,
       _logger = logger;

  final http.Client _httpClient;
  final Logger _logger;

  /// Fetches and converts content from a list of resources.
  ///
  /// Throws an [Exception] if fetching any resource fails. This strict behavior
  /// prevents wasting tokens on generating low-quality skills when
  /// source material is missing.
  Future<String> fetchAndConvertContent(
    List<String> resources, {
    io.Directory? configDir,
  }) async {
    final converter = MarkdownConverter();
    final sb = StringBuffer();
    for (final resource in resources) {
      _logger.info('  Fetching $resource...');

      if (resource.startsWith('http://')) {
        throw Exception(
          'Insecure HTTP URL found: $resource. '
          'Only HTTPS URLs or relative file paths are allowed.',
        );
      }

      if (resource.startsWith('https://')) {
        final response = await _httpClient.get(Uri.parse(resource));
        if (response.statusCode == 200) {
          sb
            ..writeln('--- Raw content from $resource ---')
            ..writeln(converter.convert(response.body));
        } else {
          throw Exception(
            'Failed to fetch $resource: HTTP ${response.statusCode}. '
            'Failing fast to save Gemini tokens.',
          );
        }
      } else {
        if (configDir == null) {
          throw Exception(
            'Relative resource "$resource" found, but no configuration '
            'directory was provided to resolve it.',
          );
        }
        final file = io.File(p.join(configDir.path, resource));
        if (!file.existsSync()) {
          throw Exception('Local resource file not found: ${file.path}');
        }

        final String content;
        try {
          content = file.readAsStringSync();
        } on io.FileSystemException {
          throw Exception('Local resource file is not readable: ${file.path}');
        }

        sb
          ..writeln('--- Raw content from $resource ---')
          ..writeln(content);
      }
    }
    return sb.toString();
  }
}
