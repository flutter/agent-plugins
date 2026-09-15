# Android Kotlin & Mixed Kotlin/Java to Flutter Migration Guide (`flutter-kotlin-java-to-flutter`)

## Contents
- [Overview & Core Paradigms](#kotlin-overview--core-paradigms)
- [Language & Syntax Mapping (Kotlin to Dart)](#kotlin-to-dart-language--syntax-mapping)
  - [Data Classes vs Immutable Classes](#data-classes-vs-immutable-classes)
  - [Sealed Classes and Interfaces vs Dart 3 Sealed Classes](#sealed-classes-and-interfaces-vs-dart-3-sealed-classes)
  - [Null Safety Semantics (Smart Casts vs Flow Promotion)](#null-safety-semantics-smart-casts-vs-flow-promotion)
  - [Extension Functions and Extension Properties](#extension-functions-and-extension-properties)
  - [Collections and Higher-Order Functions](#collections-and-higher-order-functions)
  - [Singletons, Objects, and Companion Objects](#singletons-objects-and-companion-objects)
  - [Property Delegation vs Dart Patterns](#property-delegation-vs-dart-patterns)
- [Concurrency: Coroutines & Flow to Dart](#concurrency-coroutines--flow-to-dart)
  - [suspend Functions and CoroutineScope vs Future and async/await](#suspend-functions-and-coroutinescope-vs-future-and-asyncawait)
  - [Dispatchers.Main vs Root UI Isolate](#dispatchersmain-vs-root-ui-isolate)
  - [Dispatchers.Default vs Isolate.run](#dispatchersdefault-vs-isolaterun)
  - [Flow, StateFlow, and SharedFlow vs Stream and ValueNotifier](#flow-stateflow-and-sharedflow-vs-stream-and-valuenotifier)
- [UI Architecture: Jetpack Compose & XML to Flutter Widgets](#ui-architecture-jetpack-compose--xml-to-flutter-widgets)
  - [Composable Functions vs Widget Trees](#composable-functions-vs-widget-trees)
  - [Layout Primitives Comparison Table](#kotlin-layout-primitives-comparison-table)
  - [Compose Modifiers vs Widget Composition](#compose-modifiers-vs-widget-composition)
  - [Lazy Lists (LazyColumn / LazyRow) vs ListView.builder](#lazy-lists-lazycolumn--lazyrow-vs-listviewbuilder)
  - [State Observation: collectAsState vs ListenableBuilder](#state-observation-collectasstate-vs-listenablebuilder)
  - [Jetpack Compose to Flutter Component Equivalents](#jetpack-compose-to-flutter-component-equivalents)
- [Android Subsystems & Modern Jetpack Libraries](#kotlin-android-subsystems--modern-jetpack-libraries)
  - [Room with Coroutines to Drift / Sqflite](#room-with-coroutines-to-drift--sqflite)
  - [DataStore & EncryptedSharedPreferences](#datastore--encryptedsharedpreferences)
  - [Ktor Client & Retrofit to dio / http](#ktor-client--retrofit-to-dio--http)
  - [Dependency Injection: Hilt & Koin to get_it / Riverpod](#dependency-injection-hilt--koin-to-getit--riverpod)
  - [Navigation-Compose to GoRouter](#navigation-compose-to-gorouter)
- [Native Interoperability Strategies (When Keeping Kotlin/Java Code)](#kotlin-native-interoperability-strategies)
  - [Pigeon Code Generation for Type-Safe Kotlin IPC](#pigeon-code-generation-for-type-safe-kotlin-ipc)
  - [In-Process Calls via package:jni](#in-process-calls-via-packagejni)
  - [Platform Views for Custom Android Views and Compose](#platform-views-for-custom-android-views-and-compose)
- [Step-by-Step Migration Workflow](#kotlin-step-by-step-migration-workflow)
- [Concrete Migration Examples](#kotlin-concrete-migration-examples)
  - [Example 1: Kotlin Data Class & Sealed Hierarchy to Dart 3 Model](#kotlin-example-1-kotlin-data-class--sealed-hierarchy-to-dart-3-model)
  - [Example 2: Coroutine Flow Repository to Dart Async Stream Service](#kotlin-example-2-coroutine-flow-repository-to-dart-async-stream-service)
  - [Example 3: Jetpack Compose Screen with StateFlow to Flutter Widget](#kotlin-example-3-jetpack-compose-screen-with-stateflow-to-flutter-widget)
- [Common Pitfalls & Anti-Patterns](#kotlin-common-pitfalls--anti-patterns)
- [Migration Verification Checklist](#kotlin-migration-verification-checklist)

---

## Kotlin Overview & Core Paradigms

Modern Android applications written in Kotlin (often using Jetpack Compose, Kotlin Coroutines, and Flow) share strong philosophical similarities with Flutter: both embrace **declarative UI**, **unidirectional data flow (UDF)**, and **strong static typing**.

```
Android Kotlin / Jetpack Compose
┌────────────────────────────────────────────────────────┐
│ • Declarative @Composable functions emit UI layout    │
│ • State-driven recomposition via State<T> / StateFlow  │
│ • Coroutines (suspend fun) with structured concurrency │
│ • Kotlin compiler plugin generates Compose group keys  │
│ • Renders through Android View hierarchy or Compose canvas
└────────────────────────────────────────────────────────┘
                           │
                           ▼ Architectural Synergy
Flutter / Dart
┌────────────────────────────────────────────────────────┐
│ • Declarative Widget tree returned from build(context) │
│ • State-driven rebuilds via setState / Listenable      │
│ • Event loop with non-blocking Future and Stream       │
│ • Multi-platform engine renders directly via Impeller  │
│ • Hot Reload delivers instantaneous sub-second iteration
└────────────────────────────────────────────────────────┘
```

---

## Language & Syntax Mapping (Kotlin to Dart)

### Data Classes vs Immutable Classes

Kotlin `data class` automatically synthesizes `equals`, `hashCode`, `toString`, `componentN()`, and `copy()`. In Dart:
- Write an immutable class with `const` constructors, `final` fields, and `copyWith()`.
- Or use `package:freezed` / Dart 3 records `(String id, String title)`.

```kotlin
// Kotlin: Data class
data class UserProfile(
    val id: String,
    val username: String,
    val email: String,
    val isActive: Boolean = true
)
```

```dart
// Dart: Immutable class with copyWith
class UserProfile {
  final String id;
  final String username;
  final String email;
  final bool isActive;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.isActive = true,
  });

  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    bool? isActive,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          email == other.email &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(id, username, email, isActive);
}
```

### Sealed Classes and Interfaces vs Dart 3 Sealed Classes

Kotlin sealed hierarchies (`sealed class` / `sealed interface`) map directly to **Dart 3 `sealed class` hierarchies** with exhaustive pattern matching:

```kotlin
// Kotlin: Sealed class hierarchy
sealed interface UiState<out T> {
    object Idle : UiState<Nothing>
    object Loading : UiState<Nothing>
    data class Success<T>(val data: T) : UiState<T>
    data class Error(val message: String) : UiState<Nothing>
}

fun renderUi(state: UiState<List<String>>) = when (state) {
    is UiState.Idle -> "Ready"
    is UiState.Loading -> "Loading..."
    is UiState.Success -> "Loaded ${state.data.size} items"
    is UiState.Error -> "Error: ${state.message}"
}
```

```dart
// Dart 3: Sealed class hierarchy with exhaustive pattern matching
sealed class UiState<T> {
  const UiState();
}

class Idle<T> extends UiState<T> {
  const Idle();
}

class Loading<T> extends UiState<T> {
  const Loading();
}

class Success<T> extends UiState<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends UiState<T> {
  final String message;
  const Failure(this.message);
}

String renderUi(UiState<List<String>> state) => switch (state) {
      Idle() => 'Ready',
      Loading() => 'Loading...',
      Success(:final data) => 'Loaded ${data.length} items',
      Failure(:final message) => 'Error: $message',
    };
```

### Null Safety Semantics (Smart Casts vs Flow Promotion)

Both Kotlin and Dart feature first-class Sound Null Safety:

| Feature | Kotlin | Dart |
|---|---|---|
| Non-nullable type | `String` | `String` |
| Nullable type | `String?` | `String?` |
| Safe call | `user?.name` | `user?.name` |
| Fallback / Elvis | `name ?: "Anonymous"` | `name ?? 'Anonymous'` |
| Force unwrap | `user!!` | `user!` |
| Smart Cast / Promotion | `if (user != null) user.name` | `if (user != null) user.name` |

```kotlin
// Kotlin: Smart cast
fun formatLength(input: String?): Int {
    if (input == null) return 0
    return input.length // Smart cast to non-nullable String
}
```

```dart
// Dart: Flow-sensitive type promotion
int formatLength(String? input) {
  if (input == null) return 0;
  return input.length; // Promoted to non-nullable String
}
```

### Extension Functions and Extension Properties

```kotlin
// Kotlin: Extension functions & properties
fun String.isValidEmail(): Boolean = contains("@") && contains(".")
val String.wordCount: Int get() = split("\\s+".toRegex()).size
```

```dart
// Dart: Extension methods & getters
extension StringValidation on String {
  bool get isValidEmail => contains('@') && contains('.');
  int get wordCount => trim().split(RegExp(r'\s+')).length;
}
```

### Collections and Higher-Order Functions

```kotlin
// Kotlin: Higher-order functions
val activeUserEmails = users
    .filter { it.isActive }
    .map { it.email.lowercase() }
    .sorted()
```

```dart
// Dart: Fluent Iterable methods
final activeUserEmails = (users
    .where((u) => u.isActive)
    .map((u) => u.email.toLowerCase())
    .toList()
  ..sort());
```

### Singletons, Objects, and Companion Objects

- Kotlin `object NetworkConstants { const val TIMEOUT = 30L }` $\rightarrow$ Dart top-level constants (`const timeoutSeconds = 30;`).
- Kotlin `companion object` factory methods $\rightarrow$ Dart named or factory constructors (`factory MyClass.fromJson(...)`).

### Property Delegation vs Dart Patterns

- Kotlin `by lazy { ... }` $\rightarrow$ Dart `late final value = ...` (computes lazily on first access).
- Kotlin `by viewModels()` $\rightarrow$ Dart `Provider.of<T>(context)`, `ref.watch(...)` in Riverpod, or `GetIt.I<T>()`.

---

## Concurrency: Coroutines & Flow to Dart

### suspend Functions and CoroutineScope vs Future and async/await

- **Kotlin Coroutines**: `suspend fun` functions pause execution without blocking OS threads, requiring a `CoroutineScope` (`viewModelScope.launch { ... }`).
- **Dart Concurrency**: Standard functions marked `async` returning `Future<T>`. All Dart code within an isolate runs cooperatively on a single event loop without thread synchronization primitives.

```kotlin
// Kotlin: Coroutine ViewModel
class NewsViewModel(private val repository: NewsRepository) : ViewModel() {
    var articles by mutableStateOf<List<Article>>(emptyList())
        private set

    fun loadArticles() {
        viewModelScope.launch {
            try {
                articles = repository.fetchArticles() // Suspend execution
            } catch (e: Exception) {
                Log.e("News", "Error", e)
            }
        }
    }
}
```

```dart
// Dart & Flutter: ChangeNotifier ViewModel
class NewsViewModel extends ChangeNotifier {
  final NewsRepository _repository;
  List<Article> _articles = [];

  NewsViewModel({NewsRepository? repository})
      : _repository = repository ?? NewsRepository();

  List<Article> get articles => _articles;

  Future<void> loadArticles() async {
    try {
      _articles = await _repository.fetchArticles();
      notifyListeners();
    } on Exception catch (e) {
      debugPrint('Error: $e');
    }
  }
}
```

### Dispatchers.Main vs Root UI Isolate

In Kotlin Coroutines, network or database results must be consumed on `Dispatchers.Main` to update UI state. In Flutter, **the root isolate is already the UI platform thread**; any code resuming after `await` automatically runs on the main UI isolate!

### Dispatchers.Default vs Isolate.run

For **CPU-intensive tasks** (e.g. cryptographic computations, large JSON decoding, image processing):

```kotlin
// Kotlin: withContext(Dispatchers.Default)
suspend fun parseBigPayload(bytes: ByteArray): ParsedResult = withContext(Dispatchers.Default) {
    heavyParsingAlgorithm(bytes)
}
```

```dart
// Dart: Isolate.run offloads to worker isolate
Future<ParsedResult> parseBigPayload(Uint8List bytes) async {
  return await Isolate.run(() => heavyParsingAlgorithm(bytes));
}
```

### Flow, StateFlow, and SharedFlow vs Stream and ValueNotifier

| Kotlin Coroutines / Flow | Dart / Flutter Equivalent |
|---|---|
| `Flow<T>` (Cold stream) | `Stream<T>` (asynchronous sequence via `async*`) |
| `StateFlow<T>` (Hot state holder) | `ValueNotifier<T>` or `BehaviorSubject<T>` (`package:rxdart`) |
| `SharedFlow<T>` (Hot event bus) | `StreamController<T>.broadcast()` |
| `flow.collect { ... }` | `await for (final val in stream)` or `stream.listen(...)` |
| `flow.map { ... }.filter { ... }` | `stream.map(...).where(...)` |
| `flow.debounce(300)` | `stream.debounceTime(Duration(milliseconds: 300))` (`rxdart`) |

---

## UI Architecture: Jetpack Compose & XML to Flutter Widgets

### Composable Functions vs Widget Trees

Both Jetpack Compose and Flutter build UI declaratively from code:

```kotlin
// Jetpack Compose: @Composable function
@Composable
fun MetricBadge(label: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = label, style = MaterialTheme.typography.labelSmall)
        Spacer(modifier = Modifier.height(4.dp))
        Text(text = value, style = MaterialTheme.typography.titleMedium)
    }
}
```

```dart
// Flutter: Composed Widget
class MetricBadge extends StatelessWidget {
  final String label;
  final String value;

  const MetricBadge({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4.0),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
```

### Layout Primitives Comparison Table

| Jetpack Compose | Flutter Equivalent | Notes |
|---|---|---|
| `Column(verticalArrangement, horizontalAlignment)` | `Column(mainAxisAlignment, crossAxisAlignment)` | Vertical flex container |
| `Row(horizontalArrangement, verticalAlignment)` | `Row(mainAxisAlignment, crossAxisAlignment)` | Horizontal flex container |
| `Box(contentAlignment)` | `Stack` or `Container` | Layered layout |
| `Spacer(Modifier.weight(1f))` | `Spacer()` | Flexible expanding space |
| `Spacer(Modifier.height(8.dp))` | `SizedBox(height: 8.0)` | Fixed dimensional spacing |
| `Divider()` | `Divider()` | Rule separator |
| `LazyColumn { items(list) { ... } }` | `ListView.builder(itemCount: ..., itemBuilder: ...)` | Virtualized vertical list |
| `LazyRow { items(list) { ... } }` | `ListView.builder(scrollDirection: Axis.horizontal, ...)` | Virtualized horizontal list |
| `LazyVerticalGrid(GridCells.Fixed(2))` | `GridView.builder(gridDelegate: ...)` | Virtualized grid |
| `Scaffold(topBar = { ... })` | `Scaffold(appBar: ...)` | Screen structure |

### Compose Modifiers vs Widget Composition

In Compose, modifications are chained onto a single `Modifier` pipeline. In Flutter, modifications are expressed through nested widget composition:

```kotlin
// Jetpack Compose Modifier chain
Box(
    modifier = Modifier
        .fillMaxWidth()
        .height(100.dp)
        .padding(16.dp)
        .clip(RoundedCornerShape(12.dp))
        .background(Color.Blue)
        .clickable { handleTap() }
)
```

```dart
// Flutter: Widget composition
Padding(
  padding: const EdgeInsets.all(16.0),
  child: SizedBox(
    width: double.infinity,
    height: 100.0,
    child: Material(
      color: Colors.blue,
      borderRadius: BorderRadius.circular(12.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: handleTap,
        child: const SizedBox.expand(),
      ),
    ),
  ),
)
```

### State Observation: collectAsState vs ListenableBuilder

```kotlin
// Jetpack Compose: collectAsStateWithLifecycle
@Composable
fun TaskListScreen(viewModel: TaskViewModel = viewModel()) {
    val tasks by viewModel.tasks.collectAsStateWithLifecycle()
    LazyColumn {
        items(tasks) { task -> TaskItem(task) }
    }
}
```

```dart
// Flutter: ListenableBuilder with ChangeNotifier
class TaskListScreen extends StatelessWidget {
  final TaskViewModel viewModel;
  const TaskListScreen({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final tasks = viewModel.tasks;
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) => TaskItem(task: tasks[index]),
        );
      },
    );
  }
}
```

### Jetpack Compose to Flutter Component Equivalents

| Jetpack Compose | Flutter (Material 3) Equivalent |
|---|---|
| `Text("Hello")` | `Text('Hello')` |
| `Button(onClick = { ... }) { ... }` | `ElevatedButton(onPressed: ..., child: ...)` |
| `OutlinedButton(...)` | `OutlinedButton(...)` |
| `TextButton(...)` | `TextButton(...)` |
| `IconButton(onClick = { ... }) { Icon(...) }` | `IconButton(onPressed: ..., icon: Icon(...))` |
| `TextField(value, onValueChange)` | `TextField(controller: controller)` |
| `OutlinedTextField(...)` | `TextFormField(decoration: InputDecoration(border: OutlineInputBorder()))` |
| `Switch(checked, onCheckedChange)` | `Switch(value: checked, onChanged: ...)` |
| `Checkbox(checked, onCheckedChange)` | `Checkbox(value: checked, onChanged: ...)` |
| `CircularProgressIndicator()` | `CircularProgressIndicator()` |
| `LinearProgressIndicator()` | `LinearProgressIndicator()` |
| `Card { ... }` | `Card(child: ...)` |
| `TopAppBar(title = { Text("...") })` | `AppBar(title: Text('...'))` |
| `NavigationBar { NavigationBarItem(...) }` | `NavigationBar(destinations: [...])` |
| `ModalBottomSheet(...)` | `showModalBottomSheet(context: context, builder: ...)` |
| `AlertDialog(...)` | `showDialog(context: context, builder: (_) => AlertDialog(...))` |

---

## Android Subsystems & Modern Jetpack Libraries

| Kotlin / Android Jetpack Library | Flutter / Dart Equivalent |
|---|---|
| `Room` (Entity, Dao, Database) | `package:drift` (Type-safe reactive SQLite ORM) or `package:sqflite` |
| `DataStore` (Preferences) | `package:shared_preferences` |
| `EncryptedSharedPreferences` / KeyStore | `package:flutter_secure_storage` |
| `Retrofit` / `Ktor Client` | `package:dio` or `package:http` |
| `Kotlinx.serialization` / `Moshi` | `fromJson`/`toJson` or `package:json_serializable` |
| `Hilt` / `Koin` | `package:get_it` or Riverpod providers |
| `Coil` / `Glide` | `Image.network()` or `package:cached_network_image` |
| `Navigation-Compose` / Jetpack Navigation | `package:go_router` or `Navigator` |
| `WorkManager` | `package:workmanager` |
| `CameraX` | `package:camera` |
| `Accompanist Permissions` | `package:permission_handler` |

---

## Native Interoperability Strategies (When Keeping Kotlin/Java Code)

When migrating complex enterprise Android applications, migrate iteratively using native interop:

```
Kotlin / Java Migration Strategy:
1. UI & Domain Logic ─────────> Rewrite in 100% Dart & Flutter (Cross-platform)
2. Native Hardware / SDKs:
   ├── Type-Safe IPC ─────────> Pigeon (package:pigeon generates Kotlin & Dart contracts)
   ├── In-Process Java/Kotlin ─> package:jni (Direct Java Native Interface)
   └── Existing Custom View ──> AndroidView (Platform View via Texture Layer Hybrid Composition)
```

### Pigeon Code Generation for Type-Safe Kotlin IPC

`package:pigeon` generates clean Kotlin classes and Dart interfaces:

```dart
// pigeons/sensor_api.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/sensor_api.g.dart',
  kotlinOut: 'android/app/src/main/kotlin/com/example/app/SensorApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.example.app'),
))
@HostApi()
abstract class SensorNativeApi {
  double getLightLevel();
  void calibrateSensor();
}
```

Implement in Kotlin (`android/app/src/main/kotlin/com/example/app/SensorApiImpl.kt`):
```kotlin
package com.example.app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager

class SensorApiImpl(private val context: Context) : SensorNativeApi {
    private var lastLightValue: Double = 0.0

    override fun getLightLevel(): Double {
        return lastLightValue
    }

    override fun calibrateSensor() {
        // Calibration logic
    }
}
```

Register in `MainActivity.kt`:
```kotlin
package com.example.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SensorNativeApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            SensorApiImpl(this)
        )
    }
}
```

---

## Kotlin Step-by-Step Migration Workflow

Follow this procedure when migrating a Kotlin or mixed Kotlin/Java Android project:

**Phase 1: Architecture & Dependency Inventory**
- [ ] Catalog `.kt` and `.java` files:
  - Data models (`data class`, `enum`, `sealed class`)
  - Repositories and DataSources (Room, Retrofit/Ktor, DataStore)
  - Business logic (ViewModels, UseCases, CoroutineScopes)
  - UI (Compose `@Composable` functions, XML layouts, Fragments)
  - Gradle dependencies (`build.gradle.kts` / `libs.versions.toml`)

**Phase 2: Data Models & Serialization**
- [ ] Convert Kotlin `data class` into immutable Dart classes with `copyWith` and `const` constructors.
- [ ] Convert `sealed class` / `sealed interface` to Dart 3 `sealed class` with pattern matching.
- [ ] Implement `fromJson` and `toJson` factory methods.

**Phase 3: Asynchronous Services & Concurrency**
- [ ] Convert Coroutine `suspend fun` to Dart `async`/`await` functions returning `Future<T>`.
- [ ] Replace `Dispatchers.Default` with `Isolate.run()` for heavy computations.
- [ ] Convert Kotlin `Flow` and `StateFlow` to Dart `Stream<T>` and `ValueNotifier<T>`.

**Phase 4: State Management & ViewModels**
- [ ] Map Jetpack `ViewModel` to `ChangeNotifier` + `ListenableBuilder` (or Riverpod / BLoC).
- [ ] Replace `MutableStateFlow` with properties calling `notifyListeners()`.

**Phase 5: Declarative UI Conversion**
- [ ] Convert Compose `@Composable` functions to `StatelessWidget` or `StatefulWidget`.
- [ ] Map layout trees (`Column`, `Row`, `Box`, `Spacer`, `LazyColumn`) to Flutter equivalents.
- [ ] Convert Compose modifiers into nested widget wrappers.
- [ ] Replicate styling with Material 3 `ThemeData` and `ColorScheme`.

**Phase 6: Platform Integration (if needed)**
- [ ] If proprietary Android SDKs must be retained, implement `package:pigeon` bindings.

**Phase 7: Testing & Verification**
- [ ] Port JUnit & Mockk unit tests to Dart `package:test`.
- [ ] Port Compose UI tests (`composeTestRule`) to Flutter widget tests (`testWidgets`).
- [ ] Run `dart analyze` to guarantee zero static analysis errors.

---

## Kotlin Concrete Migration Examples

### Kotlin Example 1: Kotlin Data Class & Sealed Hierarchy to Dart 3 Model

#### Kotlin Source Code
```kotlin
// Transaction.kt
package com.example.models

import kotlinx.serialization.Serializable

@Serializable
sealed interface TransactionStatus {
    @Serializable
    object Pending : TransactionStatus
    
    @Serializable
    data class Completed(val transactionHash: String) : TransactionStatus
    
    @Serializable
    data class Failed(val errorCode: Int, val reason: String) : TransactionStatus
}

@Serializable
data class Transaction(
    val id: String,
    val amount: Double,
    val recipient: String,
    val status: TransactionStatus
)
```

#### Dart 3 & Flutter Equivalent
```dart
// transaction.dart
sealed class TransactionStatus {
  const TransactionStatus();

  factory TransactionStatus.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'pending' => const PendingStatus(),
      'completed' => CompletedStatus(json['hash'] as String),
      'failed' => FailedStatus(
          errorCode: json['error_code'] as int,
          reason: json['reason'] as String,
        ),
      _ => throw FormatException('Unknown transaction status: $type'),
    };
  }

  Map<String, dynamic> toJson();
}

class PendingStatus extends TransactionStatus {
  const PendingStatus();
  @override
  Map<String, dynamic> toJson() => {'type': 'pending'};
}

class CompletedStatus extends TransactionStatus {
  final String transactionHash;
  const CompletedStatus(this.transactionHash);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'completed',
        'hash': transactionHash,
      };
}

class FailedStatus extends TransactionStatus {
  final int errorCode;
  final String reason;

  const FailedStatus({required this.errorCode, required this.reason});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'failed',
        'error_code': errorCode,
        'reason': reason,
      };
}

class Transaction {
  final String id;
  final double amount;
  final String recipient;
  final TransactionStatus status;

  const Transaction({
    required this.id,
    required this.amount,
    required this.recipient,
    required this.status,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      recipient: json['recipient'] as String,
      status: TransactionStatus.fromJson(
        json['status'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'recipient': recipient,
      'status': status.toJson(),
    };
  }
}
```

---

### Kotlin Example 2: Coroutine Flow Repository to Dart Async Stream Service

#### Kotlin Source Code
```kotlin
// TransactionRepository.kt
package com.example.repository

import com.example.models.Transaction
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.request.*

class TransactionRepository(private val client: HttpClient) {
    suspend fun getTransactions(): List<Transaction> {
        return client.get("https://api.example.com/v1/transactions").body()
    }

    fun pollRecentTransactions(intervalMs: Long = 5000): Flow<List<Transaction>> = flow {
        while (true) {
            emit(getTransactions())
            delay(intervalMs)
        }
    }
}
```

#### Dart & Flutter Equivalent
```dart
// transaction_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'transaction.dart';

class TransactionRepository {
  final http.Client _client;
  final Uri _endpoint = Uri.https('api.example.com', '/v1/transactions');

  TransactionRepository({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<Transaction>> getTransactions() async {
    final response = await _client.get(_endpoint);

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Failed to fetch transactions: ${response.statusCode}',
        _endpoint,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Expected JSON list of transactions');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Transaction.fromJson)
        .toList();
  }

  Stream<List<Transaction>> pollRecentTransactions({
    Duration interval = const Duration(seconds: 5),
  }) async* {
    while (true) {
      yield await getTransactions();
      await Future<void>.delayed(interval);
    }
  }

  void dispose() {
    _client.close();
  }
}
```

---

### Kotlin Example 3: Jetpack Compose Screen with StateFlow to Flutter Widget

#### Kotlin / Jetpack Compose Source Code
```kotlin
// TransactionListScreen.kt
package com.example.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.models.Transaction
import com.example.models.TransactionStatus
import com.example.repository.TransactionRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class TransactionViewModel(private val repository: TransactionRepository) : ViewModel() {
    private val _transactions = MutableStateFlow<List<Transaction>>(emptyList())
    val transactions: StateFlow<List<Transaction>> = _transactions.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                _transactions.value = repository.getTransactions()
            } finally {
                _isLoading.value = false
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionListScreen(viewModel: TransactionViewModel) {
    val transactions by viewModel.transactions.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.load()
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text("Transactions") }) }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            } else {
                LazyColumn(modifier = Modifier.fillMaxSize()) {
                    items(transactions) { tx ->
                        ListItem(
                            headlineContent = { Text(tx.recipient) },
                            supportingContent = { Text(formatStatus(tx.status)) },
                            trailingContent = { Text("$${tx.amount}") }
                        )
                        Divider()
                    }
                }
            }
        }
    }
}

fun formatStatus(status: TransactionStatus): String = when (status) {
    is TransactionStatus.Pending -> "Pending"
    is TransactionStatus.Completed -> "Completed"
    is TransactionStatus.Failed -> "Failed: ${status.reason}"
}
```

#### Flutter & Dart Equivalent
```dart
// transaction_list_screen.dart
import 'package:flutter/material.dart';
import 'transaction.dart';
import 'transaction_repository.dart';

class TransactionViewModel extends ChangeNotifier {
  final TransactionRepository _repository;
  List<Transaction> _transactions = [];
  bool _isLoading = false;

  TransactionViewModel({TransactionRepository? repository})
      : _repository = repository ?? TransactionRepository();

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await _repository.getTransactions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final _viewModel = TransactionViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_viewModel.transactions.isEmpty) {
            return const Center(child: Text('No transactions available.'));
          }

          return ListView.separated(
            itemCount: _viewModel.transactions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tx = _viewModel.transactions[index];
              return ListTile(
                title: Text(tx.recipient),
                subtitle: Text(_formatStatus(tx.status)),
                trailing: Text(
                  '\$${tx.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatStatus(TransactionStatus status) {
    return switch (status) {
      PendingStatus() => 'Pending',
      CompletedStatus() => 'Completed',
      FailedStatus(:final reason) => 'Failed: $reason',
    };
  }
}
```

---

## Kotlin Common Pitfalls & Anti-Patterns

1. **Unnecessary Thread Dispatching**:
   - *Anti-Pattern*: Trying to switch back to a "main dispatcher" after calling an asynchronous API.
   - *Correction*: Dart code resuming after `await` already executes on the main UI isolate. Only use `Isolate.run()` for heavy CPU processing.

2. **Forgetting to Dispose State Resources**:
   - *Anti-Pattern*: Creating `StreamSubscription`, `TextEditingController`, or `AnimationController` without canceling or disposing them.
   - *Correction*: Always override `State.dispose()` in `StatefulWidget` and clean up controllers and subscriptions.

3. **Structural vs Reference Equality**:
   - *In Kotlin*: `data class` synthesizes structural `equals`.
   - *In Dart*: Classes use reference equality by default unless overridden (`operator ==` and `hashCode`) or generated via `package:freezed`.

4. **Shadowing Mutable Getters for Type Promotion**:
   - In Dart, public mutable getters cannot be promoted by null-checks (since a subclass could override the getter). Shadow to a local variable: `final val = mutableGetter; if (val != null) { ... }`.

---

## Kotlin Migration Verification Checklist

Before considering a Kotlin/Java Android to Flutter migration complete, verify:

- [ ] **Sound Null Safety**: All models and functions strictly adhere to Dart null safety with zero unverified `!` force-unwraps.
- [ ] **Sealed Classes & Exhaustiveness**: State representations and algebraic types use Dart 3 `sealed class` hierarchies with compiler-checked pattern matching.
- [ ] **Resource Disposal**: All controllers, timers, and stream subscriptions are cleaned up in `dispose()`.
- [ ] **Non-Blocking Concurrency**: All network and database operations use `async` / `await`. Heavy CPU computations use `Isolate.run()`.
- [ ] **Zero Static Analysis Warnings**: Run `dart analyze` across the package and verify 0 errors and 0 warnings.
- [ ] **Automated Test Coverage**:
  - Unit tests verify models and services: `flutter test test/models/ test/services/`
  - Widget tests verify screen layout and interactions: `flutter test test/screens/`
- [ ] **Platform Interoperability**: If using `package:pigeon` for native Kotlin bridging, verify Android builds compile cleanly via Gradle (`flutter build apk --debug`).



