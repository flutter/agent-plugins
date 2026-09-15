# Objective-C to Dart & Flutter Migration Guide

## Contents
- [Overview & Core Paradigms](#overview--core-paradigms)
- [Language & Syntax Mapping](#language--syntax-mapping)
  - [Headers, Implementations, and Imports](#headers-implementations-and-imports)
  - [Classes, Constructors, and Initializers](#classes-constructors-and-initializers)
  - [Properties and Encapsulation](#properties-and-encapsulation)
  - [Protocols vs Abstract Classes / Interfaces / Mixins](#protocols-vs-abstract-classes--interfaces--mixins)
  - [Categories vs Extension Methods](#categories-vs-extension-methods)
  - [Blocks vs Closures & First-Class Functions](#blocks-vs-closures--first-class-functions)
  - [Selectors, Enums, and Bitmasks](#selectors-enums-and-bitmasks)
- [Memory Management: ARC vs Garbage Collection](#memory-management-arc-vs-garbage-collection)
- [Foundation and Core Types Conversion](#foundation-and-core-types-conversion)
  - [Scalar and Numeric Types](#scalar-and-numeric-types)
  - [Strings and String Manipulation](#strings-and-string-manipulation)
  - [Collections (NSArray, NSDictionary, NSSet)](#collections-nsarray-nsdictionary-nsset)
  - [Dates, URLs, and Binary Buffers](#dates-urls-and-binary-buffers)
  - [Error Handling (NSError vs Exceptions/Errors)](#error-handling-nserror-vs-exceptionserrors)
- [Concurrency: Grand Central Dispatch (GCD) to Dart](#concurrency-grand-central-dispatch-gcd-to-dart)
  - [Event Loop vs OS Threads](#event-loop-vs-os-threads)
  - [Main Queue Dispatching vs UI Microtasks](#main-queue-dispatching-vs-ui-microtasks)
  - [Background Queues vs Isolates](#background-queues-vs-isolates)
  - [Dispatch Groups vs Future.wait](#dispatch-groups-vs-futurewait)
- [UI Architecture: UIKit to Flutter](#ui-architecture-uikit-to-flutter)
  - [Imperative UI vs Declarative Reactive Tree](#imperative-ui-vs-declarative-reactive-tree)
  - [UIViewController Lifecycle to StatefulWidget Lifecycle](#uiviewcontroller-lifecycle-to-statefulwidget-lifecycle)
  - [Auto Layout vs BoxConstraints](#auto-layout-vs-boxconstraints)
  - [Component Equivalents Table](#component-equivalents-table)
  - [UITableView/UICollectionView vs ListView/GridView](#uitableviewuicollectionview-vs-listviewgridview)
  - [Navigation and Routing](#navigation-and-routing)
- [iOS Subsystems & Native Services](#ios-subsystems--native-services)
- [Interoperability Strategies: When Not to Rewrite](#interoperability-strategies-when-not-to-rewrite)
  - [Dart FFI with Objective-C Support (package:ffigen)](#dart-ffi-with-objective-c-support-packageffigen)
  - [Pigeon Code Generation](#pigeon-code-generation)
  - [Standard Platform Channels](#standard-platform-channels)
  - [Platform Views (UiKitView)](#platform-views-uikitview)
- [Step-by-Step Migration Workflow](#step-by-step-migration-workflow)
- [Concrete Migration Examples](#concrete-migration-examples)
  - [Example 1: Data Model with JSON Serialization](#example-1-data-model-with-json-serialization)
  - [Example 2: Asynchronous Network Service](#example-2-asynchronous-network-service)
  - [Example 3: Table View Controller to Flutter ListView](#example-3-table-view-controller-to-flutter-listview)
- [Common Pitfalls & Anti-Patterns](#common-pitfalls--anti-patterns)
- [Migration Verification Checklist](#migration-verification-checklist)

---

## Overview & Core Paradigms

Migrating from native iOS (Objective-C / UIKit) to cross-platform Flutter (Dart) requires shifting from an **imperative, object-graph mutation model** to a **declarative, reactive widget tree model**.

```
Objective-C / UIKit (Imperative)
┌──────────────────────────────────────────┐
│  Create UIView / UIViewController        │
│  Add subview: [parent addSubview:child]  │
│  Mutate in-place: label.text = @"Hello"  │
│  Auto Layout constraints equation solver │
└──────────────────────────────────────────┘
                    │
                    ▼ Paradigm Shift
Dart / Flutter (Declarative)
┌──────────────────────────────────────────┐
│  UI = f(state)                           │
│  Widgets are immutable blueprints        │
│  Rebuild on state change (setState / BLoC│
│  BoxConstraints: Constraints down,       │
│  sizes up, parent sets position          │
└──────────────────────────────────────────┘
```

### Key Conceptual Differences
1. **Dynamic Message Dispatch vs Statically Typed AOT/JIT**:
   - Objective-C resolves method calls at runtime via `objc_msgSend`. Sending a message to `nil` returns `nil` or `0` without an exception.
   - Dart is statically typed with sound null safety. Calling a method on a `null` reference throws a compile error or `NoSuchMethodError` at runtime unless guarded with `?.`.
2. **Compilation Units**:
   - Objective-C splits definitions into headers (`.h`) and implementations (`.m`).
   - Dart uses unified `.dart` files where privacy is library-scoped using a leading underscore (`_`).
3. **Execution Runtime**:
   - Objective-C runs on Darwin POSIX threads with Grand Central Dispatch (GCD) and manual/ARC memory management.
   - Dart runs inside an isolate governed by a single-threaded event loop and a generational garbage collector.

---

## Language & Syntax Mapping

### Headers, Implementations, and Imports

| Objective-C | Dart | Notes |
|---|---|---|
| `#import <Foundation/Foundation.h>` | `import 'dart:core';` (implicit) | Dart automatically imports core libraries |
| `#import "MyClass.h"` | `import 'my_class.dart';` | Direct file import |
| `@class ForwardClass;` | Not required | Dart resolves circular references within compilation units |
| `@public`, `@private`, `@protected` | Leading `_` for library-private | Identifiers starting with `_` are private to their Dart library/file |

```objc
// Objective-C: User.h
#import <Foundation/Foundation.h>

@interface User : NSObject
@property (nonatomic, copy, readonly) NSString *userId;
@property (nonatomic, copy) NSString *name;
- (instancetype)initWithUserId:(NSString *)userId name:(NSString *)name;
- (BOOL)isValid;
@end
```

```dart
// Dart: user.dart
class User {
  final String userId;
  String name;

  User({
    required this.userId,
    required this.name,
  });

  bool get isValid => userId.isNotEmpty && name.isNotEmpty;
}
```

### Classes, Constructors, and Initializers

- Objective-C divides object creation into memory allocation (`+alloc`) and initialization (`-init...`).
- Dart features first-class generative constructors, named constructors, factory constructors, and initializing formals (`this.field`).

```objc
// Objective-C: Initializers
- (instancetype)initWithTitle:(NSString *)title {
    self = [super init];
    if (self) {
        _title = [title copy];
    }
    return self;
}

+ (instancetype)userWithEmail:(NSString *)email {
    return [[self alloc] initWithEmail:email];
}
```

```dart
// Dart: Generative & Named Constructors
class Item {
  final String title;

  // Generative constructor with initializing formal
  const Item({required this.title});

  // Named constructor
  Item.anonymous() : title = 'Anonymous';

  // Factory constructor (can return cached or subtype instances)
  factory Item.fromEmail(String email) {
    return Item(title: email.split('@').first);
  }
}
```

### Properties and Encapsulation

- Objective-C properties (`@property`) generate backing instance variables (`_prop`) and synthesize accessor methods.
- In Dart, all fields automatically expose implicit getters and (if mutable) setters. Custom getters and setters can be added without altering the public API.

```objc
// Objective-C
@property (nonatomic, strong) NSString *status;
- (NSString *)status {
    return _status;
}
- (void)setStatus:(NSString *)status {
    _status = [status uppercaseString];
}
```

```dart
// Dart
String _status = '';

String get status => _status;
set status(String value) {
  _status = value.toUpperCase();
}
```

### Protocols vs Abstract Classes / Interfaces / Mixins

- In Objective-C, a `@protocol` defines a set of required and `@optional` methods. Classes adopt protocols via `<ProtocolName>`.
- In Dart, **every class implicitly defines an interface**. Use `abstract class` or `abstract interface class` to define contracts.
- For optional delegate methods, Dart uses **nullable callback functions** (`VoidCallback?`, `ValueChanged<T>?`) rather than bulky delegate protocols.

```objc
// Objective-C: Protocol & Delegation Pattern
@protocol PaymentDelegate <NSObject>
- (void)paymentDidSucceed:(NSString *)transactionId;
@optional
- (void)paymentDidFailWithError:(NSError *)error;
@end

@interface PaymentProcessor : NSObject
@property (nonatomic, weak) id<PaymentDelegate> delegate;
- (void)processPayment;
@end
```

```dart
// Dart Idiomatic Equivalent: Callback closures
class PaymentProcessor {
  final void Function(String transactionId) onSuccess;
  final void Function(Exception error)? onFailure;

  PaymentProcessor({
    required this.onSuccess,
    this.onFailure,
  });

  void processPayment() {
    try {
      // ... process
      onSuccess('tx_12345');
    } on Exception catch (e) {
      onFailure?.call(e);
    }
  }
}
```

### Categories vs Extension Methods

- Objective-C categories (`@interface NSString (Utils)`) allow adding methods to existing classes.
- Dart provides **Extension Methods** (`extension Utils on String`) which provide static, compile-time method dispatch without runtime method swizzling dangers.

```objc
// Objective-C Category
@interface NSString (EmailValidation)
- (BOOL)isValidEmail;
@end

@implementation NSString (EmailValidation)
- (BOOL)isValidEmail {
    return [self containsString:@"@"];
}
@end
```

```dart
// Dart Extension Method
extension EmailValidation on String {
  bool get isValidEmail => contains('@') && contains('.');
}

// Usage:
// 'test@example.com'.isValidEmail
```

### Blocks vs Closures & First-Class Functions

- Objective-C blocks (`^returnType(params) { ... }`) require careful memory management (`__weak typeof(self) weakSelf = self;` and `__strong`) to prevent retain cycles.
- Dart functions are first-class objects with lexical scoping. Closures automatically capture variables, and Dart's garbage collector automatically handles reference cycles.

```objc
// Objective-C: Block with weakSelf/strongSelf dance
__weak typeof(self) weakSelf = self;
[self.apiService fetchDataWithCompletion:^(NSData *data, NSError *error) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) return;
    if (error) {
        [strongSelf handleError:error];
    } else {
        [strongSelf handleData:data];
    }
}];
```

```dart
// Dart: Lexical closure with async/await
try {
  final data = await apiService.fetchData();
  handleData(data);
} on Exception catch (e) {
  handleError(e);
}
```

### Selectors, Enums, and Bitmasks

- Objective-C relies on `@selector(method:)` and `NS_ENUM` / `NS_OPTIONS`.
- Dart provides **first-class functions** (no selector reflection required) and **Enhanced Enums** with properties, methods, and constructors.

```objc
// Objective-C: NS_ENUM
typedef NS_ENUM(NSInteger, NetworkState) {
    NetworkStateDisconnected,
    NetworkStateConnecting,
    NetworkStateConnected
};
```

```dart
// Dart: Enhanced Enum
enum NetworkState {
  disconnected('Offline'),
  connecting('Connecting...'),
  connected('Online');

  final String label;
  const NetworkState(this.label);

  bool get isReady => this == NetworkState.connected;
}
```

---

## Memory Management: ARC vs Garbage Collection

| Feature | Objective-C (ARC) | Dart |
|---|---|---|
| **Mechanism** | Automatic Reference Counting (compiler inserts `retain`/`release`) | Generational Garbage Collection (Nursery + Old Generation) |
| **Cycles** | Retain cycles cause permanent memory leaks | Mark-and-sweep GC easily cleans up unreachable circular references |
| **Weak References** | `__weak` or `@property (weak)` zeroing weak references | Native GC handles objects; `WeakReference<T>` available for custom caches |
| **Autorelease Pool** | `@autoreleasepool { ... }` controls temporary allocations | Scoped local variables are collected automatically by nursery GC |
| **Destruction** | `- (void)dealloc` runs when ref count reaches 0 | `State.dispose()` or `finalizer` (Finalizer is rarely needed for pure Dart) |

> [!TIP]
> In Flutter, you do **not** need `weakSelf` or `unowned` for widget event handlers. However, you **must** dispose long-lived controllers (`TextEditingController`, `AnimationController`, `StreamSubscription`, `Timer`) in `State.dispose()` to prevent leaking framework listeners.

---

## Foundation and Core Types Conversion

### Scalar and Numeric Types

| Objective-C | Dart | Notes |
|---|---|---|
| `NSInteger`, `NSUInteger`, `int` | `int` | 64-bit integer on 64-bit platforms |
| `CGFloat`, `float`, `double` | `double` | 64-bit IEEE 754 floating point |
| `BOOL`, `YES`, `NO` | `bool`, `true`, `false` | Dart booleans are strictly typed (`0` is not falsy) |
| `NSNumber *` | `int`, `double`, `bool`, or `num` | No wrapper object needed |
| `NSIntegerMax` | Unsupported directly | Use bit shifting: `(1 << 62) - 1 + (1 << 62)` or `double.infinity` |

### Strings and String Manipulation

```objc
// Objective-C
NSString *greeting = [NSString stringWithFormat:@"Hello, %@! You have %ld items.", userName, (long)count];
BOOL contains = [greeting containsString:@"Hello"];
NSString *sub = [greeting substringWithRange:NSMakeRange(0, 5)];
```

```dart
// Dart: String interpolation and methods
final greeting = 'Hello, $userName! You have $count items.';
final contains = greeting.contains('Hello');
final sub = greeting.substring(0, 5);
```

### Collections (NSArray, NSDictionary, NSSet)

| Objective-C | Dart | Mutability |
|---|---|---|
| `NSArray<T> *` | `List<T>` | Dart lists are mutable by default; use `List.unmodifiable()` for immutable |
| `NSMutableArray<T> *` | `List<T>` | Append: `list.add(item);`, `list.addAll(items);` |
| `NSDictionary<K, V> *` | `Map<K, V>` | Key lookup: `map['key']`, literals: `{'a': 1}` |
| `NSMutableDictionary<K, V> *` | `Map<K, V>` | Assignment: `map['key'] = value;` |
| `NSSet<T> *` / `NSMutableSet<T> *` | `Set<T>` | Literals: `{1, 2, 3}`, membership: `set.contains(x)` |

```objc
// Objective-C: Filtering and Mapping
NSMutableArray *names = [NSMutableArray array];
for (User *user in users) {
    if (user.isValid) {
        [names addObject:[user.name uppercaseString]];
    }
}
```

```dart
// Dart: Functional Collections
final names = users
    .where((user) => user.isValid)
    .map((user) => user.name.toUpperCase())
    .toList();
```

### Dates, URLs, and Binary Buffers

- `NSDate` -> `DateTime` (`DateTime.now()`, `DateTime.parse(isoString)`, `dateTime.toIso8601String()`).
- `NSURL` -> `Uri` (`Uri.parse(urlString)`, `Uri.https('api.example.com', '/path')`).
- `NSData` / `NSMutableData` -> `Uint8List` (`dart:typed_data`).

### Error Handling (NSError vs Exceptions/Errors)

- Objective-C passes `NSError **` pointers to methods: `-(BOOL)save:(NSError **)error;`.
- Dart uses structured exceptions (`throw Exception('message')`) and typed `catch` clauses.

```objc
// Objective-C: NSError pattern
NSError *error = nil;
NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
if (error != nil) {
    NSLog(@"Failed to load data: %@", error.localizedDescription);
    return;
}
```

```dart
// Dart: Try / On / Catch
try {
  final response = await http.get(url);
  final data = response.bodyBytes;
} on SocketException catch (e) {
  print('Network error: $e');
} on HttpException catch (e) {
  print('HTTP error: $e');
} catch (e, stackTrace) {
  print('Unexpected error: $e\n$stackTrace');
}
```

---

## Concurrency: Grand Central Dispatch (GCD) to Dart

### Event Loop vs OS Threads

Objective-C developers frequently manage concurrency with GCD queues (`dispatch_async`) and `NSOperationQueue`. In Dart:
- The **main isolate** executes all UI building, rendering coordination, and user event processing on a **single thread**.
- I/O operations (network requests, database queries, file reads) are **non-blocking asynchronous tasks** handled by the OS kernel and Dart event loop. You do **not** need a background thread for network calls.

```
Objective-C GCD:
Thread 1 (Main) ──────────> dispatch_async(global_queue) ──> Thread 2 (Worker)
                                                                    │
Thread 1 (Main) <────────── dispatch_async(main_queue) <────────────┘

Dart Event Loop:
Event Loop ───> [ Microtask Queue ] ───> [ Event Queue (I/O, Timer, UI) ]
(Single thread, cooperative scheduling via async/await)
For heavy CPU only: Isolate.run() launches separate worker isolate
```

### Main Queue Dispatching vs UI Microtasks

In Objective-C, background callbacks must dispatch back to the main queue to touch UIKit:
```objc
// Objective-C
dispatch_async(dispatch_get_main_queue(), ^{
    self.statusLabel.text = @"Done";
});
```

In Dart, code returning from an `await` statement **already resumes on the main isolate**. No dispatching is required:
```dart
// Dart
final result = await fetchRemoteData();
// Automatically resumes on main isolate!
setState(() {
  status = 'Done';
});
```

If you need to defer code until after the current frame finishes rendering:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  // Runs immediately after Flutter renders the frame
  showWelcomeBanner();
});
```

### Background Queues vs Isolates

For **heavy CPU computation** (e.g., parsing a 50MB JSON payload, image resizing, encryption):
```objc
// Objective-C GCD Background Queue
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    NSData *processed = [self heavyCalculation:input];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self displayResult:processed];
    });
});
```

```dart
// Dart: Isolate.run (spawns separate isolate, transfers result)
final processed = await Isolate.run(() => heavyCalculation(input));
displayResult(processed);
```

### Dispatch Groups vs Future.wait

```objc
// Objective-C: dispatch_group
dispatch_group_t group = dispatch_group_create();
dispatch_group_enter(group);
[api loadProfile:^{ dispatch_group_leave(group); }];

dispatch_group_enter(group);
[api loadSettings:^{ dispatch_group_leave(group); }];

dispatch_group_notify(group, dispatch_get_main_queue(), ^{
    [self updateUI];
});
```

```dart
// Dart: Future.wait
final results = await Future.wait([
  api.loadProfile(),
  api.loadSettings(),
]);
updateUI(results[0], results[1]);
```

---

## UI Architecture: UIKit to Flutter

### Imperative UI vs Declarative Reactive Tree

| Concept | UIKit (Objective-C) | Flutter (Dart) |
|---|---|---|
| **View Construction** | Storyboard / XIB or `[[UIView alloc] init]` | `Widget build(BuildContext context)` returns immutable widget tree |
| **Updating Content** | Direct assignment (`myLabel.text = @"New"`) | Call `setState()` to request re-execution of `build()` |
| **View Reuse** | `dequeueReusableCellWithIdentifier:` | Handled automatically by `ListView.builder` element recycling |
| **Layout System** | Auto Layout (`NSLayoutConstraint`, Cassowary solver) | BoxConstraints ("Constraints go down. Sizes go up. Parent sets position") |

### UIViewController Lifecycle to StatefulWidget Lifecycle

```
UIViewController                   StatefulWidget / State<T>
┌─────────────────────────┐        ┌─────────────────────────┐
│ - (void)viewDidLoad     │  ───>  │ void initState()        │
│                         │        │                         │
│ - (void)viewWillAppear  │  ───>  │ didChangeDependencies() │
│                         │        │ (or RouteObserver)      │
│                         │        │                         │
│ [subviews layoutSubviews│  ───>  │ Widget build(context)   │
│                         │        │                         │
│ - (void)viewWillDisappear───>    │ (RouteObserver)         │
│                         │        │                         │
│ - (void)dealloc         │  ───>  │ void dispose()          │
└─────────────────────────┘        └─────────────────────────┘
```

### Auto Layout vs BoxConstraints

Auto Layout solves multi-variable equations with priorities, which can lead to unsatisfied constraint exceptions or ambiguous layouts. Flutter uses simple one-pass layout rules:
1. **Constraints go down**: Parent passes `BoxConstraints(minWidth, maxWidth, minHeight, maxHeight)` to child.
2. **Sizes go up**: Child determines its own size within those constraints and reports it to parent.
3. **Parent sets position**: Parent decides where to position child in `(x, y)` coordinate space.

- `UIStackView (horizontal)` -> `Row(children: [...])`
- `UIStackView (vertical)` -> `Column(children: [...])`
- Auto Layout equal widths/spacing -> `Expanded`, `Flexible`, `Spacer`
- Pinned frame / overlays -> `Stack(children: [Positioned(...)])`
- Safe Area insets (`view.safeAreaInsets`) -> `SafeArea(child: ...)`

### Component Equivalents Table

| UIKit (Objective-C) | Flutter (Dart) |
|---|---|
| `UIViewController` | `StatefulWidget` or `StatelessWidget` returning a `Scaffold` |
| `UIView` | `Container`, `SizedBox`, `DecoratedBox`, `Padding` |
| `UILabel` | `Text('...')` or `RichText` |
| `UIButton` | `ElevatedButton`, `FilledButton`, `CupertinoButton` |
| `UIImageView` | `Image.asset('...')`, `Image.network('...')` |
| `UITextField` | `TextField(controller: _controller)` / `TextFormField` |
| `UISwitch` | `Switch(value: _val, onChanged: (v) => ...)` |
| `UIActivityIndicatorView` | `CircularProgressIndicator()` / `CupertinoActivityIndicator()` |
| `UIAlertController` | `showDialog(builder: (_) => AlertDialog(...))` |
| `UIScrollView` | `SingleChildScrollView(child: ...)` |
| `UITableView` / `UICollectionView` | `ListView.builder`, `GridView.builder` |
| `UINavigationController` | `Navigator.push(...)` or `GoRouter` |
| `UITabBarController` | `CupertinoTabScaffold` or `NavigationBar` / `BottomNavigationBar` |

### UITableView/UICollectionView vs ListView/GridView

In UIKit, displaying a list requires `UITableViewDataSource` protocols and cell dequeueing:
```objc
// Objective-C UITableView DataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CustomCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [cell configureWithItem:self.items[indexPath.row]];
    return cell;
}
```

In Flutter, cell reuse is handled under the hood by Flutter's RenderObject pipeline. You simply declare an item builder:
```dart
// Flutter ListView.builder
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return ListTile(
      title: Text(item.title),
      subtitle: Text(item.subtitle),
      onTap: () => _handleSelect(item),
    );
  },
)
```

### Navigation and Routing

```objc
// Objective-C: Push and Pop
DetailViewController *vc = [[DetailViewController alloc] initWithItem:item];
[self.navigationController pushViewController:vc animated:YES];

// Pop
[self.navigationController popViewControllerAnimated:YES];
```

```dart
// Dart: Navigator 2.0 / Imperative Push
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => DetailScreen(item: item),
  ),
);

// Pop
Navigator.of(context).pop();
```

---

## iOS Subsystems & Native Services

| iOS Framework / Service | Flutter / Dart Package Equivalent | Purpose |
|---|---|---|
| `NSUserDefaults` | `package:shared_preferences` | Key-value simple configuration storage |
| `Security (Keychain)` | `package:flutter_secure_storage` | Encrypted storage for tokens and credentials |
| `CoreData` / `SQLite` | `package:sqflite`, `package:drift` | Relational local database persistence |
| `NSURLSession` / `AFNetworking` | `package:http`, `package:dio` | REST, HTTP/HTTPS client |
| `CoreLocation` | `package:geolocator` | GPS location, heading, geofencing |
| `AVFoundation (Camera)` | `package:camera` | Camera capture and preview |
| `AVFoundation (Audio)` | `package:audioplayers` | Audio playback and streaming |
| `UserNotifications` | `package:flutter_local_notifications` | Push and local notifications |
| `NSNotificationCenter` | `ChangeNotifier`, `StreamController`, or Riverpod | In-app decoupled event pub/sub |
| `UIKit (Haptics)` | `HapticFeedback.lightImpact()` (`services.dart`) | Native tactile haptic feedback |

---

## Interoperability Strategies: When Not to Rewrite

When migrating an existing iOS Objective-C app, you don't always rewrite 100% of the native code immediately.

```
Is the code UI or standard Business Logic?
├── YES ──> Rewrite in pure Dart (Fastest, cross-platform)
└── NO  ──> Is it a proprietary C/Obj-C library or deep hardware SDK?
            ├── High-frequency, in-process C/Obj-C API? ──> Use Dart FFI (package:ffigen)
            ├── Structured API with complex models?      ──> Use Pigeon (package:pigeon)
            └── Existing complex UIView to embed?        ──> Use UiKitView (Platform View)
```

### Dart FFI with Objective-C Support (package:ffigen)

Dart supports direct calling of Objective-C APIs via `dart:ffi` and `package:ffigen` with zero method channel serialization overhead!

```dart
// tool/ffigen_objc.dart
import 'package:ffigen/ffigen.dart';

void main() {
  final config = FfiGenerator(
    headers: Headers(
      entryPoints: [
        Uri.file('/path/to/MyNativeSDK.h'),
      ],
    ),
    objectiveC: ObjectiveC(
      interfaces: Interfaces.includeSet({'MyNativeSDK'}),
    ),
    output: Output(
      dartFile: Uri.file('lib/src/native_sdk.g.dart'),
    ),
  );
  config.generate();
}
```

In Dart, consume the generated bindings directly:
```dart
import 'dart:ffi';
import 'package:objective_c/objective_c.dart';
import 'native_sdk.g.dart';

void useNative() {
  final sdk = MyNativeSDK.alloc().init();
  final result = sdk.calculateMetric(NSString('input'));
  print(result.toDartString());
}
```

### Pigeon Code Generation

For multi-platform plugins needing structured IPC between Dart and Objective-C/Swift without manual `MethodChannel` string matching, use `package:pigeon`:

```dart
// pigeons/messages.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  objcHeaderOut: 'ios/Runner/Messages.g.h',
  objcSourceOut: 'ios/Runner/Messages.g.m',
))
@HostApi()
abstract class NativeDeviceApi {
  String getDeviceId();
  void setVibration(bool enabled);
}
```

Run pigeon:
```bash
dart run pigeon --input pigeons/messages.dart
```

---

## Step-by-Step Migration Workflow

Follow this systematic workflow when porting an Objective-C iOS codebase to Flutter:

**Phase 1: Codebase Audit & Architectural Inventory**
- [ ] Catalog all `.h` and `.m` files. Group into:
  - Data Models / Entities
  - Networking / Services
  - Storage / CoreData
  - View Controllers / Views / Storyboards
  - 3rd-party iOS Pods / Frameworks
- [ ] Identify which 3rd-party Pods have established Flutter package equivalents on [pub.dev](https://pub.dev).

**Phase 2: Foundation & Data Layer Migration**
- [ ] Convert `@interface` data models to pure Dart classes.
- [ ] Implement `fromJson` and `toJson` methods or use `package:freezed` / `package:json_serializable`.
- [ ] Convert `NSDate` fields to `DateTime` and `NSURL` fields to `Uri`.

**Phase 3: Business Logic & Network Services**
- [ ] Convert `NSURLSession` or `AFNetworking` clients to `package:http` or `package:dio`.
- [ ] Replace completion blocks with `Future<T>` and `async` / `await`.
- [ ] Replace Grand Central Dispatch queues with standard asynchronous futures or `Isolate.run()`.

**Phase 4: State Management Architecture**
- [ ] Choose an architecture suited to the app scale (e.g., `ChangeNotifier` + `ListenableBuilder` for simple apps; `BLoC` or `Riverpod` for enterprise apps).
- [ ] Replace `NSNotificationCenter` with event streams or state providers.

**Phase 5: UI Construction (Declarative Widgets)**
- [ ] Convert `UIViewController` screens into `StatelessWidget` or `StatefulWidget`.
- [ ] Rebuild Storyboard / Auto Layout constraints using `Scaffold`, `Column`, `Row`, `Expanded`, and `ListView.builder`.
- [ ] Replicate styling using `ThemeData`, `ColorScheme`, and `TextTheme`.

**Phase 6: Native Bridge Setup (Optional)**
- [ ] If proprietary iOS SDKs must remain, implement `package:ffigen` Objective-C bindings or `package:pigeon`.

**Phase 7: Testing & Quality Assurance**
- [ ] Write unit tests for models and services with `package:test`.
- [ ] Write widget tests with `package:flutter_test` (`pumpWidget`, `findsOneWidget`).
- [ ] Run `dart analyze` to ensure zero static warnings.

---

## Concrete Migration Examples

### Example 1: Data Model with JSON Serialization

#### Objective-C Implementation
```objc
// Product.h
#import <Foundation/Foundation.h>

@interface Product : NSObject
@property (nonatomic, copy, readonly) NSString *productId;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) double price;
@property (nonatomic, strong, readonly) NSDate *createdAt;

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dict;
- (NSDictionary<NSString *, id> *)toDictionary;
@end

// Product.m
#import "Product.h"

@implementation Product

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dict {
    self = [super init];
    if (self) {
        _productId = [dict[@"id"] copy];
        _name = [dict[@"name"] copy];
        _price = [dict[@"price"] doubleValue];
        
        static NSISO8601DateFormatter *formatter = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            formatter = [[NSISO8601DateFormatter alloc] init];
        });
        _createdAt = [formatter dateFromString:dict[@"created_at"]];
    }
    return self;
}

- (NSDictionary<NSString *, id> *)toDictionary {
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    return @{
        @"id": self.productId ?: @"",
        @"name": self.name ?: @"",
        @"price": @(self.price),
        @"created_at": [formatter stringFromDate:self.createdAt] ?: @""
    };
}
@end
```

#### Dart & Flutter Equivalent
```dart
// product.dart
class Product {
  final String productId;
  final String name;
  final double price;
  final DateTime createdAt;

  const Product({
    required this.productId,
    required this.name,
    required this.price,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': productId,
      'name': name,
      'price': price,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
```

---

### Example 2: Asynchronous Network Service

#### Objective-C Implementation
```objc
// ProductService.m
#import "ProductService.h"

@implementation ProductService

- (void)fetchProductsWithCompletion:(void(^)(NSArray<Product *> * _Nullable products, NSError * _Nullable error))completion {
    NSURL *url = [NSURL URLWithString:@"https://api.example.com/v1/products"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        NSError *jsonError = nil;
        NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, jsonError);
            });
            return;
        }
        
        NSMutableArray<Product *> *products = [NSMutableArray array];
        for (NSDictionary *dict in jsonArray) {
            [products addObject:[[Product alloc] initWithDictionary:dict]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(products, nil);
        });
    }];
    [task resume];
}
@end
```

#### Dart & Flutter Equivalent
```dart
// product_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'product.dart';

class ProductService {
  final http.Client _client;
  final Uri _endpoint = Uri.https('api.example.com', '/v1/products');

  ProductService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Product>> fetchProducts() async {
    final response = await _client.get(_endpoint);

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Failed to fetch products: status ${response.statusCode}',
        _endpoint,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Expected JSON list of products');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
  }

  void dispose() {
    _client.close();
  }
}
```

---

### Example 3: Table View Controller to Flutter ListView

#### Objective-C (ProductListViewController)
```objc
// ProductListViewController.m
#import "ProductListViewController.h"
#import "ProductService.h"
#import "Product.h"

@interface ProductListViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, copy) NSArray<Product *> *products;
@property (nonatomic, strong) ProductService *service;
@end

@implementation ProductListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Products";
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.service = [[ProductService alloc] init];
    self.products = @[];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.view addSubview:self.tableView];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = self.view.center;
    [self.view addSubview:self.spinner];
    
    [self loadData];
}

- (void)loadData {
    [self.spinner startAnimating];
    __weak typeof(self) weakSelf = self;
    [self.service fetchProductsWithCompletion:^(NSArray<Product *> *products, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.spinner stopAnimating];
        if (products) {
            strongSelf.products = products;
            [strongSelf.tableView reloadData];
        }
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.products.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    Product *p = self.products[indexPath.row];
    cell.textLabel.text = p.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"$%.2f", p.price];
    return cell;
}
@end
```

#### Dart & Flutter Equivalent
```dart
// product_list_screen.dart
import 'package:flutter/material.dart';
import 'product.dart';
import 'product_service.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _service = ProductService();
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _service.fetchProducts();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading products: ${snapshot.error}'),
            );
          }

          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(child: Text('No products available.'));
          }

          return ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                trailing: Text('\$${product.price.toStringAsFixed(2)}'),
                onTap: () {
                  // Navigate to detail
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

## Common Pitfalls & Anti-Patterns

1. **Attempting to message `null` (The `nil` trap)**:
   - *In Objective-C*: `[nil doSomething]` fails silently and returns `0`.
   - *In Dart*: Calling a method on a nullable variable without `?.` will not compile, and force-unwrapping with `!` on a null value throws `TypeError`. Always handle nullable variables explicitly.

2. **Mutating State without `setState` or State Management**:
   - *Anti-Pattern*: Modifying a field `_count++` directly and expecting the UI to update like a UIKit imperative view property.
   - *Correction*: Wrap state updates in `setState(() { _count++; })` or use a reactive state container (`ValueNotifier`, `Riverpod`, `BLoC`).

3. **Treating Widgets as Mutable Objects**:
   - *Anti-Pattern*: Storing a widget in a member variable (`MyWidget widget = MyWidget();`) and trying to modify its properties later (`widget.title = "new";`).
   - *Correction*: Widgets are lightweight, immutable configuration blueprints. Pass state down through constructor parameters.

4. **Synchronously Blocking the Main Isolate**:
   - *Anti-Pattern*: Running heavy CPU computations (e.g. image processing, massive list sorting, cryptographic hashing) in synchronous methods, freezing the 60/120fps UI thread.
   - *Correction*: Offload heavy CPU work to `Isolate.run(() => doHeavyWork())`.

5. **Leaking Subscriptions and Controllers**:
   - *Anti-Pattern*: Creating `TextEditingController`, `AnimationController`, or `StreamSubscription` without canceling them.
   - *Correction*: Always override `dispose()` in `State<T>` and call `.dispose()` or `.cancel()`.

6. **Recreating the Entire UIViewController Delegate Protocol Boilerplate**:
   - *Anti-Pattern*: Creating verbose `@protocol` equivalents with 10 methods when only one or two callbacks are needed.
   - *Correction*: Use standard Dart `typedef ActionCallback = void Function(Data);` or `ValueChanged<T>`.

---

## Migration Verification Checklist

Before considering an Objective-C to Dart/Flutter migration complete, verify:

- [ ] **Sound Null Safety**: All models and functions strictly adhere to Dart null safety with zero unnecessary `!` force-unwraps.
- [ ] **Declarative Architecture**: No UI views retain long-lived mutable subview references; state is managed via `StatefulWidget`, `ChangeNotifier`, or a state management framework.
- [ ] **Resource Cleanup**: Every `TextEditingController`, `ScrollController`, `AnimationController`, and `StreamSubscription` created is explicitly cleaned up in `dispose()`.
- [ ] **Non-Blocking Concurrency**: All network calls and disk operations use `async` / `await`. Heavy CPU tasks use `Isolate.run()`.
- [ ] **Zero Static Analysis Warnings**: Run `dart analyze` across the package and verify 0 errors and 0 warnings.
- [ ] **Automated Test Coverage**:
  - Unit tests verify serialization and business logic: `flutter test test/models/`
  - Widget tests verify screen rendering and interaction: `flutter test test/screens/`
- [ ] **iOS Native Platform Check**: If using native interop (`ffigen` or `pigeon`), ensure iOS builds succeed in Xcode (`flutter build ios --no-codesign`).

---
---

