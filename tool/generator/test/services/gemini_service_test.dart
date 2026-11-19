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
        httpClient: MockClient((_) async => http.Response('', 500)),
      );
      addTearDown(service.close);
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

      test(
        'removes 4-backtick outer fences while preserving nested 3-backtick blocks',
        () {
          const content = '''
````markdown
# Title
```dart
void main() {}
```
````
''';
          const expected = '''
# Title
```dart
void main() {}
```
''';
          expect(service.cleanContent(content), expected);
        },
      );

      test('strips empty outer code fences completely', () {
        expect(service.cleanContent('```markdown\n```'), '\n');
        expect(service.cleanContent('````markdown\n\n````'), '\n');
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

      test('strips possible frontmatter after conversational lead-in', () {
        const content = '''
Here is the content:
---
name: value
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

      test(
        'strips frontmatter with camelCase keys and block scalars ending in blank line',
        () {
          const content = '''
---
name: flutter-layout
examplePrompt: Build a responsive layout
description: |
  Multi-line description.

---
# Flutter Layout
Body content.
''';
          const expected = '''
# Flutter Layout
Body content.
''';
          expect(service.cleanContent(content), expected);
        },
      );

      test(
        'preserves colon-terminated prose followed by non-frontmatter key:',
        () {
          const content = '''
Shortcut mapping:
---
key: Ctrl+Shift+P
command: Reload
---
# Body
''';
          expect(service.cleanContent(content), content);
        },
      );

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

      test(
        'preserves markdown body containing multiple horizontal rules (---)',
        () {
          const content = '''
# Building CLI Apps

Introductory paragraph.

---

## Section 1

Details for section 1.

---

## Section 2

Details for section 2.
''';
          expect(service.cleanContent(content), content);
        },
      );

      test(
        'preserves embedded YAML frontmatter inside code blocks after heading',
        () {
          const content = '''
# Authoring Skills

Example frontmatter:

```yaml
---
name: example-skill
description: Example description
---
```
''';
          expect(service.cleanContent(content), content);
        },
      );

      test(
        'preserves horizontal rules even without top H1 if section has subheadings',
        () {
          const content = '''
Introductory note without H1.

---

## Subheading

Body text.

---

Footer text.
''';
          expect(service.cleanContent(content), content);
        },
      );

      test(
        'preserves callout and numbered section between --- rules before first # heading',
        () {
          const content = '''
> **Note:** Run all commands from the repository root.

---

1. Configure `pubspec.yaml`.
2. Run `dart pub get`.

---

# CLI Usage
Details here.
''';
          expect(service.cleanContent(content), content);
        },
      );

      test('preserves Setext H2 headings underlined with ---', () {
        const content = '''
Overview
---

Note: Run from root.
---

Details.
''';
        expect(service.cleanContent(content), content);
      });

      test(
        'preserves colon-terminated ATX headings and Setext H2 headings before --- rules',
        () {
          const atxHeading = '''
# Prerequisites:

---

Note: Run from root.

---

# Steps
Details.
''';
          expect(service.cleanContent(atxHeading), atxHeading);

          const setextHeading = '''
Prerequisites:
---
Note: Run from root.
---

Details.
''';
          expect(service.cleanContent(setextHeading), setextHeading);
        },
      );

      test('strips YAML frontmatter containing # YAML comments', () {
        const content = '''
---
# Skill metadata
name: flutter-layout
description: Build responsive layouts
---
# Flutter Layout
Body content.
''';
        const expected = '''
# Flutter Layout
Body content.
''';
        expect(service.cleanContent(content), expected);
      });

      test(
        'strips empty and comment-only frontmatter blocks at start of response',
        () {
          const emptyFrontmatter = '''
---
---
# Title
Body content.
''';
          const commentOnlyFrontmatter = '''
---
# Placeholder comment
---
# Title
Body content.
''';
          const expected = '''
# Title
Body content.
''';
          expect(service.cleanContent(emptyFrontmatter), expected);
          expect(service.cleanContent(commentOnlyFrontmatter), expected);
        },
      );

      test('preserves content when --- frontmatter is unclosed', () {
        const content = '''
---
name: flutter-layout
# Flutter Layout
Body content.
''';
        expect(service.cleanContent(content), content);
      });

      test('handles CRLF line endings in code fences and frontmatter', () {
        const content =
            '```markdown\r\n---\r\nname: test\r\n---\r\n# Title\r\nBody\r\n```\r\n';
        expect(service.cleanContent(content), '# Title\r\nBody\n');
      });
    });

    group('response validation and client lifecycle', () {
      test(
        'rejects frontmatter-only, empty-fence, truncated finishReason, and empty candidates',
        () async {
          var callCount = 0;
          final responses = <Map<String, dynamic>>[
            // 1. Frontmatter-only response (empty body after cleaning) -> retry
            {
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {'text': '---\nname: stub\n---'},
                    ],
                  },
                },
              ],
            },
            // 2. Truncated MAX_TOKENS response -> retry
            {
              'candidates': [
                {
                  'finishReason': 'MAX_TOKENS',
                  'content': {
                    'parts': [
                      {'text': '# Partial body cut mid-sent'},
                    ],
                  },
                },
              ],
            },
            // 3. Complete valid response -> succeeds on 3rd attempt
            {
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {'text': '# Valid Skill\nComplete body.'},
                    ],
                  },
                },
              ],
            },
          ];

          final mockClient = MockClient((_) async {
            final payload = responses[callCount++];
            return http.Response(jsonEncode(payload), 200);
          });

          final gemini = GeminiService(
            apiKey: 'test-key',
            httpClient: mockClient,
          );

          final result = await gemini.generateSkillContent(
            'Raw',
            'test-skill',
            'Desc',
          );
          expect(callCount, 3);
          expect(result, contains('# Valid Skill\nComplete body.'));
        },
      );

      test(
        'returns null when candidates list is empty across retries',
        () async {
          final mockClient = MockClient((_) async {
            return http.Response(
              jsonEncode({
                'candidates': <Object>[],
                'promptFeedback': {'blockReason': 'SAFETY'},
              }),
              200,
            );
          });

          final gemini = GeminiService(
            apiKey: 'test-key',
            httpClient: mockClient,
          );
          final result = await gemini.updateSkillContent(
            'Existing',
            'Raw',
            'test-skill',
            'Desc',
          );
          expect(result, isNull);
        },
      );

      test(
        'close() closes internally owned client but preserves injected client',
        () {
          var injectedClosed = false;
          final injectedClient = _TrackingClient(
            onClose: () => injectedClosed = true,
          );

          GeminiService(apiKey: 'k', httpClient: injectedClient).close();
          expect(injectedClosed, isFalse);

          final ownedService = GeminiService(apiKey: 'k');
          expect(ownedService.close, returnsNormally);
        },
      );
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

class _TrackingClient extends http.BaseClient {
  _TrackingClient({required this.onClose});

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() {
    onClose();
  }
}
