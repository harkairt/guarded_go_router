import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef Reader = T Function<T>(ProviderListenable<T> provider);

abstract class GoGuard {
  final Reader read;

  const GoGuard(this.read);

  Future<bool> passes(GoRouterState state);
  Future<bool> blocks(GoRouterState state) async => !(await passes(state));
}
