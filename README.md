# guarded_go_router

A guard mechanism for [`go_router`](https://pub.dev/packages/go_router) powered by [Riverpod](https://pub.dev/packages/hooks_riverpod). Declaratively protect route subtrees behind guards, automatically redirect to a resolution screen when a guard blocks, and return users to their original destination once the guard passes.

**Version:** `0.0.16` — requires `go_router: ^15.1.1`, `hooks_riverpod: ^2.1.3`, Flutter `>=3.29.2`

---

## Mental model

Every guard is a boolean condition derived from Riverpod state.

```
Guard passes → user can access the subtree
Guard blocks → user is redirected to the guard's "shield" route
```

Three concepts build on top of that:

| Concept | What it means | Example |
|---|---|---|
| **Shield route** | Where the user goes to satisfy the guard | `/login` for `AuthGuard` |
| **Discarded route** | A route that makes no sense when the guard passes | `/get-started` once authenticated |
| **Follow-up route** | Where to send the user from a discarded route when the guard passes | `/dashboard` |

When a guard blocks and the user was trying to reach `/dashboard`, the package redirects to `/login?continue=/dashboard`. After the guard passes, the user is returned to `/dashboard` automatically.

---

## Quick start

### 1. Add dependency

```yaml
dependencies:
  guarded_go_router: ^0.0.16
```

### 2. Define a guard

```dart
import 'package:guarded_go_router/guarded_go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// Riverpod provider holding your auth state
final isAuthenticatedProvider = StateProvider<bool>((ref) => false);

class AuthGuard extends GoGuard {
  AuthGuard(super.read);  // super.read is a Riverpod Reader

  @override
  bool passes() => read(isAuthenticatedProvider);
}
```

### 3. Build the router

```dart
// Inside a Riverpod widget / provider:
final guardedRouter = GuardedGoRouter(
  guards: [AuthGuard(ref.read)],
  routes: [
    // Shield: resolves the guard (login page)
    goRoute('login',
      shieldOf: [AuthGuard],
      builder: (context, state) => const LoginPage(),
    ),
    // Protected subtree
    GuardShell<AuthGuard>([
      goRoute('dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      goRoute('profile',
        builder: (context, state) => const ProfilePage(),
      ),
    ]),
  ],
  buildRouter: (routes, rootRedirect) => GoRouter(
    redirect: rootRedirect,       // REQUIRED – inject guard redirect
    redirectLimit: 20,
    routes: routes,
    initialLocation: '/dashboard',
    refreshListenable: GoNotifier(ref, dependencies: [isAuthenticatedProvider]),
  ),
);
```

### 4. Wire into MaterialApp

```dart
MaterialApp.router(
  routerDelegate: guardedRouter.goRouter.routerDelegate,
  routeInformationParser: guardedRouter.goRouter.routeInformationParser,
  routeInformationProvider: guardedRouter.goRouter.routeInformationProvider,
  // Optional: hook in routerWrapper
  builder: guardedRouter.appBuilderDelegate,
)
```

---

## Core API

### `GoGuard`

Abstract base class. Extend it and implement `passes()`.

```dart
abstract class GoGuard {
  final Reader read;  // typedef Reader = T Function<T>(ProviderListenable<T>)
  const GoGuard(this.read);

  bool passes();
  bool blocks() => !passes();  // provided automatically
}
```

The `read` function is a Riverpod `Reader` — pass `ref.read` from your Riverpod scope.

---

### `GuardedGoRouter`

The central object. Wraps GoRouter and manages all guard logic.

```dart
GuardedGoRouter({
  required List<GoGuard> guards,       // guard instances
  required List<RouteBase> routes,     // your route tree
  required GoRouter Function(          // you build the GoRouter here
    List<RouteBase> routes,
    FutureOr<String?> Function(BuildContext, GoRouterState)? redirect,
  ) buildRouter,
  LogCallback? logger,                 // optional: void Function(String, {Object? error, StackTrace? stackTrace})
  ChildWidgetBuilder pageWrapper,      // wraps every page widget (workaround for flutter#111842)
  ChildWidgetBuilder routerWrapper,    // wraps the router output; needs appBuilderDelegate wired in
})
```

**Key members:**

```dart
GoRouter get goRouter                    // the actual GoRouter instance
DeepLinkHandlingBuilder appBuilderDelegate  // pass to MaterialApp.router builder:

FutureOr<T> neglectContinue<T>(FutureOr<T> Function() fn)
// Wraps navigation logic so the current location is NOT saved as `continue`.
// Use this for logout flows where you don't want to return the user to their
// previous guarded location.
```

---

### `GoNotifier`

A `ChangeNotifier` that listens to Riverpod providers and notifies `GoRouter` to re-evaluate guards.

```dart
GoNotifier(
  Ref ref, {
  List<ProviderListenable<Object?>> dependencies = const [],
  LogCallback? logger,
})
```

Pass it to `GoRouter`'s `refreshListenable`. Any change to a listed provider triggers a redirect re-evaluation.

```dart
GoNotifier(ref, dependencies: [authProvider, onboardingProvider, pinProvider])
```

---

### `goRoute()` / `GuardAwareGoRoute`

Drop-in replacement for `GoRoute` with guard metadata.

```dart
goRoute(
  String name, {
  String? path,                       // defaults to name
  List<Type> shieldOf = const [],     // this route is the shield for these guard types
  List<Type> followUp = const [],     // redirect here when a discarded route is accessed and guards pass
  List<Type> discardedBy = const [],  // this route is irrelevant when these guards pass
  List<String> pathAliases = const [], // /alias -> /canonical redirects
  bool ignoreAsContinueLocation = false,  // don't save this path as 'continue'
  List<RouteBase> routes = const [],
  Widget Function(BuildContext, GoRouterState)? builder,
  Page<dynamic> Function(BuildContext, GoRouterState)? pageBuilder,
  GlobalKey<NavigatorState>? parentNavigatorKey,
  FutureOr<String?> Function(BuildContext, GoRouterState)? redirect,
  FutureOr<bool> Function(BuildContext, GoRouterState)? onExit,
})
```

The `name` is used as `GoRoute.name` and as the path when `path` is omitted. The `path` is relative to the parent route, just like in standard `go_router`.

---

### `GuardShell<T>`

Marks all child routes as protected by guard `T`. Extends `ShellRoute`.

```dart
GuardShell<AuthGuard>(
  List<RouteBase> routes, {
  DestinationPersistence destinationPersistence = DestinationPersistence.store,
  GlobalKey<NavigatorState>? navigatorKey,
})
```

`DestinationPersistence` controls what happens to the destination when this guard blocks **and is the first blocking guard**:

| Value | Effect |
|---|---|
| `store` | Save current path as `?continue=` (default) |
| `ignore` | Do not save the path |
| `clear` | Remove any existing `?continue=` param (for hard access-denied blocks) |

---

### `DiscardShell<T>`

Marks all child routes as discarded by guard `T`. Extends `ShellRoute`.

```dart
DiscardShell<AuthGuard>(
  List<RouteBase> routes, {
  GlobalKey<NavigatorState>? navigatorKey,
})
```

Equivalent to setting `discardedBy: [AuthGuard]` on every child individually. Prefer this for grouping multiple discarded routes.

---

## Route relationship rules

These constraints are enforced at construction time (not at runtime):

| Rule | Exception thrown |
|---|---|
| Every guard in `guards` must have **exactly one** shield route | `ShieldRouteMissingException` / `MultipleShieldRouteException` |
| If any route has `followUp: [GuardX]`, at least one route must have `discardedBy: [GuardX]` | `MissingDiscardingRouteForFollowUpException` |
| Each guard can have **at most one** follow-up route | `MultipleFollowUpRouteException` |

---

## Common patterns

### Single auth guard (most common)

```dart
GuardedGoRouter(
  guards: [AuthGuard(ref.read)],
  routes: [
    goRoute('login', shieldOf: [AuthGuard],
      builder: (_, __) => const LoginPage()),

    // Routes irrelevant once logged in
    DiscardShell<AuthGuard>([
      goRoute('welcome', builder: (_, __) => const WelcomePage()),
      goRoute('signup', builder: (_, __) => const SignupPage()),
    ]),

    // Protected routes
    GuardShell<AuthGuard>([
      goRoute('dashboard', followUp: [AuthGuard],  // redirect here from discarded routes
        builder: (_, __) => const DashboardPage()),
      goRoute('profile',
        builder: (_, __) => const ProfilePage()),
    ]),
  ],
  buildRouter: (routes, redirect) => GoRouter(
    redirect: redirect,
    redirectLimit: 20,
    routes: routes,
    initialLocation: '/dashboard',
    refreshListenable: GoNotifier(ref, dependencies: [isAuthenticatedProvider]),
  ),
);
```

**Flow when unauthenticated user visits `/profile`:**
1. `AuthGuard.passes()` → `false`
2. Redirect to `/login?continue=/profile`
3. User logs in → `isAuthenticatedProvider` changes → `GoNotifier` fires → redirect re-evaluated
4. `AuthGuard.passes()` → `true`, `continue=/profile` present → redirect to `/profile`

**Flow when authenticated user visits `/welcome` (discarded):**
1. All discarding guards pass (`AuthGuard.passes()` → `true`)
2. Redirect to `/dashboard` (followUp for `AuthGuard`)

---

### Multiple nested guards

Guards are evaluated in tree order (outermost first). All guards in the path to a route must pass.

```dart
GuardedGoRouter(
  guards: [AuthGuard(ref.read), PinGuard(ref.read), OnboardGuard(ref.read)],
  routes: [
    goRoute('login',   shieldOf: [AuthGuard],   builder: ...),
    goRoute('pin',     shieldOf: [PinGuard],     builder: ...),
    goRoute('onboard', shieldOf: [OnboardGuard], builder: ...),

    GuardShell<AuthGuard>([
      GuardShell<PinGuard>([
        GuardShell<OnboardGuard>([
          goRoute('dashboard',
            followUp: [AuthGuard, PinGuard, OnboardGuard],
            builder: ...),
          goRoute('settings', builder: ...),
        ]),
      ]),
    ]),
  ],
  buildRouter: (routes, redirect) => GoRouter(
    redirect: redirect,
    redirectLimit: 20,
    routes: routes,
    initialLocation: '/dashboard',
    refreshListenable: GoNotifier(ref, dependencies: [
      isAuthenticatedProvider, pinProvider, onboardingProvider,
    ]),
  ),
);
```

If `AuthGuard` blocks, the user goes to `/login`. Once auth passes, the redirect re-runs; if `PinGuard` now blocks, they go to `/pin`. And so on.

---

### A route that is simultaneously shield and discarded

A shield route can also be discarded by the same guard — it disappears once the guard passes.

```dart
goRoute('login',
  shieldOf: [AuthGuard],     // resolves AuthGuard
  discardedBy: [AuthGuard],  // irrelevant once AuthGuard passes
  builder: ...),
```

---

### Path aliases

Redirect alternate URLs to a canonical route:

```dart
goRoute('signup',
  path: '/signup',
  pathAliases: ['/register', '/join'],  // both redirect to /signup
  builder: ...),
```

Aliases work on nested routes too. The alias path is relative to the parent (or absolute when prefixed with `/`).

---

### Disabling `continue` persistence

Three ways to prevent storing the current path in `?continue=`:

```dart
// 1. On a specific route — this route will never become a continue destination
goRoute('checkout', ignoreAsContinueLocation: true, builder: ...)

// 2. On a GuardShell — this guard won't save the destination when it blocks
GuardShell<PaywallGuard>(
  routes,
  destinationPersistence: DestinationPersistence.ignore,
)

// 3. Wrapping imperative navigation — prevents continue being set during this call
guardedRouter.neglectContinue(() {
  guardedRouter.goRouter.go('/home');
});
```

Use `DestinationPersistence.clear` instead of `ignore` when you need to wipe out a `?continue=` that may already be in the URL (e.g., when a hard access-denied guard fires after a deep link with a `continue` param).

---

### Logout (the continue caveat)

`go_router`'s redirect has no concept of navigation direction. When the user logs out:
- They are at `/dashboard`
- Guard re-evaluates → redirects to `/login?continue=/dashboard`
- But the user wanted to log out, not be returned to dashboard after re-login

**Solution:** wrap the logout navigation in `neglectContinue`:

```dart
Future<void> logout() async {
  await ref.read(authProvider.notifier).signOut();

  guardedRouter.neglectContinue(() {
    guardedRouter.goRouter.go('/login');
  });
}
```

Alternatively clear the URL manually or use `DestinationPersistence.ignore`/`clear` on the relevant shell.

---

## `RouteId` helper

`RouteId` is a convenience class to pre-declare route identifiers and build `GuardAwareGoRoute` via a call:

```dart
const dashboardRoute = RouteId(name: 'dashboard', path: '/dashboard');

// Later in your route tree:
dashboardRoute(
  followUp: [AuthGuard],
  builder: (_, __) => const DashboardPage(),
)
```

`RouteId.path(String path)` uses the same string for both name and path.

---

## Extension methods

### `GoRouterState` extensions

```dart
state.maybeResolveContinuePath()     // → String? — the decoded `continue` query param
state.removeContinuePath()           // → String? — same, but also strips it from the URI
state.locationEqualsContinuePath     // → bool — current path == continue path
state.requireName                    // → String — state.name!, throws if absent
state.resolvedFullPath               // → String — full path with path params substituted
```

### `GoRouter` extensions

```dart
router.location                      // → String — current location
router.isAtLocation(state, route)    // → bool — is the router at this GuardAwareGoRoute?
router.namedLocationFrom(            // → String? — build named location; handles continue param
  state: state,
  name: 'profile',
  destinationPersistence: DestinationPersistence.store,
)
router.namedLocationCaptureContinue('dashboard', state)  // → String? — location with ?continue= appended
router.popOrGoNamed('home')          // pop if possible, otherwise go to named route
router.popOrPushReplacementNamed('home')  // pop if possible, otherwise push replacement
```

### `List<RouteBase>` extensions (advanced)

```dart
routes.removeGuardShells(guards)           // strip GuardShell/DiscardShell for plain GoRouter use
routes.withAliasRedirects(...)             // expand pathAliases into real redirect routes
routes.copyWithTopRoutesHavingForwardSlash // ensure top-level paths start with /
routes.traverseWhere(predicate)            // deep filter
routes.traverseFirstWhereOrNull(pred)      // deep find
routes.getTreePath(routeName: 'profile')   // → List<RouteBase>? path from root to named route
routes.printTree()                         // debug: print the full route tree
```

---

## Transition helpers

```dart
// In a pageBuilder:
trans((state) => MyPage(id: state.pathParameters['id']!))
fullScreen((state) => MyModal())

// Custom transitions:
buildPageWithTransition(
  context: context,
  state: state,
  child: MyPage(),
  transitionBuilder: fadeTrainsitionBuilder,  // or bottomUpTrainsitionBuilder
)
```

---

## Testing

Guards implement `GoGuard`, so they can be mocked with `mocktail` or any mock library:

```dart
class MockAuthGuard extends Mock implements GoGuard {}

final authGuard = MockAuthGuard();
when(() => authGuard.passes()).thenReturn(false);
when(() => authGuard.blocks()).thenReturn(true);

final router = GuardedGoRouter(
  guards: [authGuard],
  routes: [...],
  buildRouter: (routes, redirect) => GoRouter(
    redirect: redirect,
    redirectLimit: 20,
    routes: routes,
    initialLocation: '/dashboard',
    refreshListenable: ChangeNotifier(),  // control manually in tests
  ),
);
```

Change guard state by calling `when(...)` again and then notifying the `refreshListenable`:

```dart
when(() => authGuard.passes()).thenReturn(true);
when(() => authGuard.blocks()).thenReturn(false);
refreshListenable.notifyListeners();  // triggers re-evaluation
await tester.pumpAndSettle();
```

---

## Exceptions reference

All exceptions are thrown at `GuardedGoRouter` construction time (fail-fast).

| Exception | Cause |
|---|---|
| `ShieldRouteMissingException` | A guard in `guards` has no route with `shieldOf: [ThatGuard]` |
| `MultipleShieldRouteException` | More than one route has `shieldOf: [SameGuard]` |
| `FollowUpRouteMissingException` | A route has `discardedBy: [GuardX]` but no route has `followUp: [GuardX]` |
| `MultipleFollowUpRouteException` | More than one route has `followUp: [SameGuard]` |
| `MissingDiscardingRouteForFollowUpException` | A route has `followUp: [GuardX]` but nothing is `discardedBy: [GuardX]` |

Exception classes live in `package:guarded_go_router/src/exceptions/` and are not re-exported from the main barrel. Import directly if you need to catch them:

```dart
import 'package:guarded_go_router/src/exceptions/shield_route_missing_exception.dart';
```

---

## How redirect injection works

`GuardedGoRouter` pre-processes your route tree at construction time:

1. **Path normalization** — ensures top-level routes start with `/`
2. **Redirect injection** — appends guard-checking redirect logic to every `GuardAwareGoRoute`; your explicit `redirect` takes precedence (runs after the guard redirect returns `null`)
3. **Alias expansion** — `pathAliases` become real `GoRoute` entries that redirect to the canonical path
4. **Shell removal** — `GuardShell` and `DiscardShell` are stripped; their roles are encoded in the injected redirects
5. **Page wrapping** — `pageWrapper` is applied to every page
6. **Router construction** — the processed routes and root redirect are passed to your `buildRouter` callback

The redirect logic per-route checks (in order):
1. Are all discarding guards passing? → redirect to followUp
2. Is this route a shield? → handle shield-specific logic (resolve continue, etc.)
3. Are any enclosing guards blocking? → redirect to first blocker's shield with `?continue=`
4. Infinite-loop detection (>30 redirects in 200ms) → strip `continue` and break the cycle

---

## Checklist for adding a new guard

- [ ] Create a class extending `GoGuard`, implement `passes()`
- [ ] Add an instance to `GuardedGoRouter.guards`
- [ ] Add one shield route with `shieldOf: [NewGuard]`
- [ ] Wrap protected routes in `GuardShell<NewGuard>([...])`
- [ ] If any routes should be discarded: mark them with `discardedBy: [NewGuard]` or `DiscardShell<NewGuard>`
- [ ] If you used discardedBy: define exactly one `followUp: [NewGuard]` route
- [ ] Add the relevant provider to `GoNotifier.dependencies`
- [ ] Handle the logout/sign-out flow with `neglectContinue` if needed
