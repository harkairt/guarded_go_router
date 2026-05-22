import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/guarded_go_router.dart';

class RouteId {
  final String path;
  final String name;
  final List<String> pathAliases;

  const RouteId({
    required this.name,
    String? path,
    this.pathAliases = const [],
  }) : path = path ?? name;

  const RouteId.path(String path) : this(name: path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteId &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          name == other.name &&
          listEquals(pathAliases, other.pathAliases);

  @override
  int get hashCode => Object.hash(path, name, Object.hashAll(pathAliases));

  @override
  String toString() => 'RouteId(name: $name, path: $path, pathAliases: $pathAliases)';

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
        pathAliases: pathAliases,
        routes: routes,
        builder: builder,
        pageBuilder: pageBuilder,
        parentNavigatorKey: parentNavigatorKey,
        redirect: redirect,
        ignoreAsContinueLocation: ignoreAsContinueLocation,
      );
}
