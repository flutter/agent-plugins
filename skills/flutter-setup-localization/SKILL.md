---
name: flutter-setup-localization
description: Add `flutter_localizations` and `intl` dependencies, enable "generate true" in `pubspec.yaml`, create an `l10n.yaml` configuration file, and add English/Chinese ARB files. Use when initializing localization support for a new Flutter project, especially when Chinese localization is required.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 26 May 2026 00:00:00 GMT
---
# Internationalizing Flutter Applications

## Contents
- [Core Concepts](#core-concepts)
- [Setup Workflow](#setup-workflow)
- [Implementation Workflow](#implementation-workflow)
- [Chinese Localization](#chinese-localization)
- [Advanced Formatting](#advanced-formatting)
- [Examples](#examples)

## Core Concepts
Flutter handles internationalization (i18n) and localization (l10n) via the `flutter_localizations` and `intl` packages. The standard approach uses App Resource Bundle (`.arb`) files to define localized strings, which are then compiled into a generated `AppLocalizations` class for type-safe access within the widget tree.

## Setup Workflow

Copy and track this checklist when initializing internationalization in a Flutter project:

- [ ] **Task Progress**
  - [ ] 1. Add dependencies to `pubspec.yaml`.
  - [ ] 2. Enable the `generate` flag.
  - [ ] 3. Create the `l10n.yaml` configuration file.
  - [ ] 4. Create English and Chinese ARB files.
  - [ ] 5. Configure `MaterialApp` or `CupertinoApp`.

### 1. Add Dependencies
Add the required localization packages to the project. Execute the following commands in the terminal:
```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```

Verify your `pubspec.yaml` includes the following under `dependencies`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
```

### 2. Enable Code Generation
Open `pubspec.yaml` and enable the `generate` flag within the `flutter` section to automate localization tasks:
```yaml
flutter:
  generate: true
```

### 3. Create Configuration File
Create a new file named `l10n.yaml` in the root directory of the Flutter project. Define the input directory, template file, and output file:
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
synthetic-package: true
```

### 4. Create English and Chinese ARB Files
Create the ARB directory and the initial template/localized files:

```text
lib/l10n/app_en.arb
lib/l10n/app_zh.arb
```

Use English as the template locale and Chinese as the first localized locale:

```json
{
  "helloWorld": "Hello World!",
  "@helloWorld": {
    "description": "The conventional newborn programmer greeting"
  }
}
```

```json
{
  "helloWorld": "你好，世界！"
}
```

Use `app_zh_CN.arb` instead of, or in addition to, `app_zh.arb` when the project specifically targets Simplified Chinese for mainland China.

### 5. Configure the App Entry Point
Import the generated localizations and the `flutter_localizations` library in your `main.dart`. Inject the delegates and supported locales into your `MaterialApp` or `CupertinoApp`.

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Adjust path if synthetic-package is false

// ... inside build method
return MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('en'), // English
    Locale('es'), // Spanish
    Locale('zh'), // Chinese
    Locale('zh', 'CN'), // Simplified Chinese, China
  ],
  home: const MyHomePage(),
);
```

## Implementation Workflow

Follow this workflow when adding or modifying localized content.

### 1. Define ARB Files
*   **If creating NEW content:** Add the base string to the template file (`lib/l10n/app_en.arb`). Include a description for context.
*   **If EDITING existing content:** Locate the key in all supported `.arb` files and update the values.

```json
{
  "helloWorld": "Hello World!",
  "@helloWorld": {
    "description": "The conventional newborn programmer greeting"
  }
}
```

Create corresponding files for other locales (e.g., `app_es.arb`):
```json
{
  "helloWorld": "¡Hola Mundo!"
}
```

Create a Chinese localization file when Chinese is required (for example, `lib/l10n/app_zh.arb` or `lib/l10n/app_zh_CN.arb`):
```json
{
  "helloWorld": "你好，世界！"
}
```

### 2. Generate Localization Classes
Run the following command to trigger code generation:
```bash
flutter pub get
```
*Feedback Loop:* Run validator -> review terminal output for ARB syntax errors -> fix missing commas or mismatched placeholders -> re-run `flutter pub get`.

### 3. Consume Localized Strings
Access the localized strings in your widget tree using `AppLocalizations.of(context)`. Ensure the widget calling this is a descendant of `MaterialApp`.

```dart
Text(AppLocalizations.of(context)!.helloWorld)
```

## Chinese Localization

When adding Chinese support, prefer this practical workflow:

- Add `lib/l10n/app_zh.arb` for generic Chinese when the app does not need regional variants.
- Add `lib/l10n/app_zh_CN.arb` for Simplified Chinese in mainland China when regional behavior matters.
- If both files exist, keep `app_zh.arb` as the broad fallback and put region-specific wording in `app_zh_CN.arb`.
- Add `Locale('zh')` and, when needed, `Locale('zh', 'CN')` to `supportedLocales`.
- Keep every non-metadata key from the template ARB file present in the Chinese ARB file.

Example `lib/l10n/app_en.arb`:
```json
{
  "appTitle": "Demo App",
  "@appTitle": {
    "description": "The application title"
  },
  "helloUser": "Hello {userName}",
  "@helloUser": {
    "description": "Greeting shown on the home page",
    "placeholders": {
      "userName": {
        "type": "String",
        "example": "Alex"
      }
    }
  }
}
```

Example `lib/l10n/app_zh.arb`:
```json
{
  "appTitle": "演示应用",
  "helloUser": "你好，{userName}"
}
```

For Chinese text, check the UI after translation. Chinese strings may be shorter than English in some places and longer in others. Avoid hard-coded widths around localized labels unless the surrounding layout already handles overflow.

## Advanced Formatting

Use placeholders for dynamic data, plurals, and conditional selects.

### Placeholders
Define parameters within curly braces and specify their type in the metadata object.
```json
"hello": "Hello {userName}",
"@hello": {
  "description": "A message with a single parameter",
  "placeholders": {
    "userName": {
      "type": "String",
      "example": "Bob"
    }
  }
}
```

### Plurals
Use the `plural` syntax to handle quantity-based string variations. The `other` case is mandatory.
```json
"nWombats": "{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}",
"@nWombats": {
  "description": "A plural message",
  "placeholders": {
    "count": {
      "type": "num",
      "format": "compact"
    }
  }
}
```

Chinese commonly does not change nouns by count. It is still valid to keep a plural message for API consistency:
```json
"messageCount": "{count, plural, =0{没有消息} other{{count} 条消息}}"
```

### Selects
Use the `select` syntax for conditional strings, such as gendered text.
```json
"pronoun": "{gender, select, male{he} female{she} other{they}}",
"@pronoun": {
  "description": "A gendered message",
  "placeholders": {
    "gender": {
      "type": "String"
    }
  }
}
```

## Examples

### Complete `l10n.yaml`
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
synthetic-package: true
use-escaping: true
```

### Complete Widget Implementation
```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class GreetingWidget extends StatelessWidget {
  final String userName;
  final int notificationCount;

  const GreetingWidget({
    super.key, 
    required this.userName, 
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(l10n.hello(userName)),
        Text(l10n.nWombats(notificationCount)),
      ],
    );
  }
}
```
