import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/guarded_go_router.dart';

extension GoRouteX on GoRoute {
  GoRoute copyWith({
    String? path,
    Widget Function(BuildContext, GoRouterState)? builder,
    Page<dynamic> Function(BuildContext, GoRouterState)? pageBuilder,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    FutureOr<String?> Function(BuildContext, GoRouterState)? redirect,
    List<RouteBase>? routes,
  }) =>
      GoRoute(
        name: name,
        path: path ?? this.path,
        redirect: redirect ?? this.redirect,
        builder: builder ?? this.builder,
        pageBuilder: pageBuilder ?? this.pageBuilder,
        parentNavigatorKey: parentNavigatorKey ?? this.parentNavigatorKey,
        routes: routes ?? this.routes,
      );

  GoRoute appendRedirect(
    FutureOr<String?> Function(BuildContext context, GoRouterState state) redirect,
  ) {
    final existingRedirect = this.redirect;
    if (existingRedirect == null) {
      return copyWith(redirect: (context, state) => redirect(context, state));
    } else {
      return copyWith(
        redirect: (context, state) async {
          final appendedRedirectResult = redirect(context, state);
          if (appendedRedirectResult != null) {
            return appendedRedirectResult;
          }

          final existingRedirectResult = await existingRedirect(context, state);
          if (existingRedirectResult != null) {
            return existingRedirectResult;
          }

          return null;
        },
      );
    }
  }
}

extension ShellRouteX on ShellRoute {
  ShellRoute copyWith({
    Widget Function(BuildContext, GoRouterState, Widget)? builder,
    Page<dynamic> Function(BuildContext, GoRouterState, Widget)? pageBuilder,
    GlobalKey<NavigatorState>? navigatorKey,
    List<RouteBase>? routes,
  }) =>
      ShellRoute(
        builder: builder ?? this.builder,
        pageBuilder: pageBuilder ?? this.pageBuilder,
        routes: routes ?? this.routes,
        navigatorKey: navigatorKey ?? this.navigatorKey,
      );
}

extension StatefulShellBranchX on StatefulShellBranch {
  StatefulShellBranch copyWith({
    List<RouteBase>? routes,
    String? initialLocation,
    GlobalKey<NavigatorState>? navigatorKey,
    List<NavigatorObserver>? observers,
    String? restorationScopeId,
  }) =>
      StatefulShellBranch(
        routes: routes ?? this.routes,
        initialLocation: initialLocation ?? this.initialLocation,
        navigatorKey: navigatorKey ?? this.navigatorKey,
        observers: observers ?? this.observers,
        restorationScopeId: restorationScopeId ?? this.restorationScopeId,
      );
}

extension StatefulShellRouteX on StatefulShellRoute {
  StatefulShellRoute traverseMap(RouteBase Function(RouteBase item) map) {
    return copyWith(branches: branches.traverseMap(map));
  }

  StatefulShellRoute copyWith({
    Widget Function(BuildContext, GoRouterState, Widget)? builder,
    Page<dynamic> Function(BuildContext, GoRouterState, Widget)? pageBuilder,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    Widget Function(BuildContext, StatefulNavigationShell, List<Widget>)? navigatorContainerBuilder,
    List<StatefulShellBranch>? branches,
    String? restorationScopeId,
  }) =>
      StatefulShellRoute(
        parentNavigatorKey: parentNavigatorKey ?? this.parentNavigatorKey,
        builder: builder ?? this.builder,
        pageBuilder: pageBuilder ?? this.pageBuilder,
        navigatorContainerBuilder: navigatorContainerBuilder ?? this.navigatorContainerBuilder,
        branches: branches ?? this.branches,
        restorationScopeId: restorationScopeId ?? this.restorationScopeId,
      );
}

