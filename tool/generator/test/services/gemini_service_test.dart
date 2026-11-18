// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:skills/src/services/gemini_service.dart';
import 'package:test/test.dart';

void main() {
  group('GeminiService', () {
    late GeminiService service;

    setUp(() {
      service = GeminiService(
        apiKey: 'test-api-key',
        httpClient: http.Client(),
      );
    });

    group('cleanContent', () {
      test('returns null for null content', () {
        expect(service.cleanContent(null), isNull);
      });

      test('removes markdown code blocks around content', () {
        const content = '''
```markdown
# Title
Some content
```
''';
        const expected = '''
# Title
Some content
''';
        expect(service.cleanContent(content), expected);
      });

      test('removes markdown code blocks with other languages', () {
        const content = '''
```text
# Title
Some content
```
''';
        const expected = '''
# Title
Some content
''';
        expect(service.cleanContent(content), expected);
      });

      test('ignores trailing markdown code block if no start block', () {
        const content = '''
# Title
Some content
```
''';
        const expected = '''
# Title
Some content
```
''';
        expect(service.cleanContent(content), expected);
      });

      test('strips possible frontmatter at start', () {
        const content = '''
---
key: value
---
# Title
Some content
''';
        const expected = '''
# Title
Some content
''';
        expect(service.cleanContent(content), expected);
      });

      test('strips possible frontmatter after some noise', () {
        const content = '''
Here is the content:
---
key: value
---
# Title
Some content
''';
        const expected = '''
# Title
Some content
''';
        expect(service.cleanContent(content), expected);
      });

      test('preserves internal code blocks', () {
        const content = '''
# Title
Here is some code:
```dart
void main() {}
```
''';
        const expected = '''
# Title
Here is some code:
```dart
void main() {}
```
''';
        expect(service.cleanContent(content), expected);
      });

      test('ensures content ends with newline', () {
        const content = 'Some content';
        const expected = 'Some content\n';
        expect(service.cleanContent(content), expected);
      });

      test('handles complex nested structure', () {
        const content = '''
```markdown
---
key: value
---
# Title
Content with code:
```dart
print('hello');
```
```
''';
        const expected = '''
# Title
Content with code:
```dart
print('hello');
```
''';
        expect(service.cleanContent(content), expected);
      });
      test('removes markdown code blocks with leading whitespace', () {
        const content = '''
  ```markdown
# Title
Some content
```
''';
        const expected = '''
# Title
Some content
''';
        expect(service.cleanContent(content), expected);
      });

      test(
        'removes markdown code blocks with trailing whitespace on fence',
        () {
          const content = '''
```markdown 
# Title
Some content
``` 
''';
          const expected = '''
# Title
Some content
''';
          expect(service.cleanContent(content), expected);
        },
      );

      test('removes markdown code blocks with uppercase language', () {
        const content = '''
```MARKDOWN
# Title
Some content
```
''';
        const expected = '''
# Title
Some content
''';
        expect(service.cleanContent(content), expected);
      });
    });

    group('generateSkillContent front matter', () {
      test('does not wrap metadata values with quotes', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Markdown body'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final serviceWithMock = GeminiService(
          apiKey: 'test-api-key',
          httpClient: mockClient,
          model: 'models/test-model',
        );

        final result = await serviceWithMock.generateSkillContent(
          'Raw Content',
          'test-skill',
          'Test description without quotes',
        );

        expect(result, isNotNull);
        expect(result, contains('name: test-skill'));
        expect(
          result,
          contains('description: Test description without quotes'),
        );
        expect(result, contains('model: models/test-model'));
        // Make sure it doesn't contain double quotes for the fields
        expect(result, isNot(contains('name: "test-skill"')));
        expect(
          result,
          isNot(contains('description: "Test description without quotes"')),
        );
        expect(result, isNot(contains('model: "models/test-model"')));
      });
    });

    group('updateSkillContent front matter', () {
      test('does not wrap metadata values with quotes', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Markdown body'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final serviceWithMock = GeminiService(
          apiKey: 'test-api-key',
          httpClient: mockClient,
          model: 'models/test-model',
        );

        final result = await serviceWithMock.updateSkillContent(
          'Existing Content',
          'Raw Content',
          'test-skill',
          'Test description without quotes',
        );

        expect(result, isNotNull);
        expect(result, contains('name: test-skill'));
        expect(
          result,
          contains('description: Test description without quotes'),
        );
        expect(result, contains('model: models/test-model'));
        // Make sure it doesn't contain double quotes for the fields
        expect(result, isNot(contains('name: "test-skill"')));
        expect(
          result,
          isNot(contains('description: "Test description without quotes"')),
        );
        expect(result, isNot(contains('model: "models/test-model"')));
      });
    });

    group('Gemini 4 request parameters', () {
      test(
        'omits temperature for models starting with models/gemini-4',
        () async {
          late Map<String, dynamic> capturedBody;
          final mockClient = MockClient((request) async {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'Generated content'},
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          });

          final gemini = GeminiService(
            apiKey: 'test-key',
            httpClient: mockClient,
            model: 'models/gemini-4-argon',
          );

          await gemini.generateSkillContent('raw', 'name', 'desc');

          final genConfig =
              capturedBody['generationConfig'] as Map<String, dynamic>;
          expect(genConfig.containsKey('temperature'), isFalse);
        },
      );

      test(
        'omits temperature for models starting with gemini-4 without prefix',
        () async {
          late Map<String, dynamic> capturedBody;
          final mockClient = MockClient((request) async {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'Generated content'},
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          });

          final gemini = GeminiService(
            apiKey: 'test-key',
            httpClient: mockClient,
            model: 'gemini-4-argon',
          );

          await gemini.generateSkillContent('raw', 'name', 'desc');

          final genConfig =
              capturedBody['generationConfig'] as Map<String, dynamic>;
          expect(genConfig.containsKey('temperature'), isFalse);
        },
      );

      test('includes temperature for non-gemini-4 models', () async {
        late Map<String, dynamic> capturedBody;
        final mockClient = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Generated content'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final gemini = GeminiService(
          apiKey: 'test-key',
          httpClient: mockClient,
          model: 'models/gemini-3.1-pro-preview',
        );

        await gemini.generateSkillContent('raw', 'name', 'desc');

        final genConfig =
            capturedBody['generationConfig'] as Map<String, dynamic>;
        expect(genConfig['temperature'], equals(0.2));
      });
    });
  });
}
