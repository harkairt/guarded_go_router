// Import ProviderListenable from misc.dart for Riverpod 3.0
import 'package:hooks_riverpod/misc.dart' show ProviderListenable;

typedef Reader = T Function<T>(ProviderListenable<T> provider);

abstract class GoGuard {
  final Reader read;

  const GoGuard(this.read);

  bool passes();
  bool blocks() => !passes();
}
