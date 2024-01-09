import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef Reader = T Function<T>(ProviderListenable<T> provider);

abstract class GoGuard {
  final Reader read;

  const GoGuard(this.read);

  bool passes();
  bool blocks() => !passes();
}
