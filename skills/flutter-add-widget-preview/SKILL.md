---
name: flutter-add-widget-preview
description: Adds interactive widget previews to the project using the previews.dart system. Use when creating new UI components or updating existing screens to ensure consistent design and interactive testing.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 20:05:23 GMT
---
# Previewing Flutter Widgets

## Contents
- [Preview Guidelines](#preview-guidelines)
- [Preview Parameters](#preview-parameters)
- [Handling Limitations](#handling-limitations)
- [Workflows](#workflows)
- [Examples](#examples)

## Preview Guidelines

Use the Flutter Widget Previewer to render widgets in real-time, isolated from the full application context.

- **Target Elements:** Apply the `@Preview` annotation to top-level functions, static methods within a class, or public widget constructors/factories that have no required arguments and return a `Widget` or `WidgetBuilder`.
- **Imports:** Always import `package:flutter/widget_previews.dart` to access the preview annotations.
- **Custom Annotations:** Extend the `Preview` class to create custom annotations that inject common properties (e.g., custom themes, wrappers, sizes) across multiple widgets.
- **Multiple Configurations:** Apply multiple `@Preview` annotations to a single target to generate multiple preview instances. Alternatively, extend `MultiPreview` to encapsulate common multi-preview configurations.
- **Runtime Transformations:** Override the `transform()` method in custom `Preview` or `MultiPreview` classes to modify preview configurations dynamically at runtime (e.g., building names dynamically based on parameters, which is impossible in a `const` constructor).

## Preview Parameters

The `@Preview` annotation supports the following parameters for tailoring preview environments:

- `name`: A descriptive name for the preview instance.
- `group`: A name used to group related previews together in the previewer.
- `size`: Artificial constraints using a `Size` object.
- `textScaleFactor`: Custom font scale factor.
- `wrapper`: A function that wraps the previewed widget in a specific widget tree (e.g., to inject state or inherited widgets).
- `theme`: A function returning a `PreviewThemeData` subclass instance to provide custom theming with support for sequential theme layering.
- `brightness`: The initial theme `Brightness` (`Brightness.light` or `Brightness.dark`).
- `localizations`: A function applying a localization configuration.

## Handling Limitations

Adhere to the following constraints when authoring previewable widgets, as the Widget Previewer runs in a web environment:

- **No Native APIs:** Do not use native plugins or APIs from `dart:io` or `dart:ffi`. Widgets with transitive dependencies on `dart:io` or `dart:ffi` will throw exceptions upon invocation. Use conditional imports or wrappers to mock or bypass these in preview mode.
- **Asset Paths:** Use package-based paths for assets loaded via `dart:ui` `fromAsset` APIs (e.g., `packages/my_package_name/assets/my_image.png` instead of `assets/my_image.png`).
- **Public Callbacks:** Ensure all callback arguments provided to preview annotations are public and constant to satisfy code generation requirements.
- **Constraints:** Apply explicit constraints using the `size` parameter in the `@Preview` annotation if your widget is unconstrained, as unconstrained widgets default to roughly half the viewport.
- **Build Caching:** The previewer caches builds in a `.widget_preview/` folder in the project root.

## Workflows

### Creating a Widget Preview
Copy and track this checklist when implementing a new widget preview:

- [ ] Import `package:flutter/widget_previews.dart`.
- [ ] Identify a valid target (top-level function, static method, or parameter-less public constructor).
- [ ] Apply the `@Preview` annotation to the target.
- [ ] Configure preview parameters (`name`, `group`, `size`, `textScaleFactor`, `wrapper`, `theme`, `brightness`, `localizations`) as needed.
- [ ] If applying the same configuration to multiple widgets, extract the configuration into a custom class extending `Preview` or `MultiPreview`.

### Interacting with Previews
Follow the appropriate conditional workflow to launch and interact with the Widget Previewer:

**If using a supported IDE (Android Studio, IntelliJ, VS Code with Flutter 3.47+):**
1. Launch the IDE. The Widget Previewer starts automatically.
2. Open the "Flutter Widget Preview" tab in the sidebar.
3. Toggle "Filter previews by selected file" at the bottom of the environment to switch between showing only previews in the active file vs. project-wide previews.

**If using the Command Line:**
1. Navigate to the Flutter project's root directory.
2. Run `flutter widget-preview start`.
3. View the automatically launched real-time preview environment in the browser.

**Searching and Filtering:**
- Use the search bar at the top of the preview environment to filter previews in real-time.
- Use the filter dropdown to match against:
  - **Preview name**: Filter by preview `name`.
  - **Group name**: Filter by preview `group`.
  - **Containing script**: Filter by the URI of the Dart file containing the preview.
  - **Containing package**: Filter by the package name.

**Feedback Loop: Preview Controls & Iteration**
1. Inspect the preview using card controls:
   - **Zoom in / Zoom out / Reset zoom**: Adjust preview magnification.
   - **Toggle light/dark mode**: Switch color scheme.
   - **Preview hot restart**: Restart only the specific widget preview to apply local changes quickly.
2. Modify widget code or preview configurations.
3. If global state was modified (e.g., static initializers changed): Use the global hot restart button at the bottom right of the previewer.

## Examples

### Basic Preview
```dart
import 'package:flutter/widget_previews.dart';
import 'package:flutter/material.dart';

@Preview(name: 'Submit Button', group: 'Form Controls')
Widget submitButtonPreview() => const ElevatedButton(
      onPressed: null,
      child: Text('Submit'),
    );
```

### Custom Preview with PreviewThemeData and Transformation
```dart
import 'package:flutter/widget_previews.dart';
import 'package:flutter/material.dart';

final class ThemedPreview extends Preview {
  const ThemedPreview({
    super.name,
    super.group,
    super.brightness,
  });

  PreviewThemeData _themeBuilder() =>
      CustomThemeData(brightness: brightness);

  @override
  Preview transform() {
    final originalPreview = super.transform();
    final themeVariant = switch (brightness) {
      null => 'Responsive',
      final b => b.name,
    };

    final builder = originalPreview.toBuilder();
    final baseName = originalPreview.name ?? 'Preview';
    builder
      ..name = '$baseName [$themeVariant]'
      ..theme = _themeBuilder;

    return builder.build();
  }
}

final class CustomThemeData extends PreviewThemeData {
  const CustomThemeData({this.brightness});

  final Brightness? brightness;

  @override
  Widget apply(BuildContext context, Widget child) {
    return Theme(
      data: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness ??
              MediaQuery.maybePlatformBrightnessOf(context) ??
              Brightness.light,
        ),
      ),
      child: child,
    );
  }
}

@ThemedPreview(name: 'Themed Action Button', brightness: Brightness.dark)
Widget themedButtonPreview() => const ElevatedButton(
      onPressed: null,
      child: Text('Action'),
    );
```

### MultiPreview Implementation
```dart
import 'package:flutter/widget_previews.dart';
import 'package:flutter/material.dart';

/// Creates light and dark mode previews automatically.
final class MultiBrightnessPreview extends MultiPreview {
  const MultiBrightnessPreview({required this.name});

  final String name;

  @override
  List<Preview> get previews => const [
        Preview(brightness: Brightness.light),
        Preview(brightness: Brightness.dark),
      ];

  @override
  List<Preview> transform() {
    final previews = super.transform();
    return previews.map((preview) {
      final builder = preview.toBuilder()
        ..group = 'Brightness'
        ..name = '$name - ${preview.brightness!.name}';
      return builder.toPreview();
    }).toList();
  }
}

@MultiBrightnessPreview(name: 'Primary Card')
Widget cardPreview() => const Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Content'),
      ),
    );
```
