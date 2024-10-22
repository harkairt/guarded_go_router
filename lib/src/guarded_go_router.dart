import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/guarded_go_router.dart';
import 'package:guarded_go_router/src/exceptions/follow_up_route_missing_exception.dart';
import 'package:guarded_go_router/src/exceptions/missing_discarding_route_for_follow_up_exception.dart';
import 'package:guarded_go_router/src/exceptions/multiple_follow_up_route_exception.dart';
import 'package:guarded_go_router/src/exceptions/multiple_shield_route_exception.dart';
import 'package:guarded_go_router/src/exceptions/shield_route_missing_exception.dart';

typedef DeepLinkHandlingBuilder = Widget Function(BuildContext context, Widget? child);
typedef ChildWidgetBuilder = Widget Function(Widget child);

Widget noOpBuilder(Widget child) => child;

class GuardedGoRouter {
  late List<RouteBase> _routes;
  late Map<GoGuard, String> _shieldRouteNames = {};
  late Map<GoGuard, String?> _followingRouteNames = {};
  late Map<GoGuard, List<String>> _subordinateRouteNames = {};

  final List<GoGuard> _guards;
  final GoRouter Function(
    List<RouteBase> routes,
    FutureOr<String?> Function(BuildContext, GoRouterState)? redirect,
  ) buildRouter;

  /// [pageWrapper] is a workaround for https://github.com/flutter/flutter/issues/111842
  /// Normally this would be a root [GuardShell] but since shell's builder sometimes is not called
  /// now all pages are wrapped with [pageWrapper] instead.
  final ChildWidgetBuilder pageWrapper;

  /// Corresponds to [MaterialApp.router]'s [builder] parameter. Important: for this to take effect you need to
  /// hook in [GuardedGoRouter]'s [appBuilderDelegate] into [MaterialApp.router]'s [builder].
  final ChildWidgetBuilder routerWrapper;

  late GoRouter goRouter;
  late DeepLinkHandlingBuilder appBuilderDelegate;

  final bool debugLog;
  final InfiniteLoopRedirectLatch latch = InfiniteLoopRedirectLatch();

  bool _isNeglectingContinue = false;

  /// Invoke to ignore storing current path as `continue` query parameter.
  /// Implicit navigations triggered by the wrapped method will not store the current location.
  FutureOr<T> neglectContinue<T>(FutureOr<T> Function() fn) async {
    _isNeglectingContinue = true;

    try {
      final result = await fn();
      return result;
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    } finally {
      _isNeglectingContinue = false;
    }
  }

  /// Define [routes] just like to the [GoRouter] constructor.
  /// Additional route types can be used like [GuardAwareGoRoute], [GuardShell] and [DiscardShell].
  ///
  /// [guards] are the guard instances that will be used to protect the routes.
  GuardedGoRouter({
    required List<GoGuard> guards,
    required List<RouteBase> routes,
    required this.buildRouter,
    this.debugLog = true,
    this.pageWrapper = noOpBuilder,
    this.routerWrapper = noOpBuilder,
  }) : _guards = guards {
    _routes = routes.copyWithTopRoutesHavingForwardSlash;
    _routes = _routes.copyWithAppendedRedirect(debugLog ? _loggingGuardingRedirect : _guardingRedirect);

    _shieldRouteNames = _getShieldRouteNames(_guards, _routes);
    _followingRouteNames = _getFollowingRouteNames(_guards, _routes);
    _subordinateRouteNames = _getSubordinateRouteNames(_guards, _routes);

    _ensureGuardsThatHaveSubordinatePathsAlsoHaveFollowUpRoute();
    _ensureGuardsThatHaveFollowUpRoutesAlsoHaveSubordinateRoute();

    goRouter = buildRouter(
      _routes.removeGuardShells(null).wrapWithShell(pageWrapper),
      (context, state) => latch.protectRedirect(
        context: context,
        state: state,
        fn: (context, state) {
          if (debugLog) {
            timedDebugPrint("👉🏻👉🏻👉🏻 ${state.uri.toString().sanitized}");
          }
          return null;
        },
        relay: (context, state) {
          if (debugLog) {
            timedDebugPrint(
              "👉🏻👉🏻👉🏻 🟠 ${state.uri.toString().sanitized} (possible in redirect cycle, removing continue query param)",
            );
          }
          return state.removeContinuePath();
        },
      ),
    );

    appBuilderDelegate = (context, child) => routerWrapper(child ?? const SizedBox());
  }

