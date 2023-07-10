import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/guarded_go_router.dart';

class RouteId {
  final String path;
  final String name;

  const RouteId({required this.path, required this.name});
  const RouteId.path(String path) : this(path: path, name: path);

  GoRoute call<GuardType extends GoGuard>({
    List<Type> shieldOf = const [],
    List<Type> followUp = const [],
    List<Type> discardedBy = const [],
    List<RouteBase> routes = const [],
    Widget Function(BuildContext, GoRouterState)? builder,
    Page<dynamic> Function(BuildContext, GoRouterState)? pageBuilder,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    FutureOr<String?> Function(BuildContext, GoRouterState)? redirect,
    bool ignoreAsContinueLocation = false,
  }) =>
      GuardAwareGoRoute(
        path: path,
        name: name,
        discardedBy: discardedBy,
        shieldOf: shieldOf,
        followUp: followUp,
        routes: routes,
        builder: builder,
        pageBuilder: pageBuilder,
        parentNavigatorKey: parentNavigatorKey,
        redirect: redirect,
        ignoreAsContinueLocation: ignoreAsContinueLocation,
      );
}

class RouteParams {
  static const guid = 'guid';
}
