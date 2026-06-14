---
name: flutter-bloc-cubit-feature
description: Scaffold or update Flutter features using flutter_bloc and cubit/bloc state management with a feature-first layered structure. Use when creating a new feature, deciding between Cubit and Bloc, adding Freezed states, wiring repositories, adding route-level BlocProvider/MultiBlocProvider scope, registering dependencies, implementing pagination, handling UI side effects, or adding tests for Bloc/Cubit logic.
metadata:
  model: models/gemini-3.1-pro-preview
---

# Implementing Flutter Bloc/Cubit Features

## Contents
- [Cubit vs Bloc Decision](#cubit-vs-bloc-decision)
- [Feature Structure](#feature-structure)
- [Workflow: Implementing a Feature](#workflow-implementing-a-feature)
- [State, Side Effects, and Errors](#state-side-effects-and-errors)
- [Dependency Injection and Routing](#dependency-injection-and-routing)
- [Pagination](#pagination)
- [Testing](#testing)
- [Examples](#examples)

## Cubit vs Bloc Decision

Choose the lightest state-management primitive that fits the feature.

Use **Cubit** when the flow is mostly command-style methods such as `load`, `refresh`, `submit`, `select`, `update`, or `retry`, and no complex event stream coordination is needed.

Use **Bloc** when the feature has multiple event types, event transformers, debounced input, subscriptions, stream coordination, pagination filters, or richer event/state transitions.

When unclear, start with Cubit. Upgrade to Bloc only when events and transformers make the behavior easier to reason about.

## Feature Structure

Prefer feature-first organization with `data`, `logic`, and `ui` layers. Put Bloc/Cubit files under the feature's `logic` folder.

```text
lib/src/features/<group>/<feature>/
  data/
    models/
    repos/
    datasources/      # optional
  logic/
    cubit/            # default for command-style flows
    bloc/             # event-heavy or stream-heavy flows
    dtos/             # optional
    view_models/      # optional
  ui/
    screens/
    widgets/
    dialogs/          # optional
```

If the target project does not use `lib/src/features/<group>/<feature>`, adapt the folder names to the existing project while preserving the `data` / `logic` / `ui` separation.

## Workflow: Implementing a Feature

Copy this checklist when creating or refactoring a feature.

### Task Progress

- [ ] **Step 1: Inspect the existing project.** Identify feature folder conventions, DI style, routing package, error/result wrappers, and test framework before generating code.
- [ ] **Step 2: Choose Cubit or Bloc.** Use Cubit for linear commands. Use Bloc for event-heavy, stream-heavy, debounced, subscription, or transformer-based flows.
- [ ] **Step 3: Create or update the feature folders.** Place models and repositories in `data`, Bloc/Cubit state logic in `logic`, and screens/widgets/dialogs in `ui`.
- [ ] **Step 4: Implement state with Freezed when available.** Include explicit `initial`, `loading`, `loaded`, `error`, and side-effect states when the project uses Freezed unions.
- [ ] **Step 5: Wire repository calls.** Inject repositories through constructors. Map result wrappers such as `ApiResult<T>.when(...)` into success, error, and transition states.
- [ ] **Step 6: Keep rendering and side effects separate.** Use `BlocBuilder` for rendering and `BlocListener` or `BlocConsumer` for navigation, snackbars, dialogs, overlays, and one-shot effects.
- [ ] **Step 7: Register dependencies.** Register API services if needed, repositories as lazy singletons, and feature Cubits/Blocs as factories unless they intentionally own app-wide runtime state.
- [ ] **Step 8: Add routing scope.** Prefer route-level `BlocProvider` or `MultiBlocProvider`. Use `BlocProvider.value(...)` only to continue an existing in-memory flow across screens.
- [ ] **Step 9: Add tests.** Test emitted state sequences, repository interactions, pagination refresh/failure behavior, and ownership-sensitive decisions.
- [ ] **Step 10: Run generators and tests.** Run `dart run build_runner build --delete-conflicting-outputs` after changing Freezed/JSON/Retrofit annotations, then run `flutter test`.

## State, Side Effects, and Errors

Use explicit state names. Common states are `initial`, `loading`, `loaded`, and `error`. Model one-shot UI effects as state variants when that is the project convention, using names such as `navigateToDetails`, `showSuccess`, `showError`, `hideDialog`, or `itemUpdated`.

Repositories should catch errors, normalize them through the project's error handler, and return the project's result type. Logic should map failures into user-facing error states or listener-handled side effects.

Avoid returning `null` for failures. Emit an explicit error state instead.

## Dependency Injection and Routing

Follow the project's existing DI entrypoint. If the project uses `get_it`, prefer this pattern:

- register API clients/services as lazy singletons
- register repositories as lazy singletons
- register feature Cubits/Blocs as factories
- register app-wide runtime owners as singletons only when they intentionally own shared runtime state

Route-level provider scope is the default for screen-local state. Do not pass shared runtime/session data through route extras when a shared owner already exists. Use typed route extras only for route-local flow state or reusing an active Cubit/Bloc across screens.

## Shared Runtime Ownership

Before adding a new field, helper, or singleton, decide whether the state is shared runtime or feature-local.

Put account/session runtime in a shared owner such as `SessionContextCubit`: current user summary, plan/subscription summary, onboarding flags, account-completion flags, and unread notification count.

Put workspace/store runtime in a shared owner such as `AppModeCubit`: active mode, active workspace/shop/store identifiers, accessible workspaces, and active summaries.

Put derived UX capability checks in a pure entitlement/capability layer such as `SessionEntitlements`. Do not duplicate raw plan-based gating inside feature widgets when an entitlement already models the decision.

Keep feature-owned state in the feature Bloc/Cubit: lists, filters, forms, wizard state, selected tabs, draft edits, pagination controllers, and screen-specific loading/error state.

## Pagination

When using `infinite_scroll_pagination`, own the `PagingController` inside the Cubit or Bloc logic, not in the widget.

- initialize the controller with the project package version's expected callbacks, such as `getNextPageKey` and `fetchPage` when available
- call `refresh()` for reloads
- expose the controller to the UI through the Cubit/Bloc when that is the established convention
- throw or map a `PagingException` on fetch failures when the package supports it
- dispose the controller in `close()`

## Testing

Place unit tests under the project's `test/` tree, mirroring the feature path when possible. Use the project's mocking package, commonly `mocktail`.

Test the important behavior rather than every implementation detail:

- Cubit/Bloc initial state
- emitted state sequence on success
- emitted state sequence on failure
- repository method calls and arguments
- pagination refresh and next-page behavior
- side-effect states such as navigation or success messages
- shared-runtime ownership decisions when the feature reads session, mode, or entitlement state

## Examples

### Minimal Cubit with Freezed State

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/repos/feature_repository.dart';
import '../../../../core/networking/error/api_error_model.dart';

part 'feature_cubit.freezed.dart';
part 'feature_state.dart';

class FeatureCubit extends Cubit<FeatureState> {
  FeatureCubit(this._repository) : super(const FeatureState.initial());

  final FeatureRepository _repository;

  Future<void> loadData() async {
    emit(const FeatureState.loading());

    final result = await _repository.getData();
    result.when(
      success: (data) => emit(FeatureState.loaded(data)),
      failure: (error) => emit(FeatureState.error(error)),
    );
  }
}
```

```dart
part of 'feature_cubit.dart';

@freezed
class FeatureState with _$FeatureState {
  const factory FeatureState.initial() = _Initial;
  const factory FeatureState.loading() = _Loading;
  const factory FeatureState.loaded(FeatureViewData data) = _Loaded;
  const factory FeatureState.error(ApiErrorModel error) = _Error;
  const factory FeatureState.showSuccess(String message) = _ShowSuccess;
}
```

### Route-Level Provider Scope

```dart
GoRoute(
  path: '/feature',
  builder: (context, state) {
    return BlocProvider(
      create: (_) => getIt<FeatureCubit>()..loadData(),
      child: const FeatureScreen(),
    );
  },
)
```

### UI Rendering and Listener Separation

```dart
BlocConsumer<FeatureCubit, FeatureState>(
  listener: (context, state) {
    state.whenOrNull(
      showSuccess: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  },
  builder: (context, state) {
    return state.maybeWhen(
      loading: () => const Center(child: CircularProgressIndicator()),
      loaded: (data) => FeatureContent(data: data),
      error: (error) => ErrorView(message: error.message),
      orElse: () => const SizedBox.shrink(),
    );
  },
)
```

### Bloc When Events Are Richer

```dart
sealed class OrdersEvent {
  const OrdersEvent();
}

final class OrdersStarted extends OrdersEvent {
  const OrdersStarted();
}

final class OrdersFilterChanged extends OrdersEvent {
  const OrdersFilterChanged(this.filter);
  final OrdersFilter filter;
}

final class OrdersRefreshed extends OrdersEvent {
  const OrdersRefreshed();
}

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc(this._repository) : super(const OrdersState.initial()) {
    on<OrdersStarted>(_onStarted);
    on<OrdersFilterChanged>(_onFilterChanged);
    on<OrdersRefreshed>(_onRefreshed);
  }

  final OrdersRepository _repository;

  Future<void> _onStarted(
    OrdersStarted event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersState.loading());
    final result = await _repository.getOrders();
    result.when(
      success: (orders) => emit(OrdersState.loaded(orders)),
      failure: (error) => emit(OrdersState.error(error)),
    );
  }

  Future<void> _onFilterChanged(
    OrdersFilterChanged event,
    Emitter<OrdersState> emit,
  ) async {
    emit(OrdersState.filterChanged(event.filter));
    add(const OrdersRefreshed());
  }

  Future<void> _onRefreshed(
    OrdersRefreshed event,
    Emitter<OrdersState> emit,
  ) async {
    final result = await _repository.getOrders();
    result.when(
      success: (orders) => emit(OrdersState.loaded(orders)),
      failure: (error) => emit(OrdersState.error(error)),
    );
  }
}
```