  String? _loggingGuardingRedirect(BuildContext context, GoRouterState state) {
    final redirectResult = _guardingRedirect(context, state);
    if (redirectResult == null) {
      timedDebugPrint("✋🏾 ${state.uri.toString().sanitized}");
    } else {
      timedDebugPrint("  ${state.uri.toString().sanitized} (${state.requireName}) 👉 ${redirectResult.sanitized}");
    }
    return redirectResult;
  }

  void _ensureGuardsThatHaveSubordinatePathsAlsoHaveFollowUpRoute() {
    for (final entry in _subordinateRouteNames.entries) {
      final guard = entry.key;
      final _subordinateRouteNames = entry.value;

      if (_subordinateRouteNames.isNotEmpty) {
        if (_followingRouteNames[guard]?.isEmpty ?? true) {
          throw FollowUpRouteMissingException(guard.runtimeType);
        }
      }
    }
  }

  void _ensureGuardsThatHaveFollowUpRoutesAlsoHaveSubordinateRoute() {
    for (final entry in _followingRouteNames.entries) {
      final guard = entry.key;
      final followUpRouteName = entry.value;

      if (followUpRouteName != null) {
        final az = _routes.traverseWhere((route) {
          if (route is GuardAwareGoRoute) {
            return route.discardedBy.contains(guard.runtimeType);
          }
          if (route is DiscardShell) {
            return route.guardType == guard.runtimeType;
          }

          return false;
        });
        if (az.isEmpty) {
          throw MissingDiscardingRouteForFollowUpException(guard.runtimeType);
        }
      }
    }
  }

  String? _guardingRedirect(BuildContext context, GoRouterState state) {
    final thisRoute = _routes.traverseFirstWhereOrNull(
      (item) => item is GuardAwareGoRoute && goRouter.isAtLocation(state, item),
    ) as GuardAwareGoRoute?;
    if (thisRoute == null) {
      return null;
    }

    final thisName = thisRoute.name ?? state.name ?? 'missing name';
    final discardingGuards = _getGuardsThatAreDiscardingThisRoute(thisName);

    if (discardingGuards.isNotEmpty && discardingGuards.every((g) => g._logPasses(debugLog))) {
      final firstFollowUpRouteName = _followingRouteNames[discardingGuards.first];

      if (firstFollowUpRouteName == null) {
        throw FollowUpRouteMissingException(discardingGuards.first.runtimeType);
      }

      if (isParentOf(routeName: thisName, maybeParentRouteName: firstFollowUpRouteName)) {
        return null;
      }

      final resolvedContinuePath = state.maybeResolveContinuePath();
      if (resolvedContinuePath != null) {
        if (goRouter.namedLocation(firstFollowUpRouteName) == resolvedContinuePath) {
          return goRouter.namedLocation(
            firstFollowUpRouteName,
            queryParameters: {...state.uri.queryParametersAll}..remove("continue"),
            pathParameters: state.pathParameters,
          );
        }
      }

      return goRouter.namedLocationFrom(
        state: state,
        name: firstFollowUpRouteName,
        destinationPersistence: DestinationPersistence.ignore,
      );
    }

    final enclosingGuards = _getGuardShells(thisName);

    final guardsShieldingOnThisRoute = _guards.where((g) => thisRoute.shieldOf.contains(g.runtimeType));
    if (guardsShieldingOnThisRoute.isNotEmpty) {
      final pre = enclosingGuards.takeWhile((value) => !guardsShieldingOnThisRoute.contains(value.guard));
      final firstBlockingEnclosingGuardBeforeShield = pre.firstWhereOrNull((c) => c.guard._logBlocks(debugLog));
      if (firstBlockingEnclosingGuardBeforeShield == null) {
        if (guardsShieldingOnThisRoute.any((guard) => guard._logBlocks(debugLog))) {
          final continuePath = state.maybeResolveContinuePath();
          if (continuePath == null) {
            return null;
          }

          final thisPath = goRouter.namedLocation(thisName, pathParameters: state.pathParameters);
          if (continuePath == thisPath) {
            return goRouter.namedLocation(
              thisName,
              pathParameters: state.pathParameters,
              queryParameters: state.uri.queryParametersAllWithoutContinue,
            );
          }

          return null;
        }

        return state.maybeResolveContinuePath();
      }
    }

    final firstBlockingGuard = enclosingGuards.firstWhereOrNull((c) => c.guard._logBlocks(debugLog));
    if (firstBlockingGuard != null) {
      final blockingShieldName = _getShieldRouteName(firstBlockingGuard.guard);

      final destinationPersistence = firstBlockingGuard.destinationPersistence;
      final routeIgnoreAsContinue = thisRoute.ignoreAsContinueLocation;

      if (_isNeglectingContinue || routeIgnoreAsContinue) {
        return goRouter.namedLocationFrom(
          state: state,
          name: blockingShieldName,
          destinationPersistence: DestinationPersistence.ignore,
        );
      }

      final resolvedContinuePath = state.maybeResolveContinuePath();
      if (resolvedContinuePath != null) {
        return goRouter.namedLocationFrom(
          state: state,
          name: blockingShieldName,
          destinationPersistence: destinationPersistence,
        );
      }

      return goRouter.namedLocationFrom(
        state: state,
        name: blockingShieldName,
        destinationPersistence: destinationPersistence,
      );
    }

    final it = goRouter.namedLocationFrom(
      state: state,
      name: state.requireName,
      destinationPersistence: DestinationPersistence.clear,
    );
    final isAtRedirectOfLeaf = state.resolvedFullPath == it;
    if (isAtRedirectOfLeaf) {
      return state.maybeResolveContinuePath();
    }

    return null;
  }

  String _getShieldRouteName(GoGuard guard) {
    final shieldRouteName = _shieldRouteNames[guard];
    if (shieldRouteName == null) {
      throw Exception("There must be a shield route for every guard");
    }
    return shieldRouteName;
  }

  List<GoGuard> _getGuardsThatAreDiscardingThisRoute(String name) {
    final treePath = _routes.getTreePath(routeName: name) ?? [];
    final guardTypes = treePath.map((route) {
      if (route is GuardAwareGoRoute) {
        return route.discardedBy;
      }
      if (route is DiscardShell) {
        return [route.guardType];
      }

      return <Type>[];
    }).flattened;

    return _guards.where((guard) => guardTypes.contains(guard.runtimeType)).toList();
  }

  List<_GuardShellContext> _getGuardShells(String routeName) {
    final treePath = _routes.getTreePath(routeName: routeName);
    if (treePath == null) return [];

    final guardShellRoutes = treePath.whereType<GuardShell>();
    final guardTypes = guardShellRoutes.map((r) => r.guardType).toList();
    final guards = _guards.where((g) => guardTypes.contains(g.runtimeType)).toList();
    return guards.map(
      (guard) {
        final shell = guardShellRoutes.firstWhere((element) => element.guardType == guard.runtimeType);
        return _GuardShellContext(
          guard: guard,
          destinationPersistence: shell.destinationPersistence,
        );
      },
    ).toList();
  }

  bool isParentOf({required String routeName, required String maybeParentRouteName}) {
    final treePath = _routes.getTreePath(routeName: routeName);
    if (treePath == null) return false;

    return treePath.where((route) {
      if (route is GuardAwareGoRoute) {
        return route.name == maybeParentRouteName;
      }
      return false;
    }).isNotEmpty;
  }

