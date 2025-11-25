# Migration Guide: Riverpod 3.0

This guide helps you migrate from guarded_go_router with Riverpod 2.x to Riverpod 3.0.

## Breaking Changes

### GoNotifier Dependencies Type Change

The `dependencies` parameter of `GoNotifier` now accepts `List<ProviderListenable<Object?>>` instead of `List<AlwaysAliveProviderListenable<Object>>`.

**Before (Riverpod 2.x):**
```dart
final notifier = GoNotifier(
  ref,
  dependencies: [
    myAlwaysAliveProvider, // Only AlwaysAlive providers
  ],
);
```

**After (Riverpod 3.0):**
```dart
final notifier = GoNotifier(
  ref,
  dependencies: [
    myProvider,        // Any provider type
    myStateProvider,   // StateProvider works
    myFutureProvider,  // FutureProvider works
    // All provider types are now supported
  ],
);
```

## Behavioral Changes

1. **Automatic Retry**: Providers now retry automatically on failure by default
2. **Provider Pausing**: Out-of-view providers are paused to save resources
3. **Update Filtering**: Uses `==` operator instead of `identical` for determining if values changed

## Migration Steps

1. Update your `pubspec.yaml` to use the latest guarded_go_router
2. Update any code passing `AlwaysAliveProviderListenable` to use regular providers
3. Test your guards thoroughly as provider update behavior has changed

## Example Migration

```dart
// Before (Riverpod 2.x)
final authProvider = StateProvider.autoDispose<bool>((ref) => false);
final notifier = GoNotifier(
  ref,
  dependencies: [
    // Only specific provider types were supported
    authProvider.select((value) => value),
  ],
);

// After (Riverpod 3.0)
final authProvider = StateProvider<bool>((ref) => false);
final notifier = GoNotifier(
  ref,
  dependencies: [
    authProvider,  // Direct provider reference works
  ],
);
```