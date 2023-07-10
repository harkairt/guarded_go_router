import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/src/use_effect_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uni_links/uni_links.dart';

class DeepLinkHandler extends HookConsumerWidget {
  const DeepLinkHandler({
    required this.child,
    required this.goRouter,
    super.key,
  });

  final Widget child;
  final GoRouter goRouter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) {
      return child;
    }

    usePlainAsyncEffect(
      () async {
        final initialUri = await getInitialUri();
        if (initialUri != null) {
          goRouter.go(initialUri.toString());
        }
      },
    );
    useEffectOnce(
      () => uriLinkStream.listen((uri) => goRouter.go(uri.toString())).cancel,
    );
    return child;
  }
}
