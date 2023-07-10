import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/src/go_guard.dart';

class DiscardShell<GuardType extends GoGuard> extends ShellRoute {
  DiscardShell(
    List<RouteBase> routes, {
    super.navigatorKey,
  }) : super(routes: routes);

  @override
  Widget Function(
    BuildContext context,
    GoRouterState state,
    Widget child,
  )? get builder => (context, state, child) => child;

  Type get guardType => GuardType;

  DiscardShell<GuardType> copyWith({
    List<RouteBase>? routes,
    GlobalKey<NavigatorState>? navigatorKey,
  }) =>
      DiscardShell<GuardType>(
        routes ?? this.routes,
        navigatorKey: navigatorKey ?? this.navigatorKey,
      );
}
