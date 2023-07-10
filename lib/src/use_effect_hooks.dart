import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Syntax sugar for omitting the [keys] array.
void useEffectOnce(Dispose? Function() effect) {
  useEffect(
    effect,
    [],
  );
}

/// Syntax sugar for having an effect which returns null
void usePlainEffect(void Function() effect, [List<Object?>? keys]) {
  useEffect(
    () {
      effect();
      return null;
    },
    keys,
  );
}

/// Syntax sugar for omitting the [keys] array and allowing
/// call site to pass the effect as expression body.
void usePlainEffectOnce(void Function() effect) {
  useEffectOnce(
    () {
      effect();
      return null;
    },
  );
}

void usePlainPostFrameEffectOnce(void Function() effect) =>
    usePlainEffectOnce(() => WidgetsBinding.instance.addPostFrameCallback((_) => effect()));

void usePlainPostFrameEffect(void Function() effect, [List<Object?>? keys]) => useEffect(
      () {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => effect(),
        );
        return null;
      },
      keys,
    );

void usePlainAsyncEffect(Future Function() effect) {
  useAsyncEffect(
    () async {
      await effect();
      return null;
    },
    [],
  );
}

void useAsyncEffectOnce(Future<Dispose?> Function() effect) {
  useAsyncEffect(effect, []);
}

void useAsyncEffect(Future<Dispose?> Function() effect, [List<Object?>? keys]) {
  useEffect(
    () {
      final disposeFuture = Future.microtask(effect);
      return () => disposeFuture.then((dispose) => dispose?.call());
    },
    keys,
  );
}
