import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/src/go_guard.dart';

/// Defines how the destination should be persisted when a guard is activated.
enum DestinationPersistence {
  /// Stores the path as the 'continue' query parameter.
  store,

  /// Ignores the path, meaning it doesn not store it as 'continue' query parameter.
  ignore,

  /// Clears any existing 'continue' query parameter. This is useful when the guard is a "hard" block,
  /// meaning that users are not able to resolve the guard's requirements. So it is not needed to store
  /// where should the user be continued, as they won't be continued to that path.
  /// Eg: A user wanting to access a page to which they are not authorized.
  ///
  /// This option (more strict than the `ignore` option) is needed when the app is deep linked with a continue query param.
  /// Or maybe a previous guard already stored a continue path, although that should resolve itself.
  clear,
}

/// A shell route that applies a guard to its child routes.
class GuardShell<GuardType extends GoGuard> extends ShellRoute {
  /// Determines how the destination should be handled when this guard blocks and it is the first one doing so.
  final DestinationPersistence destinationPersistence;

  GuardShell(
    List<RouteBase> routes, {
    this.destinationPersistence = DestinationPersistence.store,
    super.navigatorKey,
  }) : super(routes: routes);

  @override
  Widget Function(
    BuildContext context,
    GoRouterState state,
    Widget child,
  )? get builder => (context, state, child) => child;

  /// The type of guard associated with this shell.
  Type get guardType => GuardType;

  /// Creates a copy of this [GuardShell] with the given fields replaced with new values.
  GuardShell<GuardType> copyWith({
    List<RouteBase>? routes,
    GlobalKey<NavigatorState>? navigatorKey,
    DestinationPersistence? destinationPersistence,
  }) =>
      GuardShell<GuardType>(
        routes ?? this.routes,
        destinationPersistence: destinationPersistence ?? this.destinationPersistence,
        navigatorKey: navigatorKey ?? this.navigatorKey,
      );
}
