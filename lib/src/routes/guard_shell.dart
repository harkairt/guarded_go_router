import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/src/go_guard.dart';

class GuardShell<GuardType extends GoGuard> extends ShellRoute {
  /// By default when a destination is protected by a guard, then the router will redirect to
  /// the associated shield route of that guard and also append the original destination as `continue` query param.
  /// When `savesLocation` is set to false, then the original destination is ignored and the app simply redirects to the shield route
  final bool savesLocation;
  final bool clearsContinue;

  GuardShell(
    List<RouteBase> routes, {
    this.savesLocation = true,
    this.clearsContinue = false,
    super.navigatorKey,
  }) : super(routes: routes);

  @override
  Widget Function(
    BuildContext context,
    GoRouterState state,
    Widget child,
  )? get builder => (context, state, child) => child;

  Type get guardType => GuardType;

  GuardShell<GuardType> copyWith({
    List<RouteBase>? routes,
    GlobalKey<NavigatorState>? navigatorKey,
  }) =>
      GuardShell<GuardType>(
        routes ?? this.routes,
        savesLocation: savesLocation,
        clearsContinue: clearsContinue,
        navigatorKey: navigatorKey ?? this.navigatorKey,
      );
}
