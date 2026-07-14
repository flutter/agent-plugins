---
name: dart-use-pattern-matching
description: Use switch expressions and pattern matching where appropriate
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 24 Apr 2026 15:08:55 GMT
---
# Implementing Dart Patterns

## Contents
- [Pattern Selection Strategy](#pattern-selection-strategy)
- [Switch Statements vs. Expressions](#switch-statements-vs-expressions)
- [Core Pattern Implementations](#core-pattern-implementations)
- [Workflows](#workflows)
- [Examples](#examples)

## Pattern Selection Strategy

Apply specific pattern types based on the data structure and desired outcome. Follow these conditional guidelines:

*   **If validating and extracting from deserialized data (e.g., JSON):** Use Map and List patterns to simultaneously check structure and destructure key-value pairs.
*   **If handling multiple return values:** Use Record patterns to destructure fields directly into local variables.
*   **If executing type-specific behavior (Algebraic Data Types):** Use Object patterns combined with `sealed` classes to ensure exhaustiveness.
*   **If matching numeric ranges or conditions:** Use Relational (`>=`, `<=`) and Logical-and (`&&`) patterns.
*   **If multiple cases share logic:** Use Logical-or (`||`) patterns to share a single case body or guard clause.
*   **If ignoring specific values:** Use the Wildcard pattern (`_`) or a non-matching Rest element (`...`) in collections.

## Switch Statements vs. Expressions

Select the appropriate switch construct based on the execution context:

*   **If producing a value:** Use a **switch expression**.
    *   Syntax: `switch (value) { pattern => expression, }`
    *   Rule: Each case must be a single expression. No implicit fallthrough. Must be exhaustive.
*   **If executing statements or side effects:** Use a **switch statement**.
    *   Syntax: `switch (value) { case pattern: statements; }`
    *   Rule: Empty cases fall through to the next case. Non-empty cases implicitly break (no `break` keyword required).

## Core Pattern Implementations

Implement patterns using the following syntax and rules:

*   **Logical-or (`||`):** `pattern1 || pattern2`. Both branches must define the exact same set of variables.
*   **Logical-and (`&&`):** `pattern1 && pattern2`. Branches must *not* define overlapping variables.
*   **Relational:** `==`, `!=`, `<`, `>`, `<=`, `>=` followed by a constant expression.
*   **Cast (`as`):** `pattern as Type`. Throws if the value does not match the type. Use to forcibly assert types during destructuring.
*   **Null-check (`?`):** `pattern?`. Fails the match if the value is null. Binds the variable to the non-nullable base type.
*   **Null-assert (`!`):** `pattern!`. Throws if the value is null.
*   **Variable:** `var name` or `Type name`. Binds the matched value to a new local variable.
*   **Wildcard (`_`):** Matches any value and discards it.
*   **List:** `[pattern1, pattern2]`. Matches lists of exact length unless a Rest element (`...` or `...var rest`) is used.
*   **Map:** `{"key": pattern}`. Matches maps containing the specified keys. Ignores unmatched keys.
*   **Record:** `(pattern1, named: pattern2)`. Matches records of the exact shape. Use `:var name` to infer the getter name.
*   **Object:** `ClassName(field: pattern)`. Matches instances of `ClassName`. Use `:var field` to infer the getter name.

## Workflows

### Task Progress: Implementing Pattern Matching
Copy this checklist to track progress when implementing complex pattern matching logic:

- [ ] Identify the data structure being evaluated (JSON, Record, Class, Enum).
- [ ] Select the appropriate switch construct (Expression for values, Statement for side-effects).
- [ ] Define the required patterns (Object, Map, List, Record).
- [ ] Extract required data using Variable patterns (`var x`, `:var y`).
- [ ] Apply Guard clauses (`when condition`) for logic that cannot be expressed via patterns.
- [ ] Handle unmatched cases using a Wildcard (`_`) or `default` clause (if not using a sealed class).
- [ ] Run exhaustiveness validator.

### Feedback Loop: Exhaustiveness Checking
When switching over `sealed` classes or enums, you must ensure all subtypes are handled.

1. **Run validator:** Execute `dart analyze`.
2. **Review errors:** Look for "The type 'X' is not exhaustively matched by the switch cases" errors.
3. **Fix:** Add the missing Object patterns for the unhandled subtypes, or add a Wildcard (`_`) case if a default fallback is acceptable.

## Examples

### JSON Validation and Destructuring
Use Map and List patterns to validate structure and extract data in a single step.

**Input:**
```dart
var data = {
  'user': ['Lily', 13],
};
```

**Implementation:**
```dart
if (data case {'user': [String name, int age]}) {
  print('User $name is $age years old.');
} else {
  print('Invalid JSON structure.');
}
```

### Algebraic Data Types (Sealed Classes)
Use Object patterns with switch expressions to handle family types exhaustively.

**Implementation:**
```dart
sealed class Shape {}

class Square implements Shape {
  final double length;
  Square(this.length);
}

class Circle implements Shape {
  final double radius;
  Circle(this.radius);
}

// Switch expression guarantees exhaustiveness due to `sealed` modifier.
double calculateArea(Shape shape) => switch (shape) {
  Square(length: var l) => l * l,
  Circle(:var radius)   => math.pi * radius * radius,
};
```

### Variable Swapping and Destructuring
Use variable assignment patterns to swap values or extract record fields without temporary variables.

**Implementation:**
```dart
var (a, b) = ('left', 'right');
(b, a) = (a, b); // Swap values

// Destructuring a function return
var (name, age) = getUserInfo();
```

### Guard Clauses and Logical-or
Use `when` to evaluate arbitrary conditions after a pattern matches.

**Implementation:**
```dart
switch (shape) {
  case Square(size: var s) || Circle(size: var s) when s > 0:
    print('Valid symmetric shape with size $s');
  case Square() || Circle():
    print('Invalid or empty shape');
  default:
    print('Unknown shape');
}
```
