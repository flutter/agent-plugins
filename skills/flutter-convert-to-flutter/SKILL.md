---
name: flutter-convert-to-flutter
description: Migrate and convert native iOS (Swift, Objective-C) and Android (Kotlin, Java) applications, architecture patterns, concurrency, UI components, and subsystems to cross-platform Dart and Flutter. Use when converting native mobile codebases or UI screens to Flutter, translating language features and idioms to Dart 3, establishing platform channel or Pigeon interop, or modernizing mobile architectures.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 15 Sep 2026 20:50:00 GMT
---

# Migrating Native Mobile (Android & iOS) to Flutter

This skill guides the end-to-end migration of native mobile applications from **Android (Java, Kotlin)** and **iOS (Objective-C, Swift)** to cross-platform **Dart and Flutter**.

---

## Contents

- [Flutter Core Knowledge & Paradigms](#flutter-core-knowledge--paradigms)
  - [Declarative UI: UI as a Function of State](#declarative-ui-ui-as-a-function-of-state)
  - [The Three Trees: Widget, Element, and RenderObject](#the-three-trees-widget-element-and-renderobject)
  - [Concurrency Model: Single-Threaded Event Loop & Isolates](#concurrency-model-single-threaded-event-loop--isolates)
  - [Dart 3 Type System & Null Safety](#dart-3-type-system--null-safety)
- [Progressive Disclosure: Platform & Language Guides](#progressive-disclosure-platform--language-guides)
- [Universal Subsystem Mapping Table](#universal-subsystem-mapping-table)
- [Native Interoperability Decision Matrix](#native-interoperability-decision-matrix)
- [Universal Migration Workflow](#universal-migration-workflow)
- [Universal Pitfalls & Gotchas](#universal-pitfalls--gotchas)
- [Migration Verification Checklist](#migration-verification-checklist)

---

## Flutter Core Knowledge & Paradigms

Before migrating native code, align with Flutter's foundational design principles:

### Declarative UI: UI as a Function of State
- **Native Android/iOS (Imperative)**: Views are created and mutated directly via references (e.g. `textView.setText()`, `label.text = @"..."`, `findViewById()`, `@IBOutlet`).
- **Flutter (Declarative)**: The user interface is described as `UI = f(state)`. When state changes, widgets are rebuilt immutably.
  - **`StatelessWidget`**: Use for presentation widgets that depend solely on their constructor parameters.
  - **`StatefulWidget`**: Use when a widget owns local mutable state that triggers rebuilds via `setState()`.
  - **Composition over Inheritance**: Complex UIs are created by nesting simple single-purpose widgets (`Padding`, `Center`, `DecoratedBox`, `ConstrainedBox`), rather than configuring dozens of properties on a monolithic view class.

### The Three Trees: Widget, Element, and RenderObject
1. **Widget Tree**: Lightweight, immutable blueprints of UI elements instantiated on every rebuild.
2. **Element Tree**: Persistent lifecycle managers that manage widget updates, state retention, and tree diffing.
3. **RenderObject Tree**: Mutable objects that handle sizing, layout constraints, painting, and hit testing.
- **Rule of Thumb**: Creating widgets is extremely cheap in Dart; avoid caching widget instances manually unless optimizing static subtrees with `const`.

### Concurrency Model: Single-Threaded Event Loop & Isolates
- **Main UI Thread**: Dart runs in a single-threaded **isolate** powered by an event loop.
- **Resuming on Main**: Any code resuming after an `await` in the root isolate **already executes on the main UI thread**. There is **no need** for `runOnUiThread()`, `Dispatchers.Main`, `DispatchQueue.main.async`, or `Handler(Looper.getMainLooper())`.
- **CPU-Bound Tasks**: To execute heavy compute (e.g. image processing, massive JSON parsing, cryptography) without dropping frames, offload to a background isolate using `Isolate.run(() async => ...)`.

### Dart 3 Type System & Null Safety
- **Sound Null Safety**: Types are non-nullable by default (`String` vs `String?`). The compiler guarantees that a non-nullable variable will never hold `null`.
- **Sealed Classes & Pattern Matching**: Use `sealed class` hierarchies to represent finite state machines (e.g. `Loading`, `Success`, `Error`), and handle variants exhaustively via `switch` expressions.
- **Records & Destructuring**: Return multiple strongly typed values without ad-hoc tuple classes: `(int id, String name)`.

---

## Progressive Disclosure: Platform & Language Guides

Load the dedicated deep-dive reference document corresponding to the source language and platform:

| Source Language & Platform | Deep-Dive Reference File | Key Topics Covered |
| :--- | :--- | :--- |
| **Android (Java)** | [reference/android.md](reference/android.md) | Activities/Fragments $\rightarrow$ Widgets, XML layouts $\rightarrow$ `Column`/`Row`/`Stack`, `RecyclerView` $\rightarrow$ `ListView.builder`, `AsyncTask`/`Handler` $\rightarrow$ `Future`/`Stream`, Room $\rightarrow$ Drift/Sqflite, Retrofit $\rightarrow$ Dio/Http, Pigeon/JNI. |
| **Android (Kotlin)** | [reference/kotlin.md](reference/kotlin.md) | `data class` $\rightarrow$ immutable models, `sealed class`/`interface` $\rightarrow$ Dart 3 sealed classes, Coroutines/`Flow` $\rightarrow$ `async`/`await`/`Stream`, Jetpack Compose $\rightarrow$ Widgets, Compose Modifiers $\rightarrow$ composition, Hilt/Koin $\rightarrow$ Riverpod/GetIt. |
| **iOS (Swift / SwiftUI)** | [reference/swift.md](reference/swift.md) | Swift `struct` $\rightarrow$ Dart models, `Codable` $\rightarrow$ `json_serializable`, Swift Concurrency (`Task`/`actor`) $\rightarrow$ `Future`/`Isolate.run()`, Combine $\rightarrow$ `Stream`, SwiftUI `View` $\rightarrow$ `StatelessWidget`, `@State`/`@Binding`/`@Observable` $\rightarrow$ `StatefulWidget`/`ChangeNotifier`. |
| **iOS (Objective-C)** | [reference/objective-c.md](reference/objective-c.md) | `@interface`/`@implementation` $\rightarrow$ Dart classes, Foundation types $\rightarrow$ Dart core types, GCD / Blocks $\rightarrow$ `Future`/Closures, `UIViewController` $\rightarrow$ `StatefulWidget`, `UITableView` $\rightarrow$ `ListView.builder`, direct C/ObjC FFI via `ffigen`. |

---

## Universal Subsystem Mapping Table

| Application Subsystem | Android (Java/Kotlin) | iOS (Obj-C/Swift) | Flutter / Dart Ecosystem |
| :--- | :--- | :--- | :--- |
| **State Management** | ViewModel, LiveData, StateFlow | ObservableObject, @Observable, Combine | [`ChangeNotifier`](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html), [`ValueNotifier`](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html), [Riverpod](https://pub.dev/packages/flutter_riverpod), [BLoC](https://pub.dev/packages/flutter_bloc) |
| **HTTP Networking** | Retrofit, OkHttp, Ktor | URLSession, Alamofire | [`package:http`](https://pub.dev/packages/http), [`package:dio`](https://pub.dev/packages/dio) |
| **JSON Serialization** | Gson, Moshi, Kotlinx Serialization | Codable, NSJSONSerialization | `dart:convert`, [`package:json_serializable`](https://pub.dev/packages/json_serializable), [`package:freezed`](https://pub.dev/packages/freezed) |
| **Key-Value Storage** | SharedPreferences, DataStore | UserDefaults, Keychain | [`package:shared_preferences`](https://pub.dev/packages/shared_preferences), [`package:flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) |
| **Relational Database** | Room, SQLiteDatabase | Core Data, SwiftData, GRDB | [`package:drift`](https://pub.dev/packages/drift), [`package:sqflite`](https://pub.dev/packages/sqflite) |
| **NoSQL / Document DB** | Realm, Firebase | Realm, Firebase | [`package:hive_ce`](https://pub.dev/packages/hive_ce), `firebase_database` / `cloud_firestore` |
| **Dependency Injection** | Hilt, Dagger, Koin | Factory, Swinject, Dependencies | [`package:get_it`](https://pub.dev/packages/get_it), Riverpod Providers |
| **Navigation & Routing** | Navigation Component, Intents | NavigationStack, UINavigationController | [`package:go_router`](https://pub.dev/packages/go_router), [`Navigator`](https://api.flutter.dev/flutter/widgets/Navigator-class.html) |
| **Image Loading/Caching** | Glide, Coil, Picasso | Kingfisher, SDWebImage | [`package:cached_network_image`](https://pub.dev/packages/cached_network_image), `Image.network` |
| **Background Scheduling** | WorkManager, JobScheduler | BGAppRefreshTask, BGProcessingTask | [`package:workmanager`](https://pub.dev/packages/workmanager), platform channels |

---

## Native Interoperability Decision Matrix

When migrating an existing app, evaluate whether to rewrite completely or bridge retained native code:

```
                  ┌─────────────────────────────────────┐
                  │ Can this code be written in Dart?    │
                  └──────────────────┬──────────────────┘
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼ YES                                   ▼ NO (Requires OS SDK / C++ / Driver)
     ┌───────────────────────┐               ┌─────────────────────────────────────┐
     │ 100% Pure Dart Rewrite │               │ Interoperability Strategy:          │
     │ (Portable, testable,  │               └──────────────────┬──────────────────┘
     │ zero bridging overhead)│                                  │
     └───────────────────────┘          ┌────────────────────────┼────────────────────────┐
                                        ▼                        ▼                        ▼
                              ┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
                              │ Cross-Platform IPC│    │ In-Process Native │    │ Embedded Native UI│
                              │ (Asynchronous)    │    │ (Synchronous FFI) │    │ (Platform Views)  │
                              ├───────────────────┤    ├───────────────────┤    ├───────────────────┤
                              │ package:pigeon    │    │ Dart FFI (C/ObjC) │    │ AndroidView       │
                              │ Generates typesafe│    │ via package:ffigen│    │ UiKitView         │
                              │ Swift, Obj-C, Java│    │ or package:jni    │    │ For map engines,  │
                              │ & Kotlin bridges. │    │ for Java/Kotlin.  │    │ complex webviews. │
                              └───────────────────┘    └───────────────────┘    └───────────────────┘
```

---

## Universal Migration Workflow

Follow this step-by-step checklist to migrate modules systematically:

- [ ] **Step 1: Audit and Categorize Source Code**
  - Identify domain models, business logic/services, UI screens, and hardware/platform dependencies.
  - Separate candidates for 100% Dart rewrite from code requiring native bridging.
- [ ] **Step 2: Read Language-Specific Reference**
  - Read [reference/android.md](reference/android.md), [reference/kotlin.md](reference/kotlin.md), [reference/swift.md](reference/swift.md), or [reference/objective-c.md](reference/objective-c.md).
- [ ] **Step 3: Convert Data Models & Business Logic**
  - Translate native structs/classes/POJOs to immutable Dart classes with `final` fields, `const` constructors, and `fromJson`/`toJson` methods.
  - Implement algebraic data types using Dart 3 `sealed class` hierarchies.
- [ ] **Step 4: Translate Asynchronous & Concurrency Workflows**
  - Replace GCD queues, Android Handlers, Threads, Coroutines, and completion blocks with `Future<T>`, `Stream<T>`, and `async`/`await`.
  - Offload heavy CPU processing to `Isolate.run()`.
- [ ] **Step 5: Translate UI to Declarative Flutter Widgets**
  - Convert ViewControllers, Activities, Fragments, Compose functions, or XML layouts into `StatelessWidget` or `StatefulWidget`.
  - Compose layouts using `Scaffold`, `AppBar`, `Column`, `Row`, `Stack`, and `ListView.builder`.
- [ ] **Step 6: Implement Native Interop (If Retaining Code)**
  - Define Pigeon interface specifications (`pigeon/schema.dart`) and generate bridges.
  - For embedded native views, wrap with `AndroidView` or `UiKitView`.
- [ ] **Step 7: Validation and Testing**
  - Ensure all controllers (`TextEditingController`, `AnimationController`, `ScrollController`) and subscriptions are disposed in `State.dispose()`.
  - Run `dart analyze` to verify zero static analysis errors and warnings.
  - Write and run unit and widget tests: `flutter test`.

---

## Universal Pitfalls & Gotchas

1. **Redundant UI Thread Dispatching**:
   - *Mistake*: Calling platform channel methods or awaiting futures, then attempting to dispatch back to the "main thread".
   - *Correction*: In Dart, code that resumes after `await` on the root isolate runs directly on the platform UI thread.

2. **Leaking Controller and Subscription Resources**:
   - *Mistake*: Creating `TextEditingController`, `AnimationController`, or `StreamSubscription` without cleaning them up.
   - *Correction*: Always override `State.dispose()` and dispose all controllers, timers, and subscriptions.

3. **Overusing Deep Widget Trees Instead of Builder Patterns**:
   - *Mistake*: Mapping `UITableView` or `RecyclerView` by mapping an entire collection into children: `Column(children: list.map(...).toList())`.
   - *Correction*: Always use `ListView.builder` or `GridView.builder` to enable virtualization and render object recycling.

4. **Public Mutable Getters and Sound Null Safety Promotion**:
   - *Mistake*: Expecting a public getter to type-promote after a null-check: `if (obj.field != null) print(obj.field.length);`.
   - *Correction*: Dart cannot promote public getters because a subclass could override them. Assign to a local variable first: `final f = obj.field; if (f != null) print(f.length);`.

---

## Migration Verification Checklist

Before finalizing any native-to-Flutter migration, verify:

- [ ] **Sound Null Safety**: All variables and parameters have strict types with zero unsafe `!` force-unwraps.
- [ ] **Memory & Resource Disposal**: Every controller, stream subscription, and timer is disposed in `State.dispose()`.
- [ ] **Asynchronous Safety**: No blocking computations on the root isolate; CPU-heavy work is delegated to `Isolate.run()`.
- [ ] **Zero Static Analysis Errors**: `dart analyze` reports 0 issues.
- [ ] **Automated Test Coverage**: Unit tests for models/repositories and widget tests for screens pass via `flutter test`.
