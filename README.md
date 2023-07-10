# guarded_go_router

This package aims to provide a guard mechanism to a project using `go_router` and `riverpod`. 
Main usage is to enhance the state based declarative routing with certain subtrees being protected by some logic.

## GoGuard

A simple abstract class that the specific guards extend and has to override its `passes(): bool` function.

## GuardedGoRouter

A `GoRouter` proxy. This has a `routes: List<RouteBase>` just like the `GoRouter`.
It accepts not only the standard routes (`GoRoute` and `ShellRoute`) but also some custom route types defined by this package:
- `GuardAwareGoRoute` (extends `GoRoute`)
  - there is a simple `goRoute` function which returns a `GuardAwareGoRoute`
- `GuardShell<T>` and `DiscardShell<T>` (extends `ShellRoute`)

## GoNotifier

A helper class to supply to the `GoRouter`'s `refreshListenable`. 
Providers can be given to it, which, when changing, are triggering the redirect mechanism.

## Concepts

- All guards must have one assigned route which is the shield route. A "shield" is where the guard can be resolved. (`/login` for `AuthGuard`)
  - can be defined via the `GuardAwareGoRoute`'s `shieldOf: Type` parameter
  - if missing then `ShieldRouteMissingException` is thrown, if multiple is defined for a guard then `MultipleShieldRouteException` is thrown.
- A certain subtree can be "protected" by a guard. (only allow `/dashboard` when `AuthGuard` passes)
  - can be defined via `GuardShell<T>`
- A certain subtree can be "discarded" by a guard. (`/get-started` or `/signed-out` does not make sense when `AuthGuard` passes (user is logged in))
  - can be defined via
    - the `GuardAwareGoRoute`'s `discardedBy: List<Type>` parameter
    - or the `DiscardShell<T>` shell route
  - In case of such discarding guard is defined for a subtree, then a "followUp" route has to be defined for said guard using the `followUp: Type` parameter. (otherwise `FollowUpRouteMissingException` is thrown)
    - the followUp route is used when
      - the current route is discarded by all it's parent guards. (in other words all the guards which are defined to be discarding the current route are passing)
      - all the guards whom the current route is a shield route of are passing

## Mechanism

The `routes` given to the `GuardedGoRouter` are analyzed and based on what is their current context, each route's `redirect` is set to a function (the explicitly defined route level `redirect` has higher precedence) which implements above described logic.
The `buildRouter` required parameter is a function which has to return the actul `GoRouter` and in its params there are the `routes`. These routes are the post processed routes that were given to the `GuardedGoRouter`. (with the `redirect` appending logic, and with pruning the `GuardShell` and `DiscardShell` routes)

## Caveat

Consider the following two scenarios:

1. When the user tries to navigate to `/dashboard/:id` but it is protected by `AuthGuard`. Then the system redirects the user to `/login?continue=/dashboard/:id` which is desired in this case (user should get back to where they initially wanted to go once they log in successfully)
2. When the user is at the `/dashboard/:id` and clicks the logout button the redirecting should be triggered (via the `GoNotifier`) and recognize that the current route is guarded, so it has to redirect the user to `/login` although in this case appending the `continue` parameter is undesired, since the user simply wanted to log out.

The redirect mechanism of `go_router` doesn't really know anything about "prior" locations or the "direction" of the user (going from outside -> inside, or inside -> outside)

Because of this in some cases the url has to be cleared manually to discard this `continue` behavior.