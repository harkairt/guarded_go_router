# Skill: guarded_go_router

Use this skill when working with the `guarded_go_router` package — adding guards, configuring routes, debugging redirect behaviour, writing tests, or explaining how the package works to a developer.

---

## Package purpose

`guarded_go_router` adds a declarative guard layer on top of `go_router` + Riverpod. Guards are boolean conditions derived from Riverpod providers. When a guard blocks, the router redirects to a designated "shield" route (e.g. `/login`) and saves the original destination in `?continue=`. When the guard passes, the user is returned to their destination.

**Dependency versions (current):** `go_router: ^15.1.1`, `hooks_riverpod: ^2.1.3`, `flutter: >=3.29.2`

---

## The three route roles

Every route in the protected tree plays one or more roles:

```
GuardShell<T>  →  route is PROTECTED by guard T
  shieldOf: [T]   →  route RESOLVES guard T (the login/setup screen)
  discardedBy: [T] →  route is IRRELEVANT when guard T passes (e.g. /welcome once logged in)
  followUp: [T]   →  route is the DESTINATION from discarded routes when guard T passes
```

Rules enforced at construction (throws immediately, not at runtime):
- Every guard needs exactly **one** shield route
- Every `discardedBy: [T]` needs exactly **one** `followUp: [T]`
- Every `followUp: [T]` needs at least one `discardedBy: [T]`

---

## Minimal wiring pattern

```dart
// 1. Guard — reads Riverpod state
class AuthGuard extends GoGuard {
  AuthGuard(super.read);
  @override
  bool passes() => read(isAuthenticatedProvider);
}

// 2. Router — inside a Riverpod ConsumerWidget or provider
final guardedRouter = GuardedGoRouter(
  guards: [AuthGuard(ref.read)],
  routes: [
    goRoute('login', shieldOf: [AuthGuard], builder: ...),
    GuardShell<AuthGuard>([
      goRoute('dashboard', builder: ...),
    ]),
  ],
  buildRouter: (routes, rootRedirect) => GoRouter(
    redirect: rootRedirect,   // MUST pass this through
    redirectLimit: 20,
    routes: routes,
    initialLocation: '/dashboard',
    refreshListenable: GoNotifier(ref, dependencies: [isAuthenticatedProvider]),
  ),
);

// 3. App
MaterialApp.router(
  routerDelegate: guardedRouter.goRouter.routerDelegate,
  routeInformationParser: guardedRouter.goRouter.routeInformationParser,
  routeInformationProvider: guardedRouter.goRouter.routeInformationProvider,
  builder: guardedRouter.appBuilderDelegate,  // optional but needed for routerWrapper
)
```

---

## Key classes

### `GoGuard`
```dart
abstract class GoGuard {
  final Reader read;  // T Function<T>(ProviderListenable<T>)
  const GoGuard(this.read);
  bool passes();
  bool blocks() => !passes();
}
```

### `GuardedGoRouter`
```dart
GuardedGoRouter({
  required List<GoGuard> guards,
  required List<RouteBase> routes,
  required GoRouter Function(List<RouteBase>, FutureOr<String?> Function(BuildContext, GoRouterState)?) buildRouter,
  LogCallback? logger,         // void Function(String, {Object? error, StackTrace? stackTrace})
  ChildWidgetBuilder pageWrapper,   // wraps every page (workaround flutter#111842)
  ChildWidgetBuilder routerWrapper, // wraps router output; needs appBuilderDelegate wired in
})

// Members:
GoRouter get goRouter
DeepLinkHandlingBuilder appBuilderDelegate  // → MaterialApp.router builder:
FutureOr<T> neglectContinue<T>(FutureOr<T> Function() fn)  // suppress ?continue= during logout etc.
```

### `GoNotifier`
```dart
GoNotifier(Ref ref, {
  List<ProviderListenable<Object?>> dependencies = const [],
  LogCallback? logger,
})
// Pass to GoRouter.refreshListenable — fires on any provider change → triggers guard re-evaluation
```

### `goRoute()` / `GuardAwareGoRoute`
```dart
goRoute(
  String name, {
  String? path,                        // defaults to name
  List<Type> shieldOf = const [],
  List<Type> followUp = const [],
  List<Type> discardedBy = const [],
  List<String> pathAliases = const [], // /alias → /canonical redirects
  bool ignoreAsContinueLocation = false,
  List<RouteBase> routes = const [],
  Widget Function(BuildContext, GoRouterState)? builder,
  Page<dynamic> Function(BuildContext, GoRouterState)? pageBuilder,
  GlobalKey<NavigatorState>? parentNavigatorKey,
  FutureOr<String?> Function(BuildContext, GoRouterState)? redirect,
  FutureOr<bool> Function(BuildContext, GoRouterState)? onExit,
})
```

### `GuardShell<T>`
```dart
GuardShell<AuthGuard>(
  List<RouteBase> routes, {
  DestinationPersistence destinationPersistence = DestinationPersistence.store,
  // store  → save path as ?continue= (default)
  // ignore → don't save
  // clear  → wipe existing ?continue= (use for hard access-denied blocks)
  GlobalKey<NavigatorState>? navigatorKey,
})
```

### `DiscardShell<T>`
```dart
DiscardShell<AuthGuard>(List<RouteBase> routes, {GlobalKey<NavigatorState>? navigatorKey})
// All children are treated as discardedBy: [AuthGuard]
```

