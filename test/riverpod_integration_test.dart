import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:guarded_go_router/guarded_go_router.dart';

final testProvider = StateProvider<int>((ref) => 0);
final asyncProvider = FutureProvider<String>((ref) async => 'test');

void main() {
  group('GoNotifier Riverpod 3.0 compatibility', () {
    test('accepts any ProviderListenable type', () {
      final container = ProviderContainer();

      // This should work with any provider type
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
  });
}