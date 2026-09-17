# Android Java to Flutter Migration Guide (`flutter-android-java-to-flutter`)

## Contents
- [Overview & Core Paradigms](#android-overview--core-paradigms)
- [Language & Syntax Mapping (Java to Dart)](#java-to-dart-language--syntax-mapping)
  - [Classes, Interfaces, and Mixins](#classes-interfaces-and-mixins)
  - [Constructors, Initializers, and Named Constructors](#constructors-initializers-and-named-constructors)
  - [Getters, Setters, and Encapsulation](#getters-setters-and-encapsulation)
  - [Null Safety vs NullPointerException](#null-safety-vs-nullpointerexception)
  - [Collections and Streams API Mapping](#collections-and-streams-api-mapping)
  - [Anonymous Classes vs First-Class Functions](#anonymous-classes-vs-first-class-functions)
  - [Enums and Constant Sets](#enums-and-constant-sets)
- [Concurrency: Android Threads & Handlers to Dart](#concurrency-android-threads--handlers-to-dart)
  - [Thread, ExecutorService, and Handler vs Dart Event Loop](#thread-executorservice-and-handler-vs-dart-event-loop)
  - [runOnUiThread vs Automatic Main Isolate Resumption](#runonuithread-vs-automatic-main-isolate-resumption)
  - [Heavy Background Work: Isolate.run vs Background Threads](#heavy-background-work-isolaterun-vs-background-threads)
  - [RxJava to Dart Streams and RxDart](#rxjava-to-dart-streams-and-rxdart)
- [UI Architecture: Android Views & XML to Flutter](#ui-architecture-android-views--xml-to-flutter)
  - [Activity / Fragment Lifecycle to StatefulWidget Lifecycle](#activity--fragment-lifecycle-to-statefulwidget-lifecycle)
  - [XML Layout ViewGroups to Flutter Layout Widgets](#xml-layout-viewgroups-to-flutter-layout-widgets)
  - [RecyclerView & ViewHolder to ListView.builder](#recyclerview--viewholder-to-listviewbuilder)
  - [Component Equivalents Table](#android-component-equivalents-table)
  - [Themes, Colors, and Drawables to BoxDecoration & ThemeData](#themes-colors-and-drawables-to-boxdecoration--themedata)
- [Android Architecture & Subsystem Mapping](#android-architecture--subsystem-mapping)
  - [ViewModel & LiveData to ChangeNotifier / Riverpod](#viewmodel--livedata-to-changenotifier--riverpod)
  - [SharedPreferences & KeyStore](#sharedpreferences--keystore)
  - [Room & SQLiteDatabase to sqflite / drift](#room--sqlitedatabase-to-sqflite--drift)
  - [Retrofit & OkHttp to package:http / dio](#retrofit--okhttp-to-packagehttp--dio)
  - [Intents (Internal & External)](#intents-internal--external)
- [Native Interoperability Strategies (When Keeping Java Code)](#native-interoperability-strategies-when-keeping-java-code)
  - [Pigeon Code Generation for Type-Safe Java IPC](#pigeon-code-generation-for-type-safe-java-ipc)
  - [Direct In-Process Interop via package:jni](#direct-in-process-interop-via-packagejni)
  - [Platform Views (AndroidView)](#platform-views-androidview)
- [Step-by-Step Migration Workflow](#android-step-by-step-migration-workflow)
- [Concrete Migration Examples](#android-concrete-migration-examples)
  - [Example 1: POJO Model with Gson to Dart Model with fromJson/toJson](#android-example-1-pojo-model-with-gson-to-dart-model-with-fromjsontojson)
  - [Example 2: Retrofit/OkHttp Service with Callback to Dart Async Service](#android-example-2-retrofitokhttp-service-with-callback-to-dart-async-service)
  - [Example 3: Activity with RecyclerView & ViewModel to Flutter StatefulWidget](#android-example-3-activity-with-recyclerview--viewmodel-to-flutter-statefulwidget)
- [Common Pitfalls & Anti-Patterns](#android-common-pitfalls--anti-patterns)
- [Migration Verification Checklist](#android-migration-verification-checklist)

---

## Android Overview & Core Paradigms

Migrating from native Android (Java) to Flutter involves transitioning from a **multi-component, XML-bound, imperative framework** to a **unified, declarative widget tree**:

```
Android Java Architecture (Imperative & XML-driven)
┌──────────────────────────────────────────────────────────────┐
│ • Layouts declared in XML: res/layout/activity_main.xml       │
│ • Component lifecycle: Activity / Fragment / Service         │
│ • Imperative mutation: findViewById -> textView.setText(...) │
│ • Multi-threading: Handler, Looper, runOnUiThread(...)       │
│ • Manifest registration for every screen and permission      │
└──────────────────────────────────────────────────────────────┘
                               │
                               ▼ Paradigm Shift
Flutter / Dart Architecture (Declarative & Code-driven)
┌──────────────────────────────────────────────────────────────┐
│ • UI = f(state): Declarative widget tree inside build()      │
│ • Everything is a Widget (layout, styling, animations)       │
│ • Single-threaded isolate event loop (no runOnUiThread)     │
│ • Lightweight element tree diffing via Skia / Impeller       │
│ • Single-entry point: void main() => runApp(const MyApp())   │
└──────────────────────────────────────────────────────────────┘
```

---

## Java to Dart Language & Syntax Mapping

### Classes, Interfaces, and Mixins

- **In Java**: Interfaces require explicit `implements`, and classes can only extend one superclass. Default methods exist, but true mixin composition is unavailable.
- **In Dart**: **Every class implicitly defines an interface**. Multiple interfaces can be implemented without `interface` keywords. Reusable behavior across class hierarchies is achieved via **`mixin`**.

```java
// Java: Interface and Class
public interface Identifiable {
    String getId();
}

public class User extends BaseEntity implements Identifiable {
    private final String id;
    private String name;

    public User(String id, String name) {
        this.id = id;
        this.name = name;
    }

    @Override
    public String getId() {
        return id;
    }
}
```

```dart
// Dart: Class implementing implicit interface and using mixin
abstract interface class Identifiable {
  String get id;
}

mixin TimestampMixin {
  DateTime createdAt = DateTime.now();
  bool get isRecent => DateTime.now().difference(createdAt).inDays < 7;
}

class User extends BaseEntity with TimestampMixin implements Identifiable {
  @override
  final String id;
  String name;

  User({
    required this.id,
    required this.name,
  });
}
```

### Constructors, Initializers, and Named Constructors

Java requires verbose assignment boilerplate (`this.field = field;`) and method overloading for constructors. Dart provides **initializing formals**, **named constructors**, and **factory constructors**:

```java
// Java: Constructor overloading
public class Product {
    private final String id;
    private final String title;
    private final double price;

    public Product(String id, String title, double price) {
        this.id = id;
        this.title = title;
        this.price = price;
    }

    public Product(String id, String title) {
        this(id, title, 0.0);
    }
}
```

```dart
// Dart: Initializing formals & named constructors
class Product {
  final String id;
  final String title;
  final double price;

  // Generative constructor with default value
  const Product({
    required this.id,
    required this.title,
    this.price = 0.0,
  });

  // Named constructor
  const Product.free({
    required this.id,
    required this.title,
  }) : price = 0.0;
}
```

### Getters, Setters, and Encapsulation

Java uses boilerplate getters and setters (`getId()`, `setId(...)`). In Dart:
- Public fields automatically provide implicit getters and setters.
- Custom getters and setters can be introduced later without changing the public contract.
- Privacy is library-scoped via a leading underscore (`_`).

```java
// Java: Getters and setters
public class Counter {
    private int count = 0;

    public int getCount() {
        return count;
    }

    public void setCount(int count) {
        if (count >= 0) {
            this.count = count;
        }
    }
}
```

```dart
// Dart: Idiomatic getters and setters
class Counter {
  int _count = 0;

  int get count => _count;
  set count(int value) {
    if (value >= 0) {
      _count = value;
    }
  }
}
```

### Null Safety vs NullPointerException

- In Java, any object reference can be `null`, resulting in frequent `NullPointerException` (NPE) crashes at runtime.
- In Dart, **Sound Null Safety** guarantees that non-nullable types (`String`) can never be `null`. Nullable types (`String?`) require explicit handling.

```java
// Java: Defensive null checks
public String formatUser(User user) {
    if (user != null) {
        String name = user.getName();
        if (name != null) {
            return name.trim();
        }
    }
    return "Guest";
}
```

```dart
// Dart: Sound Null Safety with null-aware operators
String formatUser(User? user) {
  return user?.name.trim() ?? 'Guest';
}
```

### Collections and Streams API Mapping

| Java Collection / API | Dart Equivalent | Notes |
|---|---|---|
| `java.util.List<T>` / `ArrayList` | `List<T>` | Literal: `[1, 2, 3]` |
| `java.util.Map<K, V>` / `HashMap` | `Map<K, V>` | Literal: `{'key': 'value'}` |
| `java.util.Set<T>` / `HashSet` | `Set<T>` | Literal: `{1, 2, 3}` |
| `Collections.unmodifiableList(...)` | `List.unmodifiable(...)` | Read-only wrapper |
| `list.stream().filter(p).collect(...)` | `list.where(p).toList()` | Dart Iterable methods |
| `list.stream().map(f).collect(...)` | `list.map(f).toList()` | Lazy transformation |
| `list.stream().findFirst().orElse(d)` | `list.firstWhere(p, orElse: () => d)` | Search element |
| `list.stream().reduce(0, Integer::sum)` | `list.fold(0, (sum, val) => sum + val)` | Aggregation |

```java
// Java: Streams API
List<String> activeNames = users.stream()
    .filter(User::isActive)
    .map(User::getName)
    .sorted()
    .collect(Collectors.toList());
```

```dart
// Dart: Fluent Iterables
final activeNames = (users
    .where((u) => u.isActive)
    .map((u) => u.name)
    .toList()
  ..sort());
```

### Anonymous Classes vs First-Class Functions

Java uses anonymous classes (e.g. `new View.OnClickListener() { ... }`) or lambda expressions. In Dart, functions are first-class objects:

```java
// Java: Event Listener
button.setOnClickListener(new View.OnClickListener() {
    @Override
    public void onClick(View v) {
        submitForm();
    }
});
```

```dart
// Dart: First-class function callback
ElevatedButton(
  onPressed: submitForm,
  child: const Text('Submit'),
)
```

### Enums and Constant Sets

Java uses `public enum Status`. Dart supports **Enhanced Enums** with properties, constructors, and methods, as well as Dart 3 **`sealed class`** hierarchies for pattern-matching state machines.

```java
// Java: Enum with properties
public enum Priority {
    LOW(1), MEDIUM(2), HIGH(3);

    private final int level;
    Priority(int level) { this.level = level; }
    public int getLevel() { return level; }
}
```

```dart
// Dart: Enhanced Enum
enum Priority {
  low(1),
  medium(2),
  high(3);

  final int level;
  const Priority(this.level);

  bool get isUrgent => level == 3;
}
```

---

## Concurrency: Android Threads & Handlers to Dart

### Thread, ExecutorService, and Handler vs Dart Event Loop

In Android Java:
- CPU and I/O work are dispatched to background threads using `ExecutorService`, `ThreadPoolExecutor`, or `Thread`.
- To modify Views, background threads must post Runnables back to the main thread via `Handler` or `Activity.runOnUiThread(...)`.

In Flutter:
- The **main isolate** processes all UI building, rendering coordination, and user events on a single thread.
- Asynchronous I/O (network calls, database operations, file reads) is non-blocking via `Future` and `async`/`await`.
- Code that resumes after `await` **already executes on the main UI isolate**. No `Handler` or `runOnUiThread` is needed!

```
Android Java Multi-threading:
[Main Thread] ──> ExecutorService ──> [Worker Thread (I/O or CPU)]
                                              │
[Main Thread] <── Handler.post(Runnable) <────┘

Dart Event Loop:
[Root Isolate UI Thread] ──> await http.get() (non-blocking OS I/O)
                                   │
[Root Isolate UI Thread] <─────────┘ (resumes on main thread automatically!)
```

### runOnUiThread vs Automatic Main Isolate Resumption

```java
// Android Java
new Thread(new Runnable() {
    @Override
    public void run() {
        final String result = networkService.fetchData();
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                textView.setText(result);
            }
        });
    }
}).start();
```

```dart
// Dart & Flutter
final result = await networkService.fetchData();
// Automatically resumes on main thread!
setState(() {
  _statusText = result;
});
```

### Heavy Background Work: Isolate.run vs Background Threads

For **heavy CPU-bound operations** (e.g. image processing, large JSON decryption/parsing, cryptographic hashing):

```java
// Java: ExecutorService background execution
ExecutorService executor = Executors.newSingleThreadExecutor();
Handler mainHandler = new Handler(Looper.getMainLooper());

executor.execute(() -> {
    byte[] compressed = processImage(rawBytes);
    mainHandler.post(() -> updateImageView(compressed));
});
```

```dart
// Dart: Isolate.run transfers execution to a worker isolate
final compressed = await Isolate.run(() => processImage(rawBytes));
updateImageView(compressed);
```

### RxJava to Dart Streams and RxDart

| RxJava | Dart Streams / RxDart |
|---|---|
| `Observable<T>` / `Flowable<T>` | `Stream<T>` |
| `Single<T>` | `Future<T>` |
| `Completable` | `Future<void>` |
| `PublishSubject<T>` | `StreamController<T>.broadcast()` |
| `BehaviorSubject<T>` | `BehaviorSubject<T>` (`package:rxdart`) or `ValueNotifier<T>` |
| `Schedulers.io()` | Unnecessary (Dart I/O is non-blocking) |
| `AndroidSchedulers.mainThread()` | Unnecessary (resumes on root isolate) |
| `.subscribe(onSuccess, onError)` | `stream.listen((v) => ..., onError: (e) => ...)` |
| `CompositeDisposable` | `List<StreamSubscription>` cancelled in `dispose()` |

---

## UI Architecture: Android Views & XML to Flutter

### Activity / Fragment Lifecycle to StatefulWidget Lifecycle

```
Android Activity / Fragment         Flutter State<T>
┌───────────────────────────┐       ┌───────────────────────────┐
│ onCreate(Bundle saved)    │ ───>  │ void initState()          │
│                           │       │                           │
│ onStart() / onResume()    │ ───>  │ didChangeDependencies()   │
│                           │       │ didChangeAppLifecycleState│
│                           │       │                           │
│ onCreateView() / XML      │ ───>  │ Widget build(context)     │
│                           │       │                           │
│ onPause() / onStop()      │ ───>  │ didChangeAppLifecycleState│
│                           │       │                           │
│ onDestroy()               │ ───>  │ void dispose()            │
└───────────────────────────┘       └───────────────────────────┘
```

### XML Layout ViewGroups to Flutter Layout Widgets

In Android, layouts are defined in XML files with constraint equations or nested ViewGroups. In Flutter, layout is achieved using composable widgets:

```xml
<!-- Android XML: LinearLayout (Vertical) -->
<LinearLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="vertical"
    android:padding="16dp">

    <TextView
        android:id="@+id/title"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Welcome"
        android:textSize="20sp" />

    <Button
        android:id="@+id/action_btn"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:text="Continue" />
</LinearLayout>
```

```dart
// Flutter: Composed Widget Tree
Padding(
  padding: const EdgeInsets.all(16.0),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Welcome',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8.0),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _handleContinue,
          child: const Text('Continue'),
        ),
      ),
    ],
  ),
)
```

### RecyclerView & ViewHolder to ListView.builder

In Android, displaying a list requires `RecyclerView.Adapter`, inflating XML item layouts, maintaining `RecyclerView.ViewHolder` instances, and binding data in `onBindViewHolder`.

In Flutter, the framework automatically handles render object recycling under the hood. You simply provide an `itemCount` and an `itemBuilder`:

```java
// Android Java: RecyclerView.Adapter & ViewHolder
public class UserAdapter extends RecyclerView.Adapter<UserAdapter.ViewHolder> {
    private List<User> users;

    public static class ViewHolder extends RecyclerView.ViewHolder {
        public TextView nameView;
        public ViewHolder(View v) {
            super(v);
            nameView = v.findViewById(R.id.user_name);
        }
    }

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_user, parent, false);
        return new ViewHolder(v);
    }

    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        holder.nameView.setText(users.get(position).getName());
    }

    @Override
    public int getItemCount() {
        return users.size();
    }
}
```

```dart
// Flutter: ListView.builder
ListView.builder(
  itemCount: users.length,
  itemBuilder: (context, index) {
    final user = users[index];
    return ListTile(
      title: Text(user.name),
      onTap: () => _onUserSelected(user),
    );
  },
)
```

### Component Equivalents Table

| Android Java (XML / Views) | Flutter (Dart) | Notes |
|---|---|---|
| `Activity` / `Fragment` | `StatefulWidget` or `StatelessWidget` returning `Scaffold` | Screen foundation |
| `TextView` | `Text('...')` / `RichText` | Text display |
| `Button` / `MaterialButton` | `ElevatedButton`, `FilledButton`, `TextButton` | Buttons with callbacks |
| `ImageView` | `Image.asset('...')`, `Image.network('...')` | Image rendering |
| `EditText` | `TextField(controller: ...)` / `TextFormField` | Text input field |
| `CheckBox` | `Checkbox(value: ..., onChanged: ...)` | Checkbox control |
| `Switch` / `SwitchCompat` | `Switch(value: ..., onChanged: ...)` | Toggle control |
| `ProgressBar` (circular) | `CircularProgressIndicator()` | Loading indicator |
| `ProgressBar` (horizontal) | `LinearProgressIndicator()` | Linear progress |
| `LinearLayout (vertical)` | `Column(children: [...])` | Vertical layout |
| `LinearLayout (horizontal)` | `Row(children: [...])` | Horizontal layout |
| `FrameLayout` | `Stack(children: [...])` | Overlapping layout |
| `RelativeLayout` / `ConstraintLayout` | `Stack` + `Positioned` or composed `Row`/`Column` | Positioned layout |
| `ScrollView` | `SingleChildScrollView(child: ...)` | Scrolling view |
| `RecyclerView` / `ListView` | `ListView.builder(...)` | Virtualized list |
| `GridLayout` | `GridView.builder(...)` | Virtualized grid |
| `AlertDialog` / `DialogFragment` | `showDialog(builder: (_) => AlertDialog(...))` | Dialog modals |
| `BottomSheetDialog` | `showModalBottomSheet(...)` | Bottom modal |
| `Toast` / `Snackbar` | `ScaffoldMessenger.of(context).showSnackBar(...)` | Brief notification message |
| `Toolbar` / `ActionBar` | `AppBar(title: Text('...'))` | App top bar |
| `BottomNavigationView` | `NavigationBar` or `BottomNavigationBar` | Tab bar navigation |
| `ViewPager2` | `PageView(children: [...])` / `PageView.builder` | Paged swipeable views |

### Themes, Colors, and Drawables to BoxDecoration & ThemeData

- **Android XML Drawables** (`res/drawable/bg_rounded.xml`): Replaced by `BoxDecoration` (`color`, `borderRadius`, `border`, `gradient`, `boxShadow`).
- **Styles & Themes** (`res/values/themes.xml`): Replaced by `ThemeData` (`colorScheme`, `textTheme`, `appBarTheme`).

```xml
<!-- Android XML: Rounded rectangle drawable -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#2196F3" />
    <corners android:radius="8dp" />
    <stroke android:width="1dp" android:color="#1976D2" />
</shape>
```

```dart
// Flutter: BoxDecoration equivalent
DecoratedBox(
  decoration: BoxDecoration(
    color: const Color(0xFF2196F3),
    borderRadius: BorderRadius.circular(8.0),
    border: Border.all(color: const Color(0xFF1976D2), width: 1.0),
  ),
  child: const Padding(
    padding: EdgeInsets.all(12.0),
    child: Text('Rounded Box'),
  ),
)
```

---

## Android Architecture & Subsystem Mapping

### ViewModel & LiveData to ChangeNotifier / Riverpod

Android developers commonly follow the Android Architecture Components (AAC) pattern with `ViewModel` and `LiveData` or `StateFlow`. In Flutter:
- `ViewModel` maps to a class extending **`ChangeNotifier`**.
- `LiveData` / `StateFlow` values map to properties on the `ChangeNotifier` that invoke **`notifyListeners()`**.
- Observers map to Flutter's **`ListenableBuilder`** (or Riverpod `ConsumerWidget` / BLoC `BlocBuilder`).

```java
// Android Java: AAC ViewModel with MutableLiveData
public class TaskViewModel extends ViewModel {
    private final MutableLiveData<List<Task>> tasks = new MutableLiveData<>(new ArrayList<>());
    private final TaskRepository repository;

    public TaskViewModel(TaskRepository repository) {
        this.repository = repository;
    }

    public LiveData<List<Task>> getTasks() {
        return tasks;
    }

    public void loadTasks() {
        repository.getTasks(new Callback<List<Task>>() {
            @Override
            public void onResponse(List<Task> data) {
                tasks.setValue(data); // Main thread update
            }
        });
    }
}
```

```dart
// Flutter: ChangeNotifier ViewModel
class TaskViewModel extends ChangeNotifier {
  final TaskRepository _repository;
  List<Task> _tasks = [];
  bool _isLoading = false;

  TaskViewModel({TaskRepository? repository})
      : _repository = repository ?? TaskRepository();

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _repository.getTasks();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### SharedPreferences & KeyStore

- `SharedPreferences` $\rightarrow$ `package:shared_preferences` (`await SharedPreferences.getInstance()`).
- Android KeyStore / `EncryptedSharedPreferences` $\rightarrow$ `package:flutter_secure_storage` (hardware-backed Keystore encryption).

### Room & SQLiteDatabase to sqflite / drift

- Android `Room` with `@Entity`, `@Dao`, and `@Database` maps directly to:
  - **`package:sqflite`**: Direct SQLite queries and database helpers.
  - **`package:drift`**: Type-safe reactive SQLite ORM with code generation, migrations, and stream-based queries.

### Retrofit & OkHttp to package:http / dio

In Android Java, Retrofit interfaces define HTTP endpoints. In Dart:
- Use **`package:http`** for lightweight REST requests.
- Use **`package:dio`** for advanced features (interceptors, request cancellation, file uploads, global error handling).

### Intents (Internal & External)

- **Internal Activity Navigation** (`startActivity(new Intent(this, DetailActivity.class))`): Replaced by `Navigator.push(...)` or `GoRouter.of(context).go(...)`.
- **External System Intents** (opening browser, dialing phone, sending email, sharing text): Replaced by **`package:url_launcher`** (`launchUrl(Uri.parse('https://...'))`) and **`package:share_plus`**.

---

## Native Interoperability Strategies (When Keeping Java Code)

When migrating an enterprise Android Java app, certain proprietary modules (e.g. custom hardware SDKs, legacy NDK libraries, enterprise authentication) can be retained using native interop:

```
Android Java Migration Strategy:
1. UI & Standard Business Logic ──> Rewrite in 100% Dart & Flutter (Cross-platform)
2. Native Android SDK / Library:
   ├── High-level API calls ────> Pigeon (type-safe Java & Dart IPC code generation)
   ├── In-process Java calls ───> package:jni (direct Java Native Interface bindings)
   └── Complex Custom View ─────> AndroidView (Platform View via Texture Layer Hybrid Composition)
```

### Pigeon Code Generation for Type-Safe Java IPC

`package:pigeon` generates Java interfaces and Dart client classes:

```dart
// pigeons/battery_api.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/battery_api.g.dart',
  javaOut: 'android/app/src/main/java/com/example/app/BatteryApi.g.java',
  javaOptions: JavaOptions(package: 'com.example.app'),
))
@HostApi()
abstract class BatteryNativeApi {
  int getBatteryPercentage();
  bool isCharging();
}
```

Implement in Java (`android/app/src/main/java/com/example/app/BatteryApiImpl.java`):
```java
package com.example.app;

import android.content.Context;
import android.os.BatteryManager;

public class BatteryApiImpl implements BatteryApi.BatteryNativeApi {
    private final Context context;

    public BatteryApiImpl(Context context) {
        this.context = context;
    }

    @Override
    public Long getBatteryPercentage() {
        BatteryManager bm = (BatteryManager) context.getSystemService(Context.BATTERY_SERVICE);
        return (long) bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
    }

    @Override
    public Boolean isCharging() {
        BatteryManager bm = (BatteryManager) context.getSystemService(Context.BATTERY_SERVICE);
        int status = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS);
        return status == BatteryManager.BATTERY_STATUS_CHARGING;
    }
}
```

Register in `MainActivity.java`:
```java
public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        BatteryApi.BatteryNativeApi.setup(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            new BatteryApiImpl(getContext())
        );
    }
}
```

---

## Android Step-by-Step Migration Workflow

Follow this systematic procedure when porting an Android Java project:

**Phase 1: Architecture & Dependencies Inventory**
- [ ] Catalog all Java source files and XML resources:
  - Models / Entities / POJOs
  - Data layer: Room DAOs, SQLite helpers, Retrofit interfaces, SharedPreferences
  - Business logic: ViewModels, Presenters, Services, BroadcastReceivers
  - UI: Activities, Fragments, Custom Views, XML layouts, drawables
  - Gradle dependencies (`build.gradle`)
- [ ] Map Gradle dependencies to [pub.dev](https://pub.dev) equivalents (e.g. Retrofit $\rightarrow$ `dio`, Glide $\rightarrow$ `cached_network_image`, Room $\rightarrow$ `drift`).

**Phase 2: Data Models & Serialization**
- [ ] Convert Java POJO classes to immutable Dart classes.
- [ ] Implement `fromJson` and `toJson` serialization.
- [ ] Replace Java nullability annotations with strict Dart sound null safety.

**Phase 3: Networking & Persistence Layer**
- [ ] Convert Retrofit API interfaces to Dart service classes using `package:http` or `package:dio`.
- [ ] Replace `Room` / `SQLiteDatabase` with `package:sqflite` or `package:drift`.
- [ ] Replace `SharedPreferences` with `package:shared_preferences`.

**Phase 4: State Management & ViewModels**
- [ ] Convert Android `ViewModel` + `LiveData` to `ChangeNotifier` + `ListenableBuilder` (or Riverpod / BLoC).
- [ ] Replace `runOnUiThread` calls with Dart's natural async/await main-isolate execution.

**Phase 5: UI Construction (Declarative Widgets)**
- [ ] Convert `Activity` / `Fragment` into `StatefulWidget` or `StatelessWidget`.
- [ ] Rebuild XML layouts using Flutter flex widgets (`Column`, `Row`, `Expanded`, `Stack`).
- [ ] Replace `RecyclerView` with `ListView.builder` or `GridView.builder`.
- [ ] Port `themes.xml` and `colors.xml` to `ThemeData` and `ColorScheme`.

**Phase 6: Platform Integration & Bridging**
- [ ] If proprietary hardware SDKs or legacy Android Java libraries are required, generate bridge code via `package:pigeon`.
- [ ] Configure `android/app/src/main/AndroidManifest.xml` for necessary hardware permissions (e.g. Camera, Location, Bluetooth).

**Phase 7: Testing & Verification**
- [ ] Port JUnit tests to Dart unit tests (`flutter test test/models/ test/services/`).
- [ ] Write widget tests (`flutter test test/screens/`) verifying UI state rendering and interaction.
- [ ] Run `dart analyze` to guarantee 0 errors and 0 warnings.

---

## Android Concrete Migration Examples

### Android Example 1: POJO Model with Gson to Dart Model with fromJson/toJson

#### Android Java (POJO with Gson)
```java
// Article.java
package com.example.models;

import com.google.gson.annotations.SerializedName;
import java.util.Objects;

public class Article {
    @SerializedName("id")
    private final String id;

    @SerializedName("title")
    private final String title;

    @SerializedName("view_count")
    private final int viewCount;

    @SerializedName("published_at")
    private final String publishedAt;

    public Article(String id, String title, int viewCount, String publishedAt) {
        this.id = id;
        this.title = title;
        this.viewCount = viewCount;
        this.publishedAt = publishedAt;
    }

    public String getId() { return id; }
    public String getTitle() { return title; }
    public int getViewCount() { return viewCount; }
    public String getPublishedAt() { return publishedAt; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Article article = (Article) o;
        return viewCount == article.viewCount &&
               Objects.equals(id, article.id) &&
               Objects.equals(title, article.title) &&
               Objects.equals(publishedAt, article.publishedAt);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id, title, viewCount, publishedAt);
    }
}
```

#### Dart & Flutter Equivalent
```dart
// article.dart
class Article {
  final String id;
  final String title;
  final int viewCount;
  final DateTime publishedAt;

  const Article({
    required this.id,
    required this.title,
    required this.viewCount,
    required this.publishedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'view_count': viewCount,
      'published_at': publishedAt.toIso8601String(),
    };
  }

  Article copyWith({
    String? id,
    String? title,
    int? viewCount,
    DateTime? publishedAt,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      viewCount: viewCount ?? this.viewCount,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          viewCount == other.viewCount &&
          publishedAt == other.publishedAt;

  @override
  int get hashCode => Object.hash(id, title, viewCount, publishedAt);
}
```

---

### Android Example 2: Retrofit/OkHttp Service with Callback to Dart Async Service

#### Android Java (Retrofit2 Service)
```java
// ArticleApi.java
package com.example.network;

import com.example.models.Article;
import java.util.List;
import retrofit2.Call;
import retrofit2.http.GET;

public interface ArticleApi {
    @GET("v1/articles")
    Call<List<Article>> getArticles();
}

// ArticleRepository.java
package com.example.network;

import com.example.models.Article;
import java.util.List;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;

public class ArticleRepository {
    private final ArticleApi api;

    public interface RepositoryCallback {
        void onSuccess(List<Article> articles);
        void onError(Throwable throwable);
    }

    public ArticleRepository() {
        Retrofit retrofit = new Retrofit.Builder()
            .baseUrl("https://api.example.com/")
            .addConverterFactory(GsonConverterFactory.create())
            .build();
        this.api = retrofit.create(ArticleApi.class);
    }

    public void fetchArticles(final RepositoryCallback callback) {
        api.getArticles().enqueue(new Callback<List<Article>>() {
            @Override
            public void onResponse(Call<List<Article>> call, Response<List<Article>> response) {
                if (response.isSuccessful() && response.body() != null) {
                    callback.onSuccess(response.body());
                } else {
                    callback.onError(new Exception("HTTP Error: " + response.code()));
                }
            }

            @Override
            public void onFailure(Call<List<Article>> call, Throwable t) {
                callback.onError(t);
            }
        });
    }
}
```

#### Dart & Flutter Equivalent
```dart
// article_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'article.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

class ArticleRepository {
  final http.Client _client;
  final Uri _endpoint = Uri.https('api.example.com', '/v1/articles');

  ArticleRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Article>> fetchArticles() async {
    final response = await _client.get(_endpoint);

    if (response.statusCode != 200) {
      throw ApiException('Failed to load articles', response.statusCode);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Expected JSON list of articles');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Article.fromJson)
        .toList();
  }

  void dispose() {
    _client.close();
  }
}
```

---

### Android Example 3: Activity with RecyclerView & ViewModel to Flutter StatefulWidget

#### Android Java (Activity & XML)
```java
// ArticleListActivity.java
package com.example.ui;

import android.os.Bundle;
import android.view.View;
import android.widget.ProgressBar;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.DividerItemDecoration;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.example.R;

public class ArticleListActivity extends AppCompatActivity {
    private ArticleViewModel viewModel;
    private ProgressBar progressBar;
    private TextView errorText;
    private RecyclerView recyclerView;
    private ArticleAdapter adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_article_list);

        setTitle("Articles");
        progressBar = findViewById(R.id.progress_bar);
        errorText = findViewById(R.id.error_text);
        recyclerView = findViewById(R.id.recycler_view);

        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        recyclerView.addItemDecoration(new DividerItemDecoration(this, DividerItemDecoration.VERTICAL));
        adapter = new ArticleAdapter();
        recyclerView.setAdapter(adapter);

        viewModel = new ViewModelProvider(this).get(ArticleViewModel.class);

        viewModel.getIsLoading().observe(this, isLoading -> {
            progressBar.setVisibility(isLoading ? View.VISIBLE : View.GONE);
        });

        viewModel.getErrorMessage().observe(this, error -> {
            if (error != null) {
                errorText.setVisibility(View.VISIBLE);
                errorText.setText(error);
            } else {
                errorText.setVisibility(View.GONE);
            }
        });

        viewModel.getArticles().observe(this, articles -> {
            adapter.setArticles(articles);
        });

        viewModel.loadArticles();
    }
}
```

#### Flutter & Dart Equivalent
```dart
// article_list_screen.dart
import 'package:flutter/material.dart';
import 'article.dart';
import 'article_repository.dart';

class ArticleViewModel extends ChangeNotifier {
  final ArticleRepository _repository;
  List<Article> _articles = [];
  bool _isLoading = false;
  String? _errorMessage;

  ArticleViewModel({ArticleRepository? repository})
      : _repository = repository ?? ArticleRepository();

  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadArticles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _articles = await _repository.fetchArticles();
    } on Exception catch (e) {
      _errorMessage = e.toString();
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

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  final _viewModel = ArticleViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.loadArticles();
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
        title: const Text('Articles'),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_viewModel.errorMessage != null) {
            return Center(
              child: Text(
                _viewModel.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (_viewModel.articles.isEmpty) {
            return const Center(child: Text('No articles available.'));
          }

          return ListView.separated(
            itemCount: _viewModel.articles.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final article = _viewModel.articles[index];
              return ListTile(
                title: Text(article.title),
                subtitle: Text('Views: ${article.viewCount}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to article details
                },
              );
            },
          );
        },
      ),
    );
  }
}
```

---

## Android Common Pitfalls & Anti-Patterns

1. **Attempting Imperative View Lookups (`findViewById`)**:
   - *Anti-Pattern*: Trying to store widget references in member variables to update their properties later (`titleWidget.text = 'new'`).
   - *Correction*: Widgets are lightweight immutable configuration blueprints. Pass state changes down into constructors and trigger rebuilds using `setState()` or `ChangeNotifier`.

2. **Unnecessary Manual Threading & `runOnUiThread`**:
   - *Anti-Pattern*: Spawning background threads or Handlers for asynchronous I/O (network or database queries).
   - *Correction*: Dart asynchronous I/O (`Future`, `async`/`await`) is non-blocking on the single-threaded event loop and automatically resumes on the UI thread. Use `Isolate.run()` solely for heavy CPU-bound computation.

3. **Leaking Listeners, Controllers, and Streams**:
   - *Anti-Pattern*: Forgetting to cancel `StreamSubscription`, `TextEditingController`, or `AnimationController` instances.
   - *Correction*: Always override `State.dispose()` and call `.dispose()` or `.cancel()`.

4. **Ignoring the Android Back Button**:
   - *Anti-Pattern*: Assuming navigation backstack works without configuring back navigation on Android.
   - *Correction*: Use `PopScope` to intercept hardware back-button presses when handling confirmation dialogs or unsaved changes.

5. **Hardcoding Density-Independent Pixels (`dp`) instead of Flex**:
   - *Anti-Pattern*: Hardcoding absolute widths and heights on containers to match Android XML `layout_width="200dp"`.
   - *Correction*: Use `Expanded`, `Flexible`, `LayoutBuilder`, or `MediaQuery` to create responsive layouts that adapt across multiple screen sizes.

---

## Android Migration Verification Checklist

Before considering an Android Java to Flutter migration complete, verify:

- [ ] **Sound Null Safety**: All data models and services enforce non-nullable types with zero unverified `!` force-unwraps.
- [ ] **Declarative Architecture**: No imperative view mutations; state is held in `StatefulWidget`, `ChangeNotifier`, Riverpod, or BLoC.
- [ ] **Lifecycle Resource Cleanup**: All `TextEditingController`, `AnimationController`, and `StreamSubscription` instances are closed in `dispose()`.
- [ ] **Non-Blocking Concurrency**: All network and database operations use `async` / `await`. Heavy CPU algorithms use `Isolate.run()`.
- [ ] **Android Hardware Back Handling**: Forms and multi-step dialogs correctly integrate with `PopScope` for hardware back-button navigation.
- [ ] **Zero Static Analysis Warnings**: Run `dart analyze` across the package and verify 0 errors and 0 warnings.
- [ ] **Automated Test Coverage**:
  - Unit tests verify domain models and services: `flutter test test/models/ test/services/`
  - Widget tests verify screen layout and interactions: `flutter test test/screens/`
- [ ] **Android Platform Build Check**: Run `flutter build apk --debug` to confirm clean Gradle compilation and manifest configuration.

---
---