---

## Common patterns

### Auth + onboarding guard chain
```dart
GuardedGoRouter(
  guards: [AuthGuard(ref.read), OnboardGuard(ref.read)],
  routes: [
    goRoute('login',   shieldOf: [AuthGuard],   builder: ...),
    goRoute('onboard', shieldOf: [OnboardGuard], builder: ...),
    DiscardShell<AuthGuard>([
      goRoute('welcome', builder: ...),
    ]),
    GuardShell<AuthGuard>([
      GuardShell<OnboardGuard>([
        goRoute('dashboard', followUp: [AuthGuard, OnboardGuard], builder: ...),
      ]),
    ]),
  ],
  buildRouter: (routes, redirect) => GoRouter(
    redirect: redirect,
    redirectLimit: 20,
    routes: routes,
    initialLocation: '/dashboard',
    refreshListenable: GoNotifier(ref, dependencies: [authProvider, onboardingProvider]),
  ),
);
```

### Shield that is also discarded by same guard
```dart
// Login page disappears once the user is logged in
goRoute('login',
  shieldOf: [AuthGuard],
  discardedBy: [AuthGuard],
  builder: ...)
```

### Path aliases
```dart
goRoute('signup', path: '/signup', pathAliases: ['/register', '/join'], builder: ...)
// /register → /signup, /join → /signup (permanent redirects in the route tree)
```

### Suppressing continue on logout
```dart
// BAD: without neglectContinue, logout from /dashboard → /login?continue=/dashboard
ref.read(authProvider.notifier).logout();

// GOOD:
guardedRouter.neglectContinue(() {
  ref.read(authProvider.notifier).logout();
  guardedRouter.goRouter.go('/login');
});
```

---

## Extension methods (most useful)

```dart
// GoRouterState
state.maybeResolveContinuePath()   // → String? — value of ?continue=
state.removeContinuePath()         // → String? — value, also strips it from URI
state.locationEqualsContinuePath   // → bool
state.requireName                  // → String, throws if null
state.resolvedFullPath             // → String, path params substituted

// GoRouter
router.location                    // → String
router.isAtLocation(state, route)  // → bool
router.popOrGoNamed('home')        // pop or go named
router.popOrPushReplacementNamed('home')

// List<RouteBase>
routes.removeGuardShells(guards)   // strip guard shells (for plain GoRouter use)
routes.getTreePath(routeName: 'x') // → List<RouteBase>? path from root to route
routes.printTree()                 // debug: log tree structure
```

---

## Testing

```dart
class MockAuthGuard extends Mock implements GoGuard {}

final refreshListenable = ChangeNotifier();
final authGuard = MockAuthGuard();

when(() => authGuard.passes()).thenReturn(false);
when(() => authGuard.blocks()).thenReturn(true);

final guardedRouter = GuardedGoRouter(
  guards: [authGuard],
  routes: [...],
  buildRouter: (routes, redirect) => GoRouter(
    redirect: redirect,
    redirectLimit: 20,
    routes: routes,
    initialLocation: '/dashboard',
    refreshListenable: refreshListenable,
  ),
);

// Later, flip the guard:
when(() => authGuard.passes()).thenReturn(true);
when(() => authGuard.blocks()).thenReturn(false);
refreshListenable.notifyListeners();
await tester.pumpAndSettle();
```

---

## Redirect order (internal, useful for debugging)

For each navigation the injected redirect checks in this order:

1. **Discard check** — all discarding guards for this route pass → redirect to `followUp`
2. **Shield check** — this route is a shield → resolve `?continue=` if appropriate
3. **Guard block check** — any enclosing `GuardShell` guard blocks → redirect to that guard's shield with `?continue=`
4. **Infinite loop protection** — >30 redirects in 200ms → strip `?continue=` and break cycle

Your explicit `redirect` on a `GuardAwareGoRoute` runs **after** the guard redirect returns `null` (i.e. guard passes). Use it for route-level redirects that are unrelated to guards.

---

## Checklist: adding a new guard

- [ ] Extend `GoGuard`, implement `passes()` reading from a Riverpod provider
- [ ] Add instance to `GuardedGoRouter.guards`
- [ ] Add exactly one `goRoute(..., shieldOf: [NewGuard], ...)`
- [ ] Wrap protected routes in `GuardShell<NewGuard>([...])`
- [ ] Mark irrelevant routes with `discardedBy: [NewGuard]` or `DiscardShell<NewGuard>([...])`
- [ ] If using `discardedBy`, add exactly one `goRoute(..., followUp: [NewGuard], ...)`
- [ ] Add the relevant provider to `GoNotifier.dependencies`
- [ ] Handle logout/session-end with `neglectContinue` if needed

---

## Exceptions (thrown at construction, not runtime)

| Class | When |
|---|---|
| `ShieldRouteMissingException` | Guard has no shield route |
| `MultipleShieldRouteException` | Guard has >1 shield route |
| `FollowUpRouteMissingException` | `discardedBy` present but no `followUp` |
| `MultipleFollowUpRouteException` | >1 route with same `followUp` guard |
| `MissingDiscardingRouteForFollowUpException` | `followUp` present but no `discardedBy` |

Import exceptions from:
```dart
import 'package:guarded_go_router/src/exceptions/<exception_file>.dart';
```
(not re-exported from the main barrel)
