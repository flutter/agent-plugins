---
name: dart-use-primary-constructors
description: >
  Help users write syntactically and semantically correct primary constructors in Dart, and migrate/use the new constructor syntax, empty-body semicolon syntax, in-body initializer list syntax, and abbreviated concise constructor syntax.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Thu, 09 Jul 2026 23:13:25 GMT
---

# Dart Primary Constructors & New Constructor Syntax Skill

Use this skill when helping users write, refactor, or debug code using Dart's **Primary Constructors** feature.

### Dart Version Requirements
*   **Dart 3.13 and above**: Primary constructors are enabled by default.
*   **Dart 3.12**: The feature is available but experimental. Users must explicitly enable the experiment flag `primary-constructors` via `--enable-experiment=primary-constructors` or in `analysis_options.yaml`:
```yaml
analyzer:
  enable-experiment:
    - primary-constructors
```
*   **Dart 3.11 and earlier**: Primary constructors are not supported.

---

## 1. Overview
Primary Constructors allow developers to declare a non-redirecting generative constructor as well as a set of instance variables directly in the class header. This significantly reduces boilerplate and improves code readability.

### Key Benefits
- Combines field declaration, parameter declaration, and initialization into a single declaration known as a declaring parameter declaration.
- Enables safe reference to constructor parameters in non-late field initializers (Primary Initializer Scope).
- Allows empty declaration bodies to be represented concisely with a semicolon (`;`).
- Introduces abbreviated concise syntax for in-body constructors.

---

## 2. Syntax Reference

### 2.1 Basic Class Header Syntax
To declare a primary constructor, place a parameter list immediately after the type name (and optional type parameters):

```dart
// Declares fields x and y, and a generative constructor Point(this.x, this.y)
class Point(var int x, var int y);

// Declares final fields
class PointFinal(final int x, final int y);
```

### 2.2 Declaring, Initializing, and Plain Parameters
A primary constructor parameter list distinguishes between three types of parameters:
1. **Declaring Parameters**: Indicated by the `var` or `final` modifier (e.g., `final int x`). They implicitly create a corresponding instance field in the class.
2. **Initializing Parameters**: Indicated by the `this.` or `super.` prefix (e.g., `this.x` or `super.x`). They initialize an existing field or a super constructor parameter, respectively.
3. **Regular Parameters**: Declared without modifiers (e.g., `int y`). They do not become fields and are only available during initialization (e.g., in field initializers or the `this :` initializer list in the class body).

```dart
// `x` is a field and a parameter because it has the keyword `final`. In particular, we can use the name `x` in the initializer list in the in-body part of the primary constructor. 'y' is a only parameter because it has neither of the keywords `final` or `var`, but `y` is passed to the super constructor via the `this :` initializer list.
class C(final int x, int y) extends Base {
  this : super(y);
}
```

Declaring parameters and initializing parameters are two ways of achieving the same goal: declaring a class with instance fields which are set in the constructor. Regular parameters are different in that their values are not automatically routed to an instance field.

### 2.3 Constant Primary Constructors
To make a primary constructor `const`, place the `const` keyword before the class/type name in the declaration header:

```dart
class const Point(final int x, final int y);
extension type const Ext(int x);
enum const MyEnum(final int x) {
  entry(1);
}
```

### 2.4 Extension Types
Extension types **must** use primary constructors.
- The single parameter in the header is the representation field.
- The representation variable cannot use the `var` modifier (using `var` triggers the `representation_field_modifier` error).
- The representation variable can optionally use the `final` modifier. If `final` is not present then it is inferred; that is, the parameter is declaring whether or not it's explicitly `final`.

### 2.5 Empty Body Semicolon Shorthand (`;`)
When a class, mixin class, mixin, extension or extension type has an empty body, the `{}` braces can be replaced by a semicolon (`;`):

```dart
class C(int x);
mixin class MC;
extension type ET(int x);
mixin M;
extension Ext on C;
```

### 2.6 The In-Body Part of a Primary Constructor (`this ...`)
If a primary constructor requires assertions or custom field initializations, they can be declared in the body using the `this :` syntax:

```dart
class Point(var int x, var int y) {
  // Initializer list in class body
  this : assert(x >= 0), y = y * 2;
}
```

You can also write a constructor body with this syntax (`this {...}`).

### 2.7 Abbreviated Concise Constructor Syntax
For constructors declared within the class body, the class name can be omitted and replaced with the `new` or `factory` keywords:

| Traditional Syntax | Abbreviated Concise Syntax |
| :--- | :--- |
| `MyClass() {}` | `new() {}` |
| `MyClass.name() {}` | `new name() {}` |
| `const MyClass();` | `const new();` |
| `const MyClass.name();` | `const new name();` |
| `factory MyClass() => ...` | `factory() => ...` |
| `factory MyClass.name() => ...` | `factory name() => ...` |

---

## 3. Semantics & Scoping Rules

