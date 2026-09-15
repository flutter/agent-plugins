# Swift & SwiftUI to Flutter Migration Guide (`flutter-swift-to-flutter`)

## Contents
- [Overview & Core Paradigms](#swift-overview--core-paradigms)
- [Language & Syntax Mapping](#swift-language--syntax-mapping)
  - [Value Types (struct) vs Immutable Reference Types](#value-types-struct-vs-immutable-reference-types)
  - [Enums with Associated Values vs Dart 3 Sealed Classes](#enums-with-associated-values-vs-dart-3-sealed-classes)
  - [Optionals & Unwrapping (guard let / if let)](#optionals--unwrapping-guard-let--if-let)
  - [Protocols, Protocol Extensions & POP vs Mixins & Interfaces](#protocols-protocol-extensions--pop-vs-mixins--interfaces)
  - [Property Wrappers vs Dart State Primitives](#property-wrappers-vs-dart-state-primitives)
  - [Codable vs Dart JSON Serialization](#codable-vs-dart-json-serialization)
- [Concurrency: Swift Modern Concurrency & Combine to Dart](#concurrency-swift-modern-concurrency--combine-to-dart)
  - [async/await and Task vs Future and Isolates](#asyncawait-and-task-vs-future-and-isolates)
  - [MainActor vs Dart Root UI Isolate](#mainactor-vs-dart-root-ui-isolate)
  - [Actors vs Dart Isolate Isolation](#actors-vs-dart-isolate-isolation)
  - [Combine Publishers vs Dart Streams](#combine-publishers-vs-dart-streams)
- [UI Architecture: SwiftUI to Flutter](#ui-architecture-swiftui-to-flutter)
  - [Declarative Blueprint Model: View vs Widget](#declarative-blueprint-model-view-vs-widget)
  - [View Modifiers vs Widget Composition](#view-modifiers-vs-widget-composition)
  - [Layout Hierarchy & Alignment Mapping](#layout-hierarchy--alignment-mapping)
  - [State Management Equivalents (@State, @Binding, @Observable)](#state-management-equivalents-state-binding-observable)
  - [Navigation and Screen Transitions](#swiftui-navigation-and-screen-transitions)
  - [SwiftUI to Flutter Component Equivalents](#swiftui-to-flutter-component-equivalents)
- [iOS Subsystems & System Integrations](#swift-ios-subsystems--system-integrations)
- [Interoperability Strategies for Swift Codebases](#interoperability-strategies-for-swift-codebases)
  - [Pigeon Code Generation for Type-Safe Swift IPC](#pigeon-code-generation-for-type-safe-swift-ipc)
  - [Swift to Objective-C Header to Dart FFI (package:ffigen)](#swift-to-objective-c-header-to-dart-ffi-packageffigen)
  - [Embedding SwiftUI Views via UIHostingController & UiKitView](#embedding-swiftui-views-via-uihostingcontroller--uikitview)
- [Step-by-Step Migration Workflow](#swift-step-by-step-migration-workflow)
- [Concrete Migration Examples](#swift-concrete-migration-examples)
  - [Example 1: Codable Struct & Algebraic Enum to Dart Sealed Class](#swift-example-1-codable-struct--algebraic-enum-to-dart-sealed-class)
  - [Example 2: Async/Await Service with Error Handling](#swift-example-2-asyncawait-service-with-error-handling)
  - [Example 3: SwiftUI View with Observable State to Flutter Widget](#swift-example-3-swiftui-view-with-observable-state-to-flutter-widget)
- [Common Pitfalls & Anti-Patterns](#swift-common-pitfalls--anti-patterns)
- [Migration Verification Checklist](#swift-migration-verification-checklist)

---

## Swift Overview & Core Paradigms

Both Swift/SwiftUI and Dart/Flutter are modern, expressive, strongly-typed environments built for reactive declarative UI. However, their fundamental memory models and runtime architectures differ:

```
Swift / SwiftUI
┌────────────────────────────────────────────────────────┐
│ • Value types (struct, enum) with Copy-on-Write (COW)  │
│ • View modifiers return modified wrapper view types    │
│ • Multi-threaded concurrency (MainActor, Task, actor)  │
│ • Macro-based observation (@Observable, @State)       │
│ • Compiled directly to native machine code via LLVM    │
└────────────────────────────────────────────────────────┘
                           │
                           ▼ Architectural Parallels & Bridges
Dart / Flutter
┌────────────────────────────────────────────────────────┐
│ • Reference types (class) with const / immutable style │
│ • Widgets wrap children (Widget composition)           │
│ • Single-threaded isolate event loop (UI is main)      │
│ • Listenable, ChangeNotifier, or Riverpod / BLoC       │
│ • Multi-platform AOT (mobile/desktop) + JIT (hot reload│
└────────────────────────────────────────────────────────┘
```

---

## Swift Language & Syntax Mapping

### Value Types (struct) vs Immutable Reference Types

- **In Swift**: `struct` is a value type copied on assignment (mutating requires `mutating func`).
- **In Dart**: Classes are reference types. To mimic Swift structs, write **immutable classes** using `const` constructors, `final` fields, and the `copyWith()` pattern or `package:freezed`.

```swift
// Swift: Immutable struct with mutating copy
struct UserProfile: Identifiable, Equatable {
    let id: String
    var displayName: String
    var email: String
    
    func withUpdatedName(_ newName: String) -> UserProfile {
        var copy = self
        copy.displayName = newName
        return copy
    }
}
```

```dart
// Dart: Immutable class with copyWith
class UserProfile {
  final String id;
  final String displayName;
  final String email;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
  });

  UserProfile copyWith({
    String? displayName,
    String? email,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          email == other.email;

  @override
  int get hashCode => Object.hash(id, displayName, email);
}
```

### Enums with Associated Values vs Dart 3 Sealed Classes

Swift enums with associated values are algebraic data types. In Dart 3, these map directly to **`sealed class` hierarchies** with exhaustive pattern matching:

```swift
// Swift: Enum with associated values
enum RequestState<T> {
    case idle
    case loading
    case success(data: T)
    case failure(error: String)
}

func renderState(state: RequestState<[String]>) {
    switch state {
    case .idle:
        print("Ready")
    case .loading:
        print("Loading...")
    case .success(let data):
        print("Loaded \(data.count) items")
    case .failure(let err):
        print("Error: \(err)")
    }
}
```

```dart
// Dart 3: Sealed class hierarchy with exhaustive pattern matching
sealed class RequestState<T> {
  const RequestState();
}

class Idle<T> extends RequestState<T> {
  const Idle();
}

class Loading<T> extends RequestState<T> {
  const Loading();
}

class Success<T> extends RequestState<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends RequestState<T> {
  final String error;
  const Failure(this.error);
}

void renderState(RequestState<List<String>> state) {
  final message = switch (state) {
    Idle() => 'Ready',
    Loading() => 'Loading...',
    Success(:final data) => 'Loaded ${data.length} items',
    Failure(:final error) => 'Error: $error',
  };
  print(message);
}
```

### Optionals & Unwrapping (guard let / if let)

- Swift `guard let val = opt else { return }` unpacks optionals into the enclosing scope.
- Dart uses **flow-sensitive type promotion**: checking `if (val == null) return;` automatically promotes `val` from `T?` to `T` in the remaining scope!

```swift
// Swift: guard let
func processOrder(orderId: String?) {
    guard let id = orderId, !id.isEmpty else {
        print("Invalid order id")
        return
    }
    // 'id' is non-optional String
    print("Processing order: \(id)")
}
```

```dart
// Dart: Flow-sensitive type promotion
void processOrder(String? orderId) {
  if (orderId == null || orderId.isEmpty) {
    print('Invalid order id');
    return;
  }
  // 'orderId' is automatically promoted to non-nullable String!
  print('Processing order: $orderId');
}
```

### Protocols, Protocol Extensions & POP vs Mixins & Interfaces

- In Swift, protocols can provide default method implementations via protocol extensions (Protocol-Oriented Programming).
- In Dart, **every class is an implicit interface** (`implements MyInterface`), and reusable default implementations are provided by **`mixin`**.

```swift
// Swift: Protocol with default extension
protocol Timestamped {
    var createdAt: Date { get }
    func formattedDate() -> String
}

extension Timestamped {
    func formattedDate() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: createdAt)
    }
}
```

```dart
// Dart: Mixin with default implementation
mixin Timestamped {
  DateTime get createdAt;

  String formattedDate() {
    return createdAt.toIso8601String();
  }
}

class Order with Timestamped {
  @override
  final DateTime createdAt;
  final String orderId;

  Order({required this.orderId, required this.createdAt});
}
```

### Property Wrappers vs Dart State Primitives

| Swift Property Wrapper | Dart / Flutter Equivalent |
|---|---|
| `@State var count = 0` | `StatefulWidget` field modified inside `setState(() => count++)` |
| `@Binding var count: Int` | Callback `ValueChanged<int> onChanged` or `ValueNotifier<int>` |
| `@ObservedObject` / `@StateObject` | `ChangeNotifier` consumed via `ListenableBuilder` or `Consumer` |
| `@Published var name = ""` | `notifyListeners()` on `ChangeNotifier`, or `ValueNotifier<String>` |
| `@AppStorage("key")` | `package:shared_preferences` read/write |
| `@Environment(\.dismiss)` | `Navigator.of(context).pop()` |

### Codable vs Dart JSON Serialization

Swift uses the compiler-synthesized `Codable` protocol. In Dart, implement `fromJson` and `toJson` methods manually or generate them with `package:json_serializable` / `package:freezed`.

```swift
// Swift: Codable
struct Article: Codable {
    let id: Int
    let title: String
    let publishedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case publishedAt = "published_at"
    }
}
```

```dart
// Dart: fromJson / toJson
class Article {
  final int id;
  final String title;
  final DateTime publishedAt;

  const Article({
    required this.id,
    required this.title,
    required this.publishedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as int,
      title: json['title'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'published_at': publishedAt.toIso8601String(),
    };
  }
}
```

---

## Concurrency: Swift Modern Concurrency & Combine to Dart

### async/await and Task vs Future and Isolates

- **Swift Concurrency**: `Task { await work() }` executes cooperatively on the global concurrent thread pool.
- **Dart Concurrency**: Code runs on a **single-threaded isolate**. `await` pauses execution until the `Future` completes and immediately resumes on the isolate's microtask queue.
- **Main Thread**: In Swift, UI code must be explicitly dispatched or annotated with `@MainActor`. In Flutter, **the root isolate is already the UI platform thread**!

```swift
// Swift: Async function with MainActor
@MainActor
class FeedViewModel: ObservableObject {
    @Published var items: [String] = []
    
    func loadFeed() async {
        do {
            let fetched = try await networkClient.fetchItems()
            self.items = fetched // Automatically on MainActor
        } catch {
            print("Error: \(error)")
        }
    }
}
```

```dart
// Dart: Async method in ChangeNotifier
class FeedViewModel extends ChangeNotifier {
  final NetworkClient _client;
  List<String> _items = [];

  FeedViewModel({NetworkClient? client}) : _client = client ?? NetworkClient();

  List<String> get items => _items;

  Future<void> loadFeed() async {
    try {
      final fetched = await _client.fetchItems();
      _items = fetched;
      notifyListeners(); // Resumes on root UI isolate automatically!
    } on Exception catch (e) {
      print('Error: $e');
    }
  }
}
```

### Actors vs Dart Isolate Isolation

- **Swift**: `actor Account { private var balance: Double; ... }` guards state against simultaneous data races across threads using actor reentrancy.
- **Dart**: Dart isolates have **completely isolated, unshared memory**. There are zero shared-memory data races. For background computation, `Isolate.run()` spawns a worker, executes a closure, and transfers the result back safely.

```swift
// Swift: TaskGroup for parallel fetching
func fetchAllMetrics() async throws -> [Metric] {
    try await withThrowingTaskGroup(of: Metric.self) { group in
        for endpoint in endpoints {
            group.addTask { try await fetchMetric(endpoint) }
        }
        var results: [Metric] = []
        for try await metric in group {
            results.append(metric)
        }
        return results
    }
}
```

```dart
// Dart: Future.wait for parallel fetching
Future<List<Metric>> fetchAllMetrics() async {
  final futures = endpoints.map(fetchMetric).toList();
  return await Future.wait(futures);
}
```

### Combine Publishers vs Dart Streams

Combine `Publisher` streams map directly to Dart `Stream`:

| Swift Combine | Dart Streams |
|---|---|
| `PassthroughSubject<T, Never>()` | `StreamController<T>.broadcast()` |
| `CurrentValueSubject<T, Never>(init)` | `BehaviorSubject<T>.seeded(init)` (`rxdart`) or `ValueNotifier<T>` |
| `.map { ... }` | `stream.map((event) => ...)` |
| `.filter { ... }` | `stream.where((event) => ...)` |
| `.debounce(for: .seconds(0.5))` | `stream.debounceTime(Duration(milliseconds: 500))` (`rxdart`) |
| `.sink { value in ... }` | `stream.listen((value) { ... })` |

---

## UI Architecture: SwiftUI to Flutter

### Declarative Blueprint Model: View vs Widget

Both frameworks use declarative, immutable UI descriptions that Flutter renders via Impeller and SwiftUI renders via CoreAnimation:

```swift
// SwiftUI: Declarative View
struct GreetingCard: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}
```

```dart
// Flutter: Declarative Widget
class GreetingCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const GreetingCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}
```

### SwiftUI to Flutter Component Equivalents

| SwiftUI | Flutter Equivalent | Notes |
|---|---|---|
| `View` protocol | `StatelessWidget` or `StatefulWidget` | Basic UI element |
| `body: some View` | `Widget build(BuildContext context)` | Rebuilds on state change |
| `VStack(spacing: n)` | `Column(children: [...])` | Vertical layout |
| `HStack(spacing: n)` | `Row(children: [...])` | Horizontal layout |
| `ZStack` | `Stack(children: [...])` | Layered layout |
| `Spacer()` | `Spacer()` | Expands to fill flex space |
| `Divider()` | `Divider()` | Rule separator |
| `Text("...")` | `Text('...')` | Text rendering |
| `Button("Title") { ... }` | `CupertinoButton(...)` or `ElevatedButton(...)` | Action button |
| `TextField("Hint", text: $text)` | `CupertinoTextField()` or `TextField(controller: ...)` | Input field |
| `Toggle("Label", isOn: $val)` | `CupertinoSwitch(value: val, onChanged: ...)` | Boolean switch |
| `Slider(value: $val, in: 0...1)` | `Slider(value: val, onChanged: ...)` | Slider control |
| `ProgressView()` | `CircularProgressIndicator()` / `CupertinoActivityIndicator()` | Loading indicator |
| `Image(systemName: "star")` | `Icon(CupertinoIcons.star)` | SF Symbols to CupertinoIcons |
| `ScrollView` | `SingleChildScrollView(child: ...)` | Scroll container |
| `List(items) { item in ... }` | `ListView.builder(itemCount: ..., itemBuilder: ...)` | Virtualized lazy list |
| `LazyVGrid` / `LazyHGrid` | `GridView.builder(...)` | Virtualized grid |
| `NavigationStack` | `Navigator` or `GoRouter` | Navigation container |
| `NavigationLink` | `Navigator.push(...)` or `context.push(...)` | Screen push |
| `.sheet(isPresented: ...)` | `showModalBottomSheet(...)` or `showCupertinoModalPopup(...)` | Sheet presentation |
| `.alert(...)` | `showDialog(builder: (_) => AlertDialog(...))` | Alert presentation |
| `TabView` | `CupertinoTabScaffold` or `NavigationBar` | Tab bar navigation |

---

## Interoperability Strategies for Swift Codebases

When migrating large existing iOS apps, migrate iteratively by bridging Swift libraries with Flutter:

```
Swift Migration Strategy:
1. Pure Business Logic & UI ──> Rewrite in 100% Dart & Flutter (Cross-platform)
2. Proprietary Swift Framework / SDK:
   ├── High-level API calls ──> Pigeon (package:pigeon generates Swift & Dart IPC)
   ├── C/ObjC compatible SDK ──> Swift @objc export + ffigen (in-process FFI)
   └── Complex existing SwiftUI View ──> UIHostingController wrapped in UiKitView
```

### Pigeon Code Generation for Type-Safe Swift IPC

`package:pigeon` generates type-safe Swift protocol definitions and Dart APIs:

```dart
// pigeons/device_service.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/device_service.g.dart',
  swiftOut: 'ios/Runner/DeviceService.g.swift',
))
@HostApi()
abstract class DeviceNativeApi {
  String getSystemVersion();
  void triggerHaptic(int style);
}
```

Implement in Swift (`ios/Runner/DeviceService.swift`):
```swift
import Flutter
import UIKit

class DeviceNativeApiImpl: DeviceNativeApi {
    func getSystemVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    func triggerHaptic(style: Int64) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
```

Register in `AppDelegate.swift`:
```swift
let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
DeviceNativeApiSetup.setUp(binaryMessenger: controller.binaryMessenger, api: DeviceNativeApiImpl())
```

---

## Swift Step-by-Step Migration Workflow

Follow this structured process when converting a Swift/SwiftUI iOS application:

**Phase 1: Architecture & Dependency Inventory**
- [ ] Catalog all Swift files. Identify:
  - Value types (`struct`, `enum`, `Codable` models)
  - Business logic services (`actor`, async network clients)
  - State managers (`@Observable`, `ObservableObject`, Combine subjects)
  - SwiftUI views (`View`, `UIViewRepresentable`)
  - CocoaPods / SPM third-party dependencies

**Phase 2: Data Models & Serialization**
- [ ] Convert Swift structs into Dart immutable classes.
- [ ] Convert enums with associated values into Dart 3 `sealed class` hierarchies.
- [ ] Write `fromJson` and `toJson` factory methods.

**Phase 3: Asynchronous Services & Concurrency**
- [ ] Convert `async` / `await` Swift methods to Dart `Future<T>` methods using `package:http` or `package:dio`.
- [ ] Replace Swift `actor` synchronization with Dart's single-threaded isolate model.
- [ ] Replace detached Tasks with `Isolate.run()` for heavy CPU processing.
- [ ] Convert Combine pipelines into Dart `Stream` or `RxDart` subjects.

**Phase 4: State Management Translation**
- [ ] Map `@Observable` / `ObservableObject` view models to `ChangeNotifier` or Riverpod notifiers.
- [ ] Replace `@Published` variables with getters and `notifyListeners()`.

**Phase 5: SwiftUI View Hierarchy Conversion**
- [ ] Map SwiftUI `View` structs to `StatelessWidget` or `StatefulWidget`.
- [ ] Convert `VStack` / `HStack` / `ZStack` layouts into `Column` / `Row` / `Stack`.
- [ ] Convert view modifier chains (`.padding()`, `.background()`, `.cornerRadius()`) into nested widget trees (`Padding`, `DecoratedBox`, `ClipRRect`).
- [ ] Replace `List` with `ListView.builder` for virtualized rendering.

**Phase 6: Platform Channels / Pigeon (if needed)**
- [ ] If proprietary iOS SDKs must be retained, implement `package:pigeon` bindings.

**Phase 7: Testing & Validation**
- [ ] Run `dart analyze` to guarantee zero errors and strict null safety compliance.
- [ ] Port XCTest unit tests to Dart `test/` suites.
- [ ] Verify widget rendering with `flutter test`.

---

## Swift Concrete Migration Examples

### Swift Example 1: Codable Struct & Algebraic Enum to Dart Sealed Class

#### Swift Implementation
```swift
// Order.swift
import Foundation

enum OrderStatus: Codable {
    case pending
    case shipped(trackingNumber: String)
    case delivered(date: Date)
    case cancelled(reason: String)
}

struct Order: Codable, Identifiable {
    let id: String
    let customerName: String
    let totalAmount: Double
    let status: OrderStatus
}
```

#### Dart 3 & Flutter Equivalent
```dart
// order.dart
sealed class OrderStatus {
  const OrderStatus();

  factory OrderStatus.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'pending' => const PendingStatus(),
      'shipped' => ShippedStatus(json['tracking_number'] as String),
      'delivered' => DeliveredStatus(DateTime.parse(json['date'] as String)),
      'cancelled' => CancelledStatus(json['reason'] as String),
      _ => throw FormatException('Unknown order status: $type'),
    };
  }

  Map<String, dynamic> toJson();
}

class PendingStatus extends OrderStatus {
  const PendingStatus();
  @override
  Map<String, dynamic> toJson() => {'type': 'pending'};
}

class ShippedStatus extends OrderStatus {
  final String trackingNumber;
  const ShippedStatus(this.trackingNumber);
  @override
  Map<String, dynamic> toJson() => {
        'type': 'shipped',
        'tracking_number': trackingNumber,
      };
}

class DeliveredStatus extends OrderStatus {
  final DateTime date;
  const DeliveredStatus(this.date);
  @override
  Map<String, dynamic> toJson() => {
        'type': 'delivered',
        'date': date.toIso8601String(),
      };
}

class CancelledStatus extends OrderStatus {
  final String reason;
  const CancelledStatus(this.reason);
  @override
  Map<String, dynamic> toJson() => {
        'type': 'cancelled',
        'reason': reason,
      };
}

class Order {
  final String id;
  final String customerName;
  final double totalAmount;
  final OrderStatus status;

  const Order({
    required this.id,
    required this.customerName,
    required this.totalAmount,
    required this.status,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      customerName: json['customer_name'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: OrderStatus.fromJson(json['status'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'status': status.toJson(),
    };
  }
}
```

---

### Swift Example 2: Async/Await Service with Error Handling

#### Swift Implementation
```swift
// OrderService.swift
import Foundation

enum NetworkError: Error {
    case badURL
    case serverError(Int)
    case decodingError
}

actor OrderService {
    private let session = URLSession.shared
    private let baseURL = URL(string: "https://api.example.com/v1/orders")!
    
    func fetchOrders() async throws -> [Order] {
        let (data, response) = try await session.data(from: baseURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError(-1)
        }
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Order].self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}
```

#### Dart Equivalent
```dart
// order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'order.dart';

class OrderException implements Exception {
  final String message;
  final int? statusCode;
  const OrderException(this.message, [this.statusCode]);

  @override
  String toString() => 'OrderException: $message (code: $statusCode)';
}

class OrderService {
  final http.Client _client;
  final Uri _endpoint = Uri.https('api.example.com', '/v1/orders');

  OrderService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Order>> fetchOrders() async {
    final response = await _client.get(_endpoint);

    if (response.statusCode != 200) {
      throw OrderException(
        'Server returned failure response',
        response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('Expected JSON array of orders');
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Order.fromJson)
          .toList();
    } catch (e) {
      throw OrderException('Decoding error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
```

---

### Swift Example 3: SwiftUI View with Observable State to Flutter Widget

#### SwiftUI Implementation
```swift
// OrderListView.swift
import SwiftUI

@MainActor
class OrderListViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let service = OrderService()
    
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            orders = try await service.fetchOrders()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct OrderListView: View {
    @StateObject private var viewModel = OrderListViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else {
                    List(viewModel.orders) { order in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(order.customerName)
                                    .font(.headline)
                                Text(statusLabel(for: order.status))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: "$%.2f", order.totalAmount))
                                .bold()
                        }
                    }
                }
            }
            .navigationTitle("Orders")
            .task {
                await viewModel.load()
            }
        }
    }
    
    private func statusLabel(for status: OrderStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .shipped(let tracking): return "Shipped: \(tracking)"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        }
    }
}
```

#### Flutter & Dart Equivalent
```dart
// order_list_screen.dart
import 'package:flutter/material.dart';
import 'order.dart';
import 'order_service.dart';

class OrderListViewModel extends ChangeNotifier {
  final OrderService _service;
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  OrderListViewModel({OrderService? service})
      : _service = service ?? OrderService();

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _service.fetchOrders();
    } on Exception catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _viewModel = OrderListViewModel();

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
        title: const Text('Orders'),
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
                'Error: ${_viewModel.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (_viewModel.orders.isEmpty) {
            return const Center(child: Text('No orders found'));
          }

          return ListView.separated(
            itemCount: _viewModel.orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = _viewModel.orders[index];
              return ListTile(
                title: Text(order.customerName),
                subtitle: Text(_formatStatus(order.status)),
                trailing: Text(
                  '\$${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatStatus(OrderStatus status) {
    return switch (status) {
      PendingStatus() => 'Pending',
      ShippedStatus(:final trackingNumber) => 'Shipped: $trackingNumber',
      DeliveredStatus() => 'Delivered',
      CancelledStatus(:final reason) => 'Cancelled: $reason',
    };
  }
}
```

---

## Swift Common Pitfalls & Anti-Patterns

1. **Assuming Structural Equality on Classes**:
   - *In Swift*: Structs automatically synthesize value equality (`==`).
   - *In Dart*: Classes use identity equality by default. If your converted model is used in sets or compared for state diffing, override `==` and `hashCode` or use `package:freezed`.

2. **Unnecessary Micro-Isolates for Async I/O**:
   - *Anti-Pattern*: Wrapping `http.get` in `Isolate.run()` thinking it is needed like a detached Swift `Task`.
   - *Correction*: Dart network and file I/O is non-blocking asynchronous by default. Reserve `Isolate.run()` strictly for CPU-intensive work.

3. **Treating Widgets as Mutable Objects**:
   - *Anti-Pattern*: Trying to alter widget properties after creation.
   - *Correction*: Widgets are lightweight immutable configuration blueprints. Pass state updates down via constructor arguments when `setState` triggers `build()`.

4. **Missing `dispose()` on Controllers and Streams**:
   - *Anti-Pattern*: Leaving `TextEditingController`, `AnimationController`, or `StreamSubscription` uncleaned when a widget is removed.
   - *Correction*: Always dispose them inside `State.dispose()`.

5. **Swift `guard let` vs Dart Type Promotion**:
   - In Dart, if an instance field is nullable (`String? field`), checking `if (field == null) return;` does **not** automatically type-promote `field` if it's a mutable getter (because a subclass could override the getter). Shadow it to a local variable first: `final val = field; if (val == null) return;`.

---

## Swift Migration Verification Checklist

Before completing a Swift/SwiftUI to Flutter migration, verify:

- [ ] **Sound Null Safety**: All variables, models, and parameters strictly enforce null safety with zero unsafe `!` force-unwraps.
- [ ] **Sealed Classes & Exhaustive Switches**: State machines and algebraic enums use Dart 3 `sealed class` with compiler-checked pattern matching.
- [ ] **Reactive Clean Architecture**: UI is driven declaratively via `build()`; state is separated in `ChangeNotifier` / `StateNotifier` / Riverpod / BLoC.
- [ ] **Lifecycle Resource Cleanup**: All controllers, timers, and subscriptions are explicitly closed in `dispose()`.
- [ ] **Zero Static Analysis Warnings**: `dart analyze` passes with 0 errors and 0 warnings.
- [ ] **Automated Test Coverage**:
  - Unit tests for models and services: `flutter test test/models/ test/services/`
  - Widget tests for screens and component interactions: `flutter test test/screens/`
- [ ] **Platform Interoperability**: If using `package:pigeon` for native Swift bridging, verify iOS builds compile cleanly in Xcode (`flutter build ios --no-codesign`).

---
---

