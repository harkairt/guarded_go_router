import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef Reader = T Function<T>(ProviderListenable<T> provider);

abstract class GoGuard {
  final Reader read;

  const GoGuard(this.read);

  Future<bool> passes();
  Future<bool> blocks() async => !(await passes());
}
