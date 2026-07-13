---
name: dart-migrate-to-checks-package
description: |-
  Replace the usage of `expect` and similar functions from `package:matcher`
  to `package:checks` equivalents.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 09 Jun 2026 19:30:00 GMT
---
# Migrating Dart Tests to Package Checks

Use this skill when you need to migrate a Dart test suite from the legacy
`package:matcher` (which is exported by default from `package:test/test.dart`)
to the modern, type-safe, and literate `package:checks` assertion library.

## Contents
- [When to Use This Skill](#when-to-use-this-skill)
- [How to Use This Skill (The Workflow)](#how-to-use-this-skill-the-workflow)
- [Key Syntax Differences and Pitfalls](#key-syntax-differences-and-pitfalls)
- [Matcher-to-Checks Mapping Table](#matcher-to-checks-mapping-table)
- [Matchers with No Direct Replacements](#matchers-with-no-direct-replacements)
- [Strategies for Discovery](#strategies-for-discovery)
- [Examples](#examples)

---

## When to Use This Skill
- When asked to "migrate tests to checks", "use package:checks", or
  "modernize test assertions".
- When updating legacy test suites where static type safety, better
  autocomplete in IDEs, and highly detailed failure diagnostics are desired.

---

## How to Use This Skill (The Workflow)

Follow this structured workflow to safely and systematically migrate a test suite:

### 1. Dependency Setup
- Add `package:checks` as a `dev_dependency` in `pubspec.yaml`:
  ```bash
  dart pub add dev:checks
  ```
- Remove `package:matcher` if it is explicitly listed under `dev_dependencies`
  (it is typically transitively included by `package:test`, which is fine).

### 2. Identify and Plan Target Files
- Use the grep patterns in [Strategies for Discovery](#strategies-for-discovery)
  to locate all test files containing legacy `expect` or `expectLater` calls.
- Decide whether to migrate files fully or incrementally.

### 3. Migrating a File (Incremental or Full)
For any target test file:
1. **Update Imports**:
   - Replace the generic `import 'package:test/test.dart';` with:
     ```dart
     import 'package:test/scaffolding.dart';
     import 'package:checks/checks.dart';
     ```
   - **For Incremental Migration**: If you only want to migrate some test cases
     in the file, or want to migrate one step at a time, add:
     ```dart
     import 'package:test/expect.dart'; // Temporarily allows legacy expect()
     ```
2. **Translate Assertions**: Rewrite legacy `expect` and `expectLater` calls
   to `check` syntax following the [Key Syntax Differences and
   Pitfalls](#key-syntax-differences-and-pitfalls) and the
   [Matcher-to-Checks Mapping Table](#matcher-to-checks-mapping-table).
3. **Verify via Compiler**: If migrating fully, remove the `import
   'package:test/expect.dart';` line. Any remaining un-migrated `expect`
   calls will immediately surface as compiler errors, making them easy to
   find and fix.

### 4. Verification and Feedback Loops
- **Static Analysis**: Run static analysis on the target package:
  ```bash
  dart analyze
  ```
  Pay close attention to generic type parameters on `.isA<Type>()` and
  ensure asynchronous expectations are properly awaited (check for
  `unawaited_futures` warnings).
- **Run Tests**: Execute the tests to verify both behavior and correct
  assertion runtime logic:
  ```bash
  dart test
  ```
  If a test fails, review the extremely detailed failure output of
  `package:checks` to diagnose if the test is genuinely failing or if the
  expectation was translated incorrectly.

---

## Key Syntax Differences and Pitfalls

> [!IMPORTANT]
> A line-for-line translation can sometimes introduce subtle bugs or false
> passes. Always review these key differences carefully:

### 1. Collection Equality Pitfall (`equals` vs `deepEquals`)
- **Legacy Matcher**: `expect(actual, expected)` or `expect(actual,
  equals(expected))` performed a **deep equality check** if the arguments
  were collections (Lists, Maps, Sets).
- **Package Checks**: `.equals(expected)` corresponds strictly to
  `operator ==`. Since Dart collections do not override `operator ==` for
  element-wise comparison, using `.equals` on a collection will check for
  *identity* and almost certainly fail at runtime.
- **Remediation**: You **must** replace collection equality assertions with
  `.deepEquals(expected)`.
  ```dart
  // BEFORE (Matcher)
  expect(myList, [1, 2, 3]);

  // AFTER (Checks)
  check(myList).deepEquals([1, 2, 3]);
  ```

### 2. The `reason` Parameter is now `because`
- **Legacy Matcher**: The explanation was passed as a trailing named
  argument `reason` to `expect`:
  ```dart
  expect(actual, expectation, reason: 'Explanation');
  ```
- **Package Checks**: The explanation is passed as the named argument
  `because` to the `check` function *before* the actual subject:
  ```dart
  check(because: 'Explanation', actual).expectation();
  ```

### 3. Regular Expression Matching (`matches` vs `matchesPattern`)
- **Legacy Matcher**: The `matches(pattern)` matcher automatically converted
  a `String` argument into a `RegExp` (e.g., `matches(r'\d')` matched `'1'`).
- **Package Checks**: `.matchesPattern(pattern)` treats a `String` argument
  as a literal string pattern.
- **Remediation**: To match using a regular expression, you must explicitly
  pass a `RegExp` object:
  ```dart
  // BEFORE (Matcher)
  expect(someString, matches(r'\d+'));

  // AFTER (Checks)
  check(someString).matchesPattern(RegExp(r'\d+'));
  ```

### 4. Property Extraction (`TypeMatcher.having` vs `.has`)
- **Legacy Matcher**: Chained field/property expectations used
  `TypeMatcher.having(feature, description, matcher)`:
  ```dart
  expect(actual, isA<Person>().having((p) => p.name, 'name', startsWith('A')));
  ```
- **Package Checks**: The `.has(feature, description)` extension is
  available on all `Subject`s, takes one fewer argument, and returns a new
  `Subject` representing that property. You chain expectations directly off
  it:
  ```dart
  check(actual).isA<Person>().has((p) => p.name, 'name').startsWith('A');
  ```

### 5. Synchronous vs. Asynchronous `throws`
- **Legacy Matcher**: In `package:matcher`, `throwsA` behaved similarly for both
  synchronous closures and asynchronous futures when wrapped in `expect` or
  `expectLater`.
- **Package Checks**: The `.throws<E>()` expectation behaves differently and
  has different return types depending on whether the subject is synchronous or
  asynchronous:
  - **Synchronous** (`Subject<T Function()>`): `.throws<E>()` returns a
    `Subject<E>` synchronously. This **does not** accept a callback argument!
    You chain or cascade expectations directly off the returned `Subject<E>`:
    ```dart
    // YES (Synchronous chaining)
    check(() => triggerSyncError()).throws<ArgumentError>()
      ..has((e) => e.message, 'message').equals('invalid input');

    // NO (Passing a callback to sync throws will cause a compiler error!)
    check(() => triggerSync").throws<ArgumentError>((it) => ...); // ERROR!
    ```
  - **Asynchronous** (`Subject<Future<T>>`): `.throws<E>()` returns
    `Future<void>`. Because you cannot chain directly off a `Future<void>`, this
    **requires** an inspection callback:
    ```dart
    // YES (Asynchronous callback)
    await check(triggerAsyncError()).throws<ArgumentError>((it) => it
      ..has((e) => e.message, 'message').equals('invalid input'));
    ```
  - **Crucial Pitfall**: Trying to chain expectations directly after an awaited
    asynchronous `.throws<E>()` (e.g.,
    `await check(future).throws<E>().equals(...)`) will fail to compile
    because it returns `Future<void>`.

### 6. RegExp / Pattern Equality
- **Legacy Matcher**: In `package:matcher`, `expect(myPattern,`
  `equals(RegExp('Hello')))` worked because the matcher comparison rules
  handled RegExp instances.
- **Package Checks**: `.equals()` uses strict Dart `==` equality. Since separate
  `RegExp` instances do not satisfy `==`, using `.equals()` will fail at runtime.
- **Remediation**: Use `.isA<RegExp>()` type refinement along with cascades to
  assert on the properties of the `RegExp` object explicitly:
  ```dart
  check(myPattern).isA<RegExp>()
    ..has((r) => r.pattern, 'pattern').equals('Hello')
    ..has((r) => r.isMultiLine, 'isMultiLine').isTrue();
  ```

### 7. Strict Nullable Boolean Safety (`bool?` fields)
- **Legacy Matcher**: Statically, `isTrue` and `isFalse` performed loose
  dynamic checks at runtime, which silently accepted nullable booleans (`bool?`).
- **Package Checks**: `.isTrue()` and `.isFalse()` are defined strictly on
  `Subject<bool>` (non-nullable). They are **not** available on `Subject<bool?>`.
- **Remediation**: For fields declared as `bool?`, you must either refine the
  subject (e.g., `.isNotNull().isTrue()`) or simply use `.equals(true)` and
  `.equals(false)` which are generic and work on all types:
  ```dart
  // If options.flagOutdated is a bool?
  check(options.flagOutdated).equals(true);
  check(options.flagOutdated).equals(false);
  ```

### 8. Map Key Containment (`containsKey` vs `contains`)
- **Legacy Matcher**: In `package:matcher`, `contains(key)` was used to assert
  that a `Map` contained a specific key.
- **Package Checks**: Calling `.contains(...)` on a `Subject<Map>` is not
  defined and will fail compilation.
- **Remediation**: Use the map-specific `.containsKey(key)` matcher instead:
  ```dart
  // BEFORE (Matcher)
  expect(myMap, contains('my_key'));

  // AFTER (Checks)
  check(myMap).containsKey('my_key');
  ```

### 9. Explicit Generic Parameters for Extension Types
- **Legacy Matcher**: `expect(extensionTypeConst, 3)` compiled because of loose
  dynamic equality.
- **Package Checks**: If `QrEciValue` is an extension type representation of `int`
  (e.g., `extension type const QrEciValue(int value) implements int`), calling
  `.equals(3)` on a `Subject<QrEciValue>` fails because `3` (an `int`) is not
  assignable to `QrEciValue`. Casting with `as int` will trigger an
  "Unnecessary cast" static analysis warning because `QrEciValue` statically
  implements `int`.
- **Remediation**: Explicitly specify the generic type parameter on the `check`
  function to force checks to treat it as the primitive type:
  ```dart
  // YES (Type-safe and warning-free)
  check<int>(QrEciValue.iso8859_1).equals(3);
  ```

### 10. Dynamic Map / JSON Lookup Casting
- **Legacy Matcher**: Loose dynamic typing allowed comparing nested json lookups
  statically typed as `dynamic` directly against lists or maps.
- **Package Checks**: Strict type safety rejects the implicit assignment of
  `dynamic` to `Iterable<Object?>` in `.deepEquals(...)`.
- **Remediation**: Statically cast the dynamic lookup result to a `List` or `Map`:
  ```dart
  // YES (Explicit cast to List)
  check(myIterable).deepEquals(json['data']['items'] as List);
  ```

---

## Matcher-to-Checks Mapping Table

Use this table as a quick reference for direct matcher replacements:

| Legacy Matcher | Package Checks Equivalent | Notes |
| :--- | :--- | :--- |
| `expect(actual, expected)` | `check(actual).equals(expected)` | Use `.deepEquals` for collections! |
| `expect(actual, equals(expected))` | `check(actual).equals(expected)` | Use `.deepEquals` for collections! |
| `isA<T>()` | `check(actual).isA<T>()` | Chaining is supported directly |
| `same(expected)` | `check(actual).identicalTo(expected)` | Verifies identity |
| `anyElement(matcher)` | `check(iterable).any(conditionCallback)` | E.g. `check(list).any((e) => e.equals(1))` |
| `everyElement(matcher)` | `check(iterable).every(conditionCallback)` | E.g. `check(list).every((e) => e.isGreaterThan(0))` |
| `hasLength(expected)` | `check(actual).length.equals(expected)` | Works on String, Map, Iterable, etc. |
| `isNot(matcher)` | `check(actual).not(conditionCallback)` | E.g. `check(val).not((it) => it.equals(5))` |
| `contains(element)` | `check(actual).contains(element)` | Works on String, Iterable (use `containsKey` for Map!) |
| `contains(key)` (on a Map) | `check(map).containsKey(key)` | Map key containment |
| `startsWith(prefix)` | `check(string).startsWith(prefix)` | String only |
| `endsWith(suffix)` | `check(string).endsWith(suffix)` | String only |
| `isEmpty` | `check(actual).isEmpty()` | Works on String, Map, Iterable |
| `isNotEmpty` | `check(actual).isNotEmpty()` | Works on String, Map, Iterable |
| `isNull` | `check(actual).isNull()` | |
| `isNotNull` | `check(actual).isNotNull()` | |
| `isTrue` / `true` | `check(actual).isTrue()` | Works on non-nullable `bool` only |
| `isFalse` / `false` | `check(actual).isFalse()` | Works on non-nullable `bool` only |
| `completion(matcher)` | `await check(future).completes(conditionCallback)` | Must be awaited! |
| `throwsA(matcher)` | `await check(future).throws<Type>()` | Must be awaited! |
| `emits(value)` | `await check(streamQueue).emits(conditionCallback)` | Must be awaited! |
| `emitsThrough(value)` | `await check(streamQueue).emitsThrough(conditionCallback)` | Must be awaited! |
| `stringContainsInOrder(list)` | `check(string).containsInOrder(list)` | String only |
| `pairwiseCompare(...)` | `check(actual).pairwiseMatches(...)` | |

---

## Matchers with No Direct Replacements

Some legacy matchers do not have a one-to-one equivalent in `package:checks`
due to API cleanup. Use these standard workarounds:

### 1. Specific Error Matchers
- **Legacy**: `throwsArgumentError`, `throwsStateError`,
  `throwsUnsupportedError`, etc.
- **Checks**: Use `.throws<T>()` with the specific error type:
  ```dart
  await check(triggerError()).throws<ArgumentError>();
  ```

### 2. The `anything` Matcher
- **Legacy**: `expect(actual, anything)`
- **Checks**: Pass an empty condition callback `(_) {}` when a condition is
  syntactically required:
  ```dart
  await check(someFuture).completes((_) {});
  ```

### 3. Specific Numeric Toggles
- **Legacy**: `isPositive`, `isNegative`, `isZero`, `isNonPositive`,
  `isNonNegative`, `isNonZero`
- **Checks**: Use explicit comparative expectations:
  - `isPositive` $\rightarrow$ `isGreaterThan(0)`
  - `isNegative` $\rightarrow$ `isLessThan(0)`
  - `isZero` $\rightarrow$ `equals(0)`
  - `isNonNegative` $\rightarrow$ `isGreaterOrEqual(0)`

### 4. Numeric Ranges
- **Legacy**: `inClosedOpenRange(min, max)`, `inInclusiveRange(min, max)`,
  etc.
- **Checks**: Chain the boundaries using the cascade operator (`..`):
  ```dart
  check(actualValue)
    ..isGreaterOrEqual(min)
    ..isLessThan(max);
  ```

---

## Writing Custom Expectations (Replacing Custom Matchers)

When migrating from a legacy codebase, you may encounter custom `Matcher`
subclasses. In `package:checks`, custom assertions are implemented as
`extension` methods on `Subject<T>`.

To write custom expectations, you must import the checks context API:
```dart
import 'package:checks/context.dart';
```

### 1. Simple Custom Expectations (using `expect`)
Use `context.expect` to check a property and return a `Rejection` on failure:
```dart
extension CustomPersonChecks on Subject<Person> {
  void isAdult() {
    context.expect(
      () => ['is an adult (age >= 18)'],
      (actual) {
        if (actual.age >= 18) return null; // Pass
        return Rejection(
          which: ['is only ${actual.age} years old'],
        );
      },
    );
  }
}
```

### 2. Nested Property Extraction (using `nest` or `has`)
To extract a property and allow further chained checks, use `nest` or the
simpler `has` helper:
- **Using `has` (Recommended for simple, non-failing field access)**:
  ```dart
  extension CustomPersonChecks on Subject<Person> {
    Subject<Address> get address => has((p) => p.address, 'address');
  }
  ```
- **Using `nest` (For property extraction that can fail or reject)**:
  ```dart
  extension CustomPersonChecks on Subject<Person> {
    Subject<String> get ssn => context.nest(
      'has a valid SSN',
      (actual) {
        final ssnValue = actual.ssn;
        if (ssnValue == null) {
          return Extracted.rejection(which: ['has no SSN']);
        }
        return Extracted.value(ssnValue);
      },
    );
  }
  ```

### 3. Asynchronous Custom Expectations
If the expectation is asynchronous (e.g. checking a Future or Stream), use
`context.expectAsync` or `context.nestAsync` and return the resulting `Future`:
```dart
extension CustomFutureChecks<T> on Subject<Future<T>> {
  Future<void> completesNormally() {
    return context.expectAsync(
      () => ['completes without throwing'],
      (actual) async {
        try {
          await actual;
          return null; // Pass
        } catch (e) {
          return Rejection(which: ['threw $e']);
        }
      },
    );
  }
}
```

---

## Strategies for Discovery

Execute these commands in the terminal to identify legacy matchers and files
requiring migration:

```bash
# 1. Find all test files containing legacy expect() or expectLater()
grep -rn "expect(" test/
grep -rn "expectLater(" test/

# 2. Find potential collection equality pitfalls (literal lists or maps)
grep -rn "expect(.*, \[" test/
grep -rn "expect(.*, {" test/

# 3. Find matches() calls (need conversion to RegExp + matchesPattern)
grep -rn "matches(" test/

# 4. Find legacy TypeMatcher.having() calls (which need conversion to .has())
grep -rn "having(" test/
```

---

## Examples

### Basic Assertions
**Before (Matcher):**
```dart
expect(someValue, isNotNull);
expect(result, isTrue, reason: 'should be successful');
expect(myString, startsWith('hello'));
```

**After (Checks):**
```dart
check(someValue).isNotNull();
check(because: 'should be successful', result).isTrue();
check(myString).startsWith('hello');
```

### Collection and Deep Equality
**Before (Matcher):**
```dart
expect(items, [1, 2, 3]);
expect(configMap, equals({'port': 8080}));
```

**After (Checks):**
```dart
check(items).deepEquals([1, 2, 3]);
check(configMap).deepEquals({'port': 8080});
```

### Chaining and Cascades
**Before (Matcher):**
```dart
expect(someString, allOf([
  startsWith('a'),
  contains('b'),
  endsWith('c'),
]));
```

**After (Checks):**
```dart
check(someString)
  ..startsWith('a')
  ..contains('b')
  ..endsWith('c');
```

### Complex Property Matching (has)
**Before (Matcher):**
```dart
expect(response, isA<Response>()
    .having((r) => r.statusCode, 'statusCode', 200)
    .having((r) => r.body, 'body', contains('success')));
```

**After (Checks):**
```dart
check(response).isA<Response>()
  ..has((r) => r.statusCode, 'statusCode').equals(200)
  ..has((r) => r.body, 'body').contains('success');
```

### Asynchronous Futures
**Before (Matcher):**
```dart
expect(fetchData(), completes);
expect(fetchData(), completion(equals('data')));
expect(failingCall(), throwsA(isA<StateError>()));
```

**After (Checks):**
```dart
await check(fetchData()).completes();
await check(fetchData()).completes((it) => it.equals('data'));
await check(failingCall()).throws<StateError>();
```

### Asynchronous Streams
**Before (Matcher):**
```dart
var queue = StreamQueue(Stream.fromIterable([1, 2, 3]));
await expectLater(queue, emitsInOrder([1, 2, 3]));
```

**After (Checks):**
```dart
var queue = StreamQueue(Stream.fromIterable([1, 2, 3]));
await check(queue).inOrder([
  (s) => s.emits((e) => e.equals(1)),
  (s) => s.emits((e) => e.equals(2)),
  (s) => s.emits((e) => e.equals(3)),
]);
```
