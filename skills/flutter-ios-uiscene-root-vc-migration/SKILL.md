---
name: flutter-ios-uiscene-root-vc-migration
description: Migrates iOS Flutter plugins from fetching the root view controller via UIApplication.shared.delegate.window.rootViewController to using registrar.viewController.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Jul 2026 21:20:01 GMT
---
# Migrating Flutter iOS Plugins to UIScene

## Contents
- [Legacy Root View Controller Pattern](#legacy-root-view-controller-pattern)
- [Registrar-Based View Controller Access](#registrar-based-view-controller-access)
- [Migrating Plugin Implementations](#migrating-plugin-implementations)
- [Examples](#examples)
- [Verification & Output Notice](#verification--output-notice)

## Legacy Root View Controller Pattern

Identify usages of direct app-delegate window root view controller access. With the adoption of the `UIScene` lifecycle in iOS, `UIApplication.shared.delegate.window` evaluates to `nil`. 

Locate and replace the following legacy patterns in the codebase:

**Swift:**
```swift
let vc = UIApplication.shared.delegate?.window??.rootViewController
```

**Objective-C:**
```objc
UIViewController *vc = [UIApplication sharedApplication].delegate.window.rootViewController;
```

## Registrar-Based View Controller Access

Update the plugin class to save the `FlutterPluginRegistrar` during registration. Retrieve the active view controller via `registrar.viewController` instead of querying the application delegate. 

If editing existing content, ensure the registrar is passed into the plugin's initializer and stored as a private property.

## Migrating Plugin Implementations

Follow this workflow to migrate a Flutter iOS plugin to support the `UIScene` lifecycle.

**Task Progress Checklist:**
- [ ] 1. Scan the plugin's iOS source files (`.swift` or `.m`) for legacy `UIApplication` window access.
- [ ] 2. Modify the plugin's registration method to inject the `FlutterPluginRegistrar` into the plugin instance.
- [ ] 3. Store the registrar as a private property on the plugin class.
- [ ] 4. Replace all legacy root view controller access with `registrar.viewController`.
- [ ] 5. Run validator -> review errors -> fix (Build the iOS target to ensure no syntax or type errors were introduced).

## Examples

Implement the registrar pattern using the following language-specific examples.

### Swift Implementation

```swift
public class FooPlugin: NSObject, FlutterPlugin {
  private let registrar: FlutterPluginRegistrar

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FooPlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: /* your channel */)
  }

  func accessVC() {
    // Access the view controller via the stored registrar
    registrar.viewController?.present(/* your view controller */, animated: true, completion: nil)
  }
}
```

### Objective-C Implementation

Declare a private property in a class extension within the implementation (`.m`) file.

```objc
@interface FooPlugin ()
@property(nonatomic) NSObject<FlutterPluginRegistrar> *registrar;
@end

@implementation FooPlugin

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  self = [super init];
  if (self) {
    _registrar = registrar;
  }
  return self;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FooPlugin *plugin = [[FooPlugin alloc] initWithRegistrar:registrar];
  [registrar addMethodCallDelegate:plugin channel:/* your channel */];
}

- (void)accessVC {
  // Access the view controller via the stored registrar
  [self.registrar.viewController presentViewController:/* your view controller */ animated:YES completion:nil];
}

@end
```

## Verification & Output Notice

**Disclaimer:** This migration was AI-generated and must be verified for accuracy and completeness. 

Build and run the affected iOS targets (`flutter build ios` or `flutter run`) to confirm the migration compiles successfully and operates correctly within the new `UIScene` lifecycle. Verify that any presented view controllers appear on the active screen as expected.
