# Dart & Flutter Documentation

## Documentation Structure (`///`)

Use `///` (doc comments) for all public members to allow tools like `dartdoc` to process them.

### Comments Format

1.  **Summary Sentence**: Start with a single-sentence summary on the first line, ending with a period.
2.  **Blank Line**: Follow the summary with a blank line.
3.  **Details**: Add paragraphs, code samples, or lists as needed to explain parameters, return values, exceptions, and behavior.
4.  **Annotations**: Place doc comments **before** any metadata annotations (e.g., `@override`, `@Deprecated`).

```dart
/// A button that initiates a purchase flow.
///
/// This widget handles the loading state automatically and disables
/// itself while the transaction is processing.
@Deprecated('Use PurchaseButtonV2 instead')
class PurchaseButton extends StatelessWidget { ... }
```

### Property Documentation

- **Getters override Setters**: Document the getter and omit documentation on the setter, as documentation tools combine them automatically. Do not document both.
  ```dart
  /// The current optimization level (0.0 to 1.0).
  double get optimizationLevel => _level;
  set optimizationLevel(double value) { ... }
  ```

### Library Documentation

- **Library Comments**: Add a doc comment at the top of the file (before imports) for libraries (files) to provide a high-level overview.

## Writing Guidelines

### Terminology

- Use **canonical terms**:
  - Refer to "widgets", "state", "build context", "render object".
  - Avoid generic terms like "component" or "element" when you mean "Widget".

### Code References

- Use square brackets `[MyClass]`, `[variableName]`, `[methodName]` to link to in-scope identifiers.
- Use backticks `` `true` ``, `` `null` ``, `` `this` `` for keywords and literals.
- **Code Samples**: Include code blocks to demonstrate usage.
  ````dart
  /// Example:
  ///
  /// ```dart
  /// final path = FlightPath(coordinates: [a, b]);
  /// ```
  ````

## Flutter Specifics

### Widgets

- **Purpose**: Explain what the widget does and when to use it.
- **Parameters**: Document key parameters, especially if they are required or have complex constraints.
- **State**: Explain any interesting state behavior, such as keeping position on scroll.

```dart
/// Displays a flight path on a map.
///
/// Use this widget within a [MapLayout]. The path is drawn using
/// the provided [coordinates].
class FlightPath extends StatelessWidget {
  /// Creates a flight path.
  ///
  /// The [coordinates] must contain at least two points.
  const FlightPath({required this.coordinates, super.key});
```

### State Management

- **Lifecycle**: Explain how to dispose of controllers or other classes that manage a complex lifecycle.
- **Private Classes**: Document significantly complex private classes (such as intricate `State` logic) to aid maintainability, even though public APIs are the priority.