### 3.1 Primary Initializer Scope
When a primary constructor is declared, its formal parameters are introduced into the **Primary Initializer Scope**. This scope is the current scope for non-late field initializers in the class body and the primary constructor's initializer list (after `this :`).
This allows non-late fields to reference constructor parameters directly during declaration:
  ```dart
  class DeltaPoint(final int x, int delta) {
    // 'x' and 'delta' are in scope here
    final int y = x + delta;
  }
  ```

### 3.2 Late Instance Variables Restriction
The primary initializer scope is **not** active for `late` instance variable initializers.
- Since `late` variables can be evaluated after construction has completed, their initializers cannot safely access constructor parameters.
- Attempting to access a primary constructor parameter in a `late` field initializer results in a compile-time error.

### 3.3 Shadowing
Primary constructor parameters shadow class members (fields) of the same name within the primary initializer scope:
- In a non-late initializer: `int y = x` refers to parameter `x`.
- In a `late` initializer: `late int y = x` refers to field `x` (if it exists) because the parameter `x` is out of scope.

### 3.4 Generative Constructor Restrictions
To guarantee that the primary constructor (and the associated initializer scope) always executes:
- A class, mixin class, or enum declaration with a primary constructor **cannot** declare any other non-redirecting generative constructors (except extension types).
- All other generative constructors declared in the body **must** redirect (directly or indirectly) to the primary constructor.

### 3.5 Parameter Mutation Errors
Primary constructor parameters are non-assignable inside the initialization phase.
- Any assignment to a parameter (e.g., `p = value`, `p++`) inside field initializers or the `this :` initializer list is a compile-time error.

### 3.6 Double Initialization Errors
Initializing a field twice (e.g., once in the field declaration/initializer and once in the `this :` initializer list or as an initializing formal) is a compile-time error.

---

## 4. Diagnostics & Troubleshooting

Most errors and lints have quick-fixes, run `dart fix` to fix those violations. For other common errors, fix them using the following table:

| Error / Lint Code | Common Cause | Resolution |
| :--- | :--- | :--- |
| **Invalid Late Access** | Referencing a primary constructor parameter inside a `late` field initializer. | Make the field non-late, or pass the value through another non-late field. |
| `fieldInitializedInInitializerAndDeclaration` | Initializing a variable both in its declaration and in the `this :` list. | Remove one of the initializations. |
| `nonRedirectingGenerativeConstructorWithPrimary` | Declaring a in-body generative constructor in the body without redirecting to the primary. | Change the in-body constructor such that it is redirecting (e.g. `this(...)`) or remove the in-body constructor. |

---

## 5. Step-by-Step Refactoring Workflows

### Workflow 5.1: Migrating a Class to a Primary Constructor

Follow these steps to migrate a verbose class to the new primary constructor syntax:

1. **Identify Candidate Fields and Constructor**:
   Locate generative constructors and the fields they initialize. In this case, this would be the `name` and `age` fields.
   ```dart
   // Before
   class User {
     final String name;
     final int age;
     User(this.name, this.age);
   }
   ```

2. **Move Fields to the Header**:
   Place fields in the header with `final` or `var` modifiers and append a semicolon (`;`) if the body is empty. The `name` and `age` fields are now written the primary constructor as declaring parameters `final String name` and `final int age`, respectively.
   ```dart
   // After
   class User(final String name, final int age);
   ```

3. **Handle Custom Initializers and Assertions**:
   If there is an initializer list or assert block, move it to a `this` block inside the body:
   ```dart
   // Before
   class Point {
     final int x;
     final int y;
     Point(this.x, this.y) : assert(x >= 0);
   }

   // After
   class Point(final int x, final int y) {
     this : assert(x >= 0);
   }
   ```

4. **Leverage Primary Initializer Scope for Calculations**:
   If a field value is calculated from parameters, declare it inside the body and assign it directly using the parameters:
   ```dart
   // Before
   class Rect {
     final double width;
     final double height;
     final double area;
     Rect(this.width, this.height) : area = width * height;
   }

   // After
   class Rect(final double width, final double height) {
     // 'width' and 'height' are in scope here
     final double area = width * height;
   }
   ```

5. **Convert In-Body Constructors to Redirecting**:
   Ensure all in-body generative constructors redirect to the primary constructor:
   ```dart
   // Before
   class Point {
     final int x;
     final int y;
     Point(this.x, this.y);
     Point.zero() : x = 0, y = 0;
   }

   // After
   class Point(final int x, final int y) {
     new zero() : this(0, 0); // Redirects to primary
   }
   ```

### Workflow 5.2: Applying Abbreviated (Concise) In-Body Constructors

When the user prefers to keep the constructor in the class body but wants to reduce verbosity, suggest the abbreviated constructor syntax:

```dart
// Before
class DatabaseService {
  final String url;
  DatabaseService(this.url);
  DatabaseService.local() : url = 'localhost';
  factory DatabaseService.create() => DatabaseService('default');
}

// After
class DatabaseService {
  final String url;
  new(this.url); // Omit class name, use 'new'
  new local() : url = 'localhost'; // Use 'new local' for named constructors
  factory create() => DatabaseService('default'); // Omit class name from factory
}
```
