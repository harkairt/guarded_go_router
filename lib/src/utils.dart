import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

typedef TransitionBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
);

const kTransitionDuration = Duration(milliseconds: 400);

TransitionBuilder get fadeTrainsitionBuilder =>
    (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child);

TransitionBuilder get bottomUpTrainsitionBuilder => (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    };

Page<T> buildPageWithTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  required TransitionBuilder transitionBuilder,
  bool fullscreenDialog = false,
}) {
  if (!kIsWeb && Platform.isIOS) {
    return CupertinoPage<T>(
      key: state.pageKey,
      child: child,
    );
  }

  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: kTransitionDuration,
    transitionsBuilder: transitionBuilder,
  );
}

Page<T> buildDefaultTransitionPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) =>
    buildPageWithTransition<T>(
      context: context,
      state: state,
      child: child,
      transitionBuilder: fadeTrainsitionBuilder,
    );

Page<T> buildFullScreenDialogPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) =>
    buildPageWithTransition<T>(
      context: context,
      state: state,
      child: child,
      transitionBuilder: bottomUpTrainsitionBuilder,
    );

/// This does not apply to routes nested into a ShellRoute https://github.com/flutter/flutter/issues/113002#issuecomment-1356851427
Page<void> Function(BuildContext, GoRouterState) trans(Widget Function(GoRouterState state) child) {
  return (context, state) => buildDefaultTransitionPage<void>(context: context, state: state, child: child(state));
}

Page<void> Function(BuildContext, GoRouterState) fullScreen(Widget Function(GoRouterState state) child) =>
    (context, state) => buildFullScreenDialogPage<void>(context: context, state: state, child: child(state));

String _formattedCurrentTime() {
  final now = DateTime.now();
  final hours = now.hour.toString().padLeft(2, "0");
  final minutes = now.minute.toString().padLeft(2, "0");
  final seconds = now.second.toString().padLeft(2, "0");
  final milliseconds = now.millisecond.toString().padLeft(3, "0");
  return "$hours:$minutes:$seconds.$milliseconds";
}

void timedDebugPrint(String value) {
  debugPrint("${_formattedCurrentTime()} $value");
}

class InfiniteLoopRedirectLatch {
  final timesCalled = <DateTime>[];

  String? protectRedirect({
    required BuildContext context,
    required GoRouterState state,
    required String? Function(BuildContext context, GoRouterState state) fn,
    required String? Function(BuildContext context, GoRouterState state) relay,
  }) {
    timesCalled.add(DateTime.now());
    if (invokeCount(within: const Duration(milliseconds: 200)) > 30) {
      timesCalled.clear();
      return relay(context, state);
    }
    return fn(context, state);
  }

  int invokeCount({required Duration within}) {
    final now = DateTime.now();
    timesCalled.add(now);
    timesCalled.removeWhere((time) => time.isBefore(now.subtract(const Duration(milliseconds: 200))));
    return timesCalled.length;
  }
}
