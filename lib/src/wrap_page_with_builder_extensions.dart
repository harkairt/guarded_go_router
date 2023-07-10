import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/guarded_go_router.dart';

// The code in this file is mainly to work around the following issue:
// https://github.com/flutter/flutter/issues/111842

extension PageX<T> on Page<T> {
  Page<T> wrapChildWithBuilder(ChildWidgetBuilder builder) {
    if (this is MaterialPage<T>) {
      final page = this as MaterialPage<T>;
      return page.copyWith(child: builder(page.child));
    }
    if (this is CupertinoPage<T>) {
      final page = this as CupertinoPage<T>;
      return page.copyWith(child: builder(page.child));
    }
    if (this is CustomTransitionPage<T>) {
      final page = this as CustomTransitionPage<T>;
      return page.copyWith(child: builder(page.child));
    }

    throw Exception("PageX.wrapChildWithBuilder: Unsupported type $runtimeType");
  }
}

extension MaterialPageX<T> on MaterialPage<T> {
  MaterialPage<T> copyWith({
    Widget? child,
    String? name,
    Object? arguments,
    LocalKey? key,
    String? restorationId,
    bool? maintainState,
    bool? fullscreenDialog,
    bool? allowSnapshotting,
  }) {
    return MaterialPage<T>(
      child: child ?? this.child,
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
      key: key ?? this.key,
      restorationId: restorationId ?? this.restorationId,
      maintainState: maintainState ?? this.maintainState,
      fullscreenDialog: fullscreenDialog ?? this.fullscreenDialog,
      allowSnapshotting: allowSnapshotting ?? this.allowSnapshotting,
    );
  }
}

extension CupertinoPageX<T> on CupertinoPage<T> {
  CupertinoPage<T> copyWith({
    Widget? child,
    String? name,
    String? title,
    Object? arguments,
    LocalKey? key,
    String? restorationId,
    bool? maintainState,
    bool? fullscreenDialog,
    bool? allowSnapshotting,
  }) {
    return CupertinoPage<T>(
      child: child ?? this.child,
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
      key: key ?? this.key,
      restorationId: restorationId ?? this.restorationId,
      maintainState: maintainState ?? this.maintainState,
      fullscreenDialog: fullscreenDialog ?? this.fullscreenDialog,
      allowSnapshotting: allowSnapshotting ?? this.allowSnapshotting,
      title: title ?? this.title,
    );
  }
}

extension CustomTransitionPageX<T> on CustomTransitionPage<T> {
  CustomTransitionPage<T> copyWith({
    Widget? child,
    String? name,
    Object? arguments,
    LocalKey? key,
    String? restorationId,
    bool? maintainState,
    bool? fullscreenDialog,
    Widget Function(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    )?
        transitionsBuilder,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
    String? barrierLabel,
    Color? barrierColor,
    bool? barrierDismissible,
    bool? opaque,
  }) {
    return CustomTransitionPage<T>(
      child: child ?? this.child,
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
      key: key ?? this.key,
      restorationId: restorationId ?? this.restorationId,
      maintainState: maintainState ?? this.maintainState,
      fullscreenDialog: fullscreenDialog ?? this.fullscreenDialog,
      transitionsBuilder: transitionsBuilder ?? this.transitionsBuilder,
      barrierColor: barrierColor ?? this.barrierColor,
      barrierDismissible: barrierDismissible ?? this.barrierDismissible,
      barrierLabel: barrierLabel ?? this.barrierLabel,
      opaque: opaque ?? this.opaque,
      reverseTransitionDuration: reverseTransitionDuration ?? this.reverseTransitionDuration,
      transitionDuration: transitionDuration ?? this.transitionDuration,
    );
  }
}

extension WrapWithShellX on List<RouteBase> {
  List<RouteBase> wrapWithShell(ChildWidgetBuilder builder) {
    return traverseMap((item) => item.copyWithWrapper(builder));
  }
}

extension on RouteBase {
  RouteBase copyWithWrapper(ChildWidgetBuilder builder) {
    if (this is GuardAwareGoRoute) {
      GuardAwareGoRoute route = this as GuardAwareGoRoute;
      final routePageBuilder = route.pageBuilder;

      if (routePageBuilder != null) {
        route = route.copyWith(
          pageBuilder: (BuildContext context, GoRouterState state) {
            return routePageBuilder(context, state).wrapChildWithBuilder(builder);
          },
        );
      }

      final routeBuilder = route.builder;
      if (routeBuilder != null) {
        route = route.copyWith(
          builder: (BuildContext context, GoRouterState state) => builder(routeBuilder(context, state)),
        );
      }

      return route;
    }
    if (this is GoRoute) {
      GoRoute route = this as GoRoute;
      final routePageBuilder = route.pageBuilder;

      if (routePageBuilder != null) {
        route = route.copyWith(
          pageBuilder: (BuildContext context, GoRouterState state) {
            return routePageBuilder(context, state).wrapChildWithBuilder(builder);
          },
        );
      }

      final routeBuilder = route.builder;
      if (routeBuilder != null) {
        route = route.copyWith(
          builder: (BuildContext context, GoRouterState state) => builder(routeBuilder(context, state)),
        );
      }

      return route;
    }

    return this;
  }
}
