import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef Reader = T Function<T>(ProviderListenable<T> provider);

abstract class GoGuard {
  final Reader read;

  const GoGuard(this.read);

  bool passes();
  bool blocks() => !passes();
}
