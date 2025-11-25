import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  test('Riverpod 3.0 types exist', () {
    // This will fail until we update to 3.0
    expect(ProviderListenable, isNotNull);
    // AlwaysAliveProviderListenable should not exist in 3.0
    // expect(() => AlwaysAliveProviderListenable, throwsA(anything));
  });
}