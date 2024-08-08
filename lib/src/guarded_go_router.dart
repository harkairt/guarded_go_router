import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/guarded_go_router.dart';
import 'package:guarded_go_router/src/exceptions/follow_up_route_missing_exception.dart';
import 'package:guarded_go_router/src/exceptions/multiple_follow_up_route_exception.dart';
import 'package:guarded_go_router/src/exceptions/multiple_shield_route_exception.dart';
import 'package:guarded_go_router/src/exceptions/shield_route_missing_exception.dart';

typedef DeepLinkHandlingBuilder = Widget Function(BuildContext context, Widget? child);
typedef ChildWidgetBuilder = Widget Function(Widget child);

Widget noOpBuilder(Widget child) => child;

class GuardedGoRouter {
  late List<RouteBase> _routes;
  late Map<GoGuard, String> _shieldRouteNames = {};
  late Map<GoGuard, String?> _follwingRouteNames = {};
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
  /// hook in [GuardedGoRouter]'s [deepLinkBuilder] into [MaterialApp.router]'s [builder].
  final ChildWidgetBuilder routerWrapper;

  late GoRouter goRouter;
  late DeepLinkHandlingBuilder deepLinkBuilder;

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
    this.debugLog = false,
    this.pageWrapper = noOpBuilder,
    this.routerWrapper = noOpBuilder,
  }) : _guards = guards {
    _routes = routes.copyWithTopRoutesHavingForwardSlash;
    _routes = _routes.copyWithAppendedRedirect(debugLog ? _loggingGuardingRedirect : _guardingRedirect);

    _shieldRouteNames = _getShieldRouteNames(_guards, _routes);
    _follwingRouteNames = _getFollowingRouteNames(_guards, _routes);
    _subordinateRouteNames = _getSubordinateRouteNames(_guards, _routes);

    _ensureGuardsThatHaveSubordinatePathsAlsoHaveFollowUpRoute();

    goRouter = buildRouter(
      _routes.removeGuardShells(null).wrapWithShell(pageWrapper),
      (context, state) => latch.protectRedirect(
        context: context,
        state: state,
        fn: (context, state) {
          if (debugLog) {
            timedDebugPrint("👉🏻👉🏻👉🏻 ${state.uri}");
          }
          return null;
        },
        relay: (context, state) {
          if (debugLog) {
            timedDebugPrint(
              "👉🏻👉🏻👉🏻 🟠 ${state.uri} (possible in redirect cycle, removing continue query param)",
            );
          }
          return state.removeContinuePath();
        },
      ),
    );

    deepLinkBuilder = (context, child) {
      return routerWrapper(
        DeepLinkHandler(
          goRouter: goRouter,
          child: child ?? const SizedBox(),
        ),
      );
    };
  }

  String? _loggingGuardingRedirect(BuildContext context, GoRouterState state) {
    final redirectResult = _guardingRedirect(context, state);
    if (redirectResult == null) {
      timedDebugPrint("✋🏾 ${state.uri}");
    } else {
      timedDebugPrint("  ${state.uri} (${state.requireName}) 👉 $redirectResult");
    }
    return redirectResult;
  }

  void _ensureGuardsThatHaveSubordinatePathsAlsoHaveFollowUpRoute() {
    for (final entry in _subordinateRouteNames.entries) {
      final guard = entry.key;
      final _subordinateRouteNames = entry.value;

      if (_subordinateRouteNames.isNotEmpty) {
        if (_follwingRouteNames[guard]?.isEmpty ?? true) {
          throw FollowUpRouteMissingException(guard.runtimeType);
        }
      }
    }
  }

  String? _guardingRedirect(BuildContext context, GoRouterState state) {
    final routeName = state.requireName;
    final routeOfLocation = _routes.traverseFirstWhereOrNull(
      (item) => item is GuardAwareGoRoute && goRouter.isAtLocation(state, item),
    ) as GuardAwareGoRoute?;

    final masterGuards = _getGuardsWhichControlState(state);
    if (masterGuards.isNotEmpty && masterGuards.every((guard) => guard._logPasses(debugLog: debugLog))) {
      final firstFollowUpRouteName = _follwingRouteNames[masterGuards.first];
      if (firstFollowUpRouteName == null) {
        throw FollowUpRouteMissingException(masterGuards.first.runtimeType);
      }

      final queryReplacedFullPath = _replaceParamsInPath(state.fullPath, state.pathParameters);
      if (queryReplacedFullPath == goRouter.namedLocation(state.requireName, pathParameters: state.pathParameters)) {
        return goRouter.namedLocationFrom(state, firstFollowUpRouteName, continuePath: state.uri.toString());
      }
    }

    final guardShells = _getGuardShells(routeName: routeName)
      ..removeWhere((c) => routeOfLocation?.discardedBy.contains(c.guard.runtimeType) ?? false);
    final parentGuards =
        guardShells.where((guardContext) => _getShieldRouteName(guardContext.guard) != routeName).toList();
    if (parentGuards.isNotEmpty) {
      final firstBlockingParent =
          guardShells.firstWhereOrNull((guardContext) => guardContext.guard._logBlocks(debugLog: debugLog));
      if (firstBlockingParent != null) {
        final blockingParentShieldName = _getShieldRouteName(firstBlockingParent.guard);

        final storeAsContinue = !(routeOfLocation?.ignoreAsContinueLocation ?? false);

        final currentGuards = _guards.where((guard) => routeOfLocation?.shieldOf.contains(guard.runtimeType) ?? false);

        if (currentGuards.isEmpty && firstBlockingParent.savesLocation && storeAsContinue && !_isNeglectingContinue) {
          return goRouter.namedLocationCaptureContinue(blockingParentShieldName, state);
        } else {
          return goRouter.namedLocation(blockingParentShieldName, queryParameters: state.uri.queryParameters);
        }
      }
    }

    final currentGuards = _getGuardsOfCurrentShield(state);
    if (currentGuards.isNotEmpty) {
      if (currentGuards.any((guard) => guard._logBlocks(debugLog: debugLog))) {
        return null;
      }

      final firstGuardWichHasFollower = currentGuards.firstWhereOrNull((guard) => _follwingRouteNames[guard] != null);
      if (firstGuardWichHasFollower != null) {
        final followingRouteName = _follwingRouteNames[firstGuardWichHasFollower]!;

        final resolvedContinuePath = state.maybeResolveContinuePath();
        if (resolvedContinuePath == null) {
          return goRouter.namedLocationFrom(state, followingRouteName);
        }
      } else {
        return state.maybeResolveContinuePath();
      }
    }

    final queryReplacedFullPath = _replaceParamsInPath(state.fullPath, state.pathParameters);
    final isAtRedirectOfLeaf = queryReplacedFullPath ==
        goRouter.namedLocation(
          state.requireName,
          pathParameters: state.pathParameters,
        );
    if (isAtRedirectOfLeaf) {
      return state.maybeResolveContinuePath();
    }

    return null;
  }

  String _replaceParamsInPath(String? path, Map<String, String> params) {
    var result = path!;
    for (final entry in params.entries) {
      result = result.replaceAll(":${entry.key}", entry.value);
    }
    return result;
  }

  String _getShieldRouteName(GoGuard guard) {
    final shieldRouteName = _shieldRouteNames[guard];
    if (shieldRouteName == null) {
      throw Exception("There must be a shield route for every guard");
    }
    return shieldRouteName;
  }

  List<GoGuard> _getGuardsWhichControlState(GoRouterState state) {
    final treePath = _routes.getTreePath(routeName: state.requireName) ?? [];
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

  List<GoGuard> _getGuardsOfCurrentShield(GoRouterState state) {
    return _guards.where((guard) => _shieldRouteNames[guard] == state.requireName).toList();
  }

  List<_GuardShell> _getGuardShells({required String routeName}) {
    final treePath = _routes.getTreePath(routeName: routeName);
    if (treePath == null) return [];

    final guardConfigRoutes = treePath.whereType<GuardShell>();
    final guardTypes = guardConfigRoutes.map((r) => r.guardType).toList();
    final guards = _guards.where((g) => guardTypes.contains(g.runtimeType)).toList();
    return guards.map(
      (guard) {
        final shell = guardConfigRoutes.firstWhere((element) => element.guardType == guard.runtimeType);

        return _GuardShell(
          guard: guard,
          savesLocation: shell.savesLocation,
        );
      },
    ).toList();
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
  bool _logPasses({bool debugLog = false}) {
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

  bool _logBlocks({bool debugLog = false}) {
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

class _GuardShell<T extends GoGuard> {
  _GuardShell({
    required this.guard,
    required this.savesLocation,
  });

  final T guard;
  final bool savesLocation;
}