extension RouteBaseX on RouteBase {
  RouteBase copyWithRoutes(List<RouteBase>? routes) {
    if (this is GuardAwareGoRoute) {
      return (this as GuardAwareGoRoute).copyWith(routes: routes);
    }
    if (this is GuardShell) {
      return (this as GuardShell).copyWith(routes: routes);
    }
    if (this is DiscardShell) {
      return (this as DiscardShell).copyWith(routes: routes);
    }
    if (this is ShellRoute) {
      return (this as ShellRoute).copyWith(routes: routes);
    }
    if (this is StatefulShellRoute) {
      throw "Do not use `copyWithRoutes` with StatefulShellRoute, but ensure that all branches are updated.";
    }
    if (this is GoRoute) {
      return (this as GoRoute).copyWith(routes: routes);
    }

    throw Exception("RouteBaseX.copyWithRoutes: Unsupported type $runtimeType");
  }

  RouteBase appendRedirect(
    FutureOr<String?> Function(BuildContext context, GoRouterState state) redirect,
  ) {
    if (this is GuardAwareGoRoute) {
      return (this as GuardAwareGoRoute).appendRedirect(redirect);
    }
    if (this is GoRoute) {
      return (this as GoRoute).appendRedirect(redirect);
    }

    return this;
  }
}

extension RouteBaseListX on List<RouteBase> {
  List<RouteBase> copyWithAppendedRedirect(
    FutureOr<String?> Function(BuildContext context, GoRouterState state) redirect,
  ) =>
      traverseMap((route) => route.appendRedirect(redirect));

  List<RouteBase> get copyWithTopRoutesHavingForwardSlash => mapTopLevelRoutes((route) {
        if (route is GuardAwareGoRoute) {
          if (route.path.startsWith("/")) {
            return route;
          }

          return route.copyWith(path: "/${route.path}");
        }
        if (route is GoRoute) {
          if (route.path.startsWith("/")) {
            return route;
          }

          return route.copyWith(path: "/${route.path}");
        }

        return route;
      }).toList();

  List<RouteBase>? getTreePath({required String routeName}) => findTreePathTillNodeWhere(
        routes: this,
        predicate: (r) => r is GoRoute && r.name == routeName,
      );

