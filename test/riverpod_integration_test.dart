import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:guarded_go_router/guarded_go_router.dart';

// Example providers
final authStateProvider = StateProvider<bool>((ref) => false);
final userProvider = Provider<String?>((ref) {
  final isAuth = ref.watch(authStateProvider);
  return isAuth ? 'user123' : null;
});

// Example guard implementation
class TestAuthGuard extends GoGuard {
  TestAuthGuard(Reader read) : super(read);

  @override
  bool passes() => read(authStateProvider);
}

void main() {
  group('GoNotifier Riverpod 3.0 compatibility', () {
    test('accepts any ProviderListenable type', () {
      final container = ProviderContainer();
      final testProvider = StateProvider<int>((ref) => 0);
      final asyncProvider = FutureProvider<String>((ref) async => 'test');

      final notifier = GoNotifier(
        container,
        dependencies: [
          testProvider,
          asyncProvider,
        ],
      );

      expect(notifier.dependencies.length, 2);
      container.dispose();
    });

    test('responds to provider changes', () async {
      final container = ProviderContainer();
      final notifier = GoNotifier(
        container,
        dependencies: [authStateProvider],
      );

      var notificationCount = 0;
      notifier.addListener(() => notificationCount++);

      // Change state
      container.read(authStateProvider.notifier).state = true;
      await Future.delayed(Duration.zero);

      expect(notificationCount, 1);
      container.dispose();
    });

    test('uses == operator for update filtering (Riverpod 3.0 behavior)', () async {
      final container = ProviderContainer();
      final notifier = GoNotifier(
        container,
        dependencies: [authStateProvider],
      );

      var notificationCount = 0;
      notifier.addListener(() => notificationCount++);

      // Set to true
      container.read(authStateProvider.notifier).state = true;
      await Future.delayed(Duration.zero);
      expect(notificationCount, 1);

      // Set to true again - should not trigger due to == operator
      container.read(authStateProvider.notifier).state = true;
      await Future.delayed(Duration.zero);
      expect(notificationCount, 1);

      container.dispose();
    });

    test('Guards can read from providers', () {
      final container = ProviderContainer();
      final guard = TestAuthGuard(container.read);

      expect(guard.passes(), false);
      expect(guard.blocks(), true);

      container.read(authStateProvider.notifier).state = true;

      expect(guard.passes(), true);
      expect(guard.blocks(), false);

      container.dispose();
    });

    test('Multiple provider types work with GoNotifier', () async {
      final container = ProviderContainer();
      final counterProvider = StateProvider<int>((ref) => 0);
      final asyncProvider = FutureProvider<String>((ref) async => 'data');

      final notifier = GoNotifier(
        container,
        dependencies: [
          authStateProvider,
          counterProvider,
          asyncProvider,
        ],
      );

      var notificationCount = 0;
      notifier.addListener(() => notificationCount++);

      // Change different provider types
      container.read(counterProvider.notifier).state++;
      await Future.delayed(Duration.zero);

      expect(notificationCount, greaterThan(0));

      container.dispose();
    });
  });
}