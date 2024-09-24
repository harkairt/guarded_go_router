import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GuardAwareGoRoute extends GoRoute {
  final List<Type> shieldOf;
  final List<Type> followUp;
  final List<Type> discardedBy;
  final bool ignoreAsContinueLocation;

  GuardAwareGoRoute({
    required super.path,
    this.shieldOf = const [],
    this.followUp = const [],
    this.discardedBy = const [],
    this.ignoreAsContinueLocation = false,
    super.name,
    super.builder,
    super.pageBuilder,
    super.parentNavigatorKey,
    super.redirect,
    super.routes,
  });

  GuardAwareGoRoute copyWith({
    String? path,
    Widget Function(BuildContext, GoRouterState)? builder,
    Page<dynamic> Function(BuildContext, GoRouterState)? pageBuilder,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    FutureOr<String?> Function(BuildContext, GoRouterState)? redirect,
    List<RouteBase>? routes,
  }) =>
      GuardAwareGoRoute(
        name: name,
        path: path ?? this.path,
        shieldOf: shieldOf,
        discardedBy: discardedBy,
        followUp: followUp,
        redirect: redirect ?? this.redirect,
        builder: builder ?? this.builder,
        pageBuilder: pageBuilder ?? this.pageBuilder,
        parentNavigatorKey: parentNavigatorKey ?? this.parentNavigatorKey,
        routes: routes ?? this.routes,
        ignoreAsContinueLocation: ignoreAsContinueLocation,
      );

  GuardAwareGoRoute appendRedirect(
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

GuardAwareGoRoute goRoute(
  String name, {
  String? path,
  List<Type> shieldOf = const [],
  List<Type> followUp = const [],
  List<Type> discardedBy = const [],
  List<RouteBase> routes = const [],
  Widget Function(BuildContext, GoRouterState)? builder,
  Page<dynamic> Function(BuildContext, GoRouterState)? pageBuilder,
  GlobalKey<NavigatorState>? parentNavigatorKey,
  FutureOr<String?> Function(BuildContext, GoRouterState)? redirect,
  bool ignoreAsContinueLocation = false,
}) {
  return GuardAwareGoRoute(
    path: path ?? name,
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