  RouteBase? traverseFirstWhereOrNull(bool Function(RouteBase item) test) {
    for (final route in this) {
      if (test(route)) {
        return route;
      }
      final result = route.routes.traverseFirstWhereOrNull(test);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  List<RouteBase> traverseWhere(bool Function(RouteBase item) test) {
    final Set<RouteBase> result = {};

    for (final route in this) {
      if (test(route)) {
        result.add(route);
      }
      result.addAll(route.routes.traverseWhere(test));
    }

    return result.toList();
  }

  void printTree(int depth) {
    for (final route in this) {
      debugPrint("${"   " * depth}$route");
      route.routes.printTree(depth + 1);
    }
  }

  List<RouteBase> traverseMap(RouteBase Function(RouteBase item) map) {
    final result = <RouteBase>[];
    for (final route in this) {
      if (route is StatefulShellRoute) {
        result.add(route.traverseMap(map));
      } else {
        final mappedRoute = map(route.copyWithRoutes(route.routes.traverseMap(map)));
        result.add(mappedRoute);
      }
    }
    return result;
  }

  List<RouteBase> removeGuardShells(RouteBase? parent) {
    final result = <RouteBase>[];
    for (final route in this) {
      if (route is GuardShell) {
        result.addAll(route.routes.removeGuardShells(parent));
      } else if (route is DiscardShell) {
        result.addAll(route.routes.removeGuardShells(parent));
      } else if (route is StatefulShellRoute) {
        result.add(
          route.copyWith(
            branches: route.branches
                .map(
                  (e) => e.copyWith(
                    routes: e.routes.removeGuardShells(null),
                  ),
                )
                .toList(),
          ),
        );
      } else {
        result.add(route.copyWithRoutes(route.routes.removeGuardShells(route)));
      }
    }
    return result;
  }

  List<RouteBase> mapTopLevelRoutes(RouteBase Function(RouteBase item) map) {
    final result = <RouteBase>[];
    for (final route in this) {
      if (route is GoRoute || route is GuardAwareGoRoute) {
        result.add(map(route));
      } else if (route is StatefulShellRoute) {
        final mappedBranches = <StatefulShellBranch>[];

        for (final branch in route.branches) {
          mappedBranches.add(branch.copyWith(routes: branch.routes.mapTopLevelRoutes(map)));
        }

        result.add(route.copyWith(branches: mappedBranches));
      } else {
        result.add(route.copyWithRoutes(route.routes.mapTopLevelRoutes(map)));
      }
    }

    return result;
  }
}

extension StatefulShellBranchListX on List<StatefulShellBranch> {
  List<StatefulShellBranch> traverseMap(RouteBase Function(RouteBase item) map) {
    final result = <StatefulShellBranch>[];

    for (final route in this) {
      result.add(route.copyWith(routes: route.routes.traverseMap(map)));
    }

    return result;
  }
}

extension StringX on String? {
  String? get sanitized =>
      this?.replaceAll("%2F", "/").replaceAll("%3F", "?").replaceAll("%3D", '=').replaceAll("%252F", "/");

  String? setQueryParam(String key, String value) {
    if (this == null) {
      return null;
    }

    final thisUri = Uri.parse(this!);
    final queryParams = Map<String, String>.from(thisUri.queryParameters);
    queryParams[key] = value;

    return Uri(path: this, queryParameters: queryParams).toString();
  }
}

extension GoRouterX on GoRouter {
  String get location {
    return routeInformationProvider.value.uri.toString();
  }

  String? namedLocationFrom(GoRouterState state, String name, {String? continuePath}) {
    return namedLocation(name, pathParameters: state.pathParameters, queryParameters: state.uri.queryParametersAll);
  }

  bool isAtLocation(GoRouterState state, GuardAwareGoRoute item) {
    // This check is because of [namedLocation] is asserting if there is
    // any extra pathParameters which is not required by the matched route.
    // ignore: invalid_use_of_internal_member
    if (listEquals(item.pathParameters, state.pathParameters.keys.toList())) {
      final _location = namedLocation(
        item.name!,
        pathParameters: state.pathParameters,
        queryParameters: state.uri.queryParametersAll,
      );

      return _location.sanitized == state.uri.toString().sanitized;
    }

    return false;
  }

  String? namedLocationCaptureContinue(String name, GoRouterState state) {
    return namedLocation(name, queryParameters: <String, dynamic>{"continue": state.uri.toString()});
  }

  void popOrGoNamed(String name, {Map<String, String> pathParameters = const {}}) {
    if (canPop()) {
      return pop();
    } else {
      goNamed(name, pathParameters: pathParameters);
    }
  }

  void popOrPushReplacementNamed(String name, {Map<String, String> pathParameters = const {}}) {
    if (canPop()) {
      return pop();
    } else {
      pushReplacementNamed(name, pathParameters: pathParameters);
    }
  }
}

List<RouteBase> findTreePathTillNodeWhere({
  required List<RouteBase> routes,
  required bool Function(RouteBase route) predicate,
}) {
  for (final route in routes) {
    if (predicate(route)) {
      return [route];
    } else {
      if (route.routes.isEmpty) {
        continue;
      }
      final childResult = findTreePathTillNodeWhere(routes: route.routes, predicate: predicate);
      if (childResult.isNotEmpty) {
        return [route, ...childResult];
      } else {
        continue;
      }
    }
  }

  return [];
}

extension GoRouterStateX on GoRouterState {
  String? removeContinuePath() {
    final newUri = Uri(
      path: Uri.parse(uri.toString()).path,
      queryParameters: <String, dynamic>{...uri.queryParameters}..remove("continue"),
    );
    return newUri.path;
  }

  String? maybeResolveContinuePath() {
    final continuePath = uri.queryParameters["continue"];
    if (continuePath?.isNotEmpty ?? false) {
      return continuePath;
    }
    return null;
  }

  bool get locationEqualsContinuePath {
    final continuePath = uri.queryParameters["continue"];
    if (continuePath == null || continuePath.isEmpty) {
      return false;
    }

    final currentUri = Uri.parse(uri.toString());
    final continueUri = Uri.parse(continuePath);

    if (currentUri.path == continueUri.path) {
      return true;
    }

    return false;
  }

  String get requireName {
    if (name == null || (name?.isEmpty ?? true)) {
      throw Exception("name is required");
    }
    return name!;
  }

  String get resolvedFullPath {
    var result = fullPath!;
    for (final entry in pathParameters.entries) {
      result = result.replaceAll(":${entry.key}", entry.value);
    }
    return result;
  }
}