  static Map<GoGuard, String> _getShieldRouteNames(
    List<GoGuard> guards,
    List<RouteBase> routes,
  ) =>
      Map.fromEntries(
        guards.map((guard) {
          final shieldRoutes = routes.traverseWhere((r) {
            return r is GuardAwareGoRoute && r.shieldOf.contains(guard.runtimeType);
          });
          if (shieldRoutes.isEmpty) {
            throw ShieldRouteMissingException(guard.runtimeType);
          }
          if (shieldRoutes.length > 1) {
            throw MultipleShieldRouteException(guard.runtimeType);
          }
          final routeName = (shieldRoutes.first as GuardAwareGoRoute).name;
          if (routeName == null) {
            throw Exception("Shield route associated with ${guard.runtimeType} does not have a name.");
          }

          return MapEntry(guard, routeName);
        }),
      );

  static Map<GoGuard, String?> _getFollowingRouteNames(
    List<GoGuard> guards,
    List<RouteBase> routes,
  ) =>
      Map.fromEntries(
        guards.map((guard) {
          final followingGoRoutes = routes.traverseWhere((r) {
            return r is GuardAwareGoRoute && r.followUp.contains(guard.runtimeType);
          });

          if (followingGoRoutes.isEmpty) {
            return MapEntry(guard, null);
          }

          if (followingGoRoutes.length > 1) {
            throw MultipleFollowUpRouteException(guard.runtimeType);
          }

          final followingGoRoute = followingGoRoutes.firstOrNull;

          final followingGoRouteName = (followingGoRoute as GoRoute?)?.name;
          if (followingGoRouteName == null) {
            throw Exception("FollowingGoRoute associated with ${guard.runtimeType} does not have a name.");
          }

          return MapEntry(guard, followingGoRouteName);
        }),
      );

  static Map<GoGuard, List<String>> _getSubordinateRouteNames(
    List<GoGuard> guards,
    List<RouteBase> routes,
  ) {
    final List<MapEntry<GoGuard, List<String>>> entries = [];

    for (final guard in guards) {
      final List<RouteBase> subordinateNodeOrSubtree = routes.traverseWhere((r) {
        if (r is GuardAwareGoRoute && r.discardedBy.contains(guard.runtimeType)) {
          return true;
        }
        if (r is DiscardShell && r.guardType == guard.runtimeType) {
          return true;
        }

        return false;
      });

      final subordinateRoutes = subordinateNodeOrSubtree.map((r) {
        if (r is GuardAwareGoRoute && r.discardedBy.contains(guard.runtimeType)) {
          return [r];
        }
        if (r is DiscardShell && r.guardType == guard.runtimeType) {
          return [...r.routes.removeGuardShells(null)];
        }

        return <RouteBase>[];
      }).flattened;

      entries.add(
        MapEntry(
          guard,
          subordinateRoutes
              .map((e) {
                if (e is! GoRoute) {
                  throw "This should be a GoRoute";
                }
                return e.name;
              })
              .whereNotNull()
              .toList(),
        ),
      );
    }

    return Map.fromEntries(entries);
  }
}

extension GoGuardX on GoGuard {
  bool _logPasses(bool debugLog) {
    if (!debugLog) {
      return passes();
    }

    if (passes()) {
      timedDebugPrint('🟢 $runtimeType');
      return true;
    } else {
      timedDebugPrint('🔴 $runtimeType');
      return false;
    }
  }

  bool _logBlocks(bool debugLog) {
    if (!debugLog) {
      return blocks();
    }

    if (blocks()) {
      timedDebugPrint('🔴 $runtimeType');
      return true;
    } else {
      timedDebugPrint('🟢 $runtimeType');
      return false;
    }
  }
}

class _GuardShellContext<T extends GoGuard> {
  _GuardShellContext({
    required this.guard,
    required this.destinationPersistence,
  });

  final T guard;
  final DestinationPersistence destinationPersistence;
}
