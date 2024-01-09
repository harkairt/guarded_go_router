import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:guarded_go_router/guarded_go_router.dart';
import 'package:guarded_go_router/src/exceptions/follow_up_route_missing_exception.dart';
import 'package:guarded_go_router/src/exceptions/multiple_follow_up_route_exception.dart';
import 'package:guarded_go_router/src/exceptions/multiple_shield_route_exception.dart';
import 'package:guarded_go_router/src/exceptions/shield_route_missing_exception.dart';
import 'package:mocktail/mocktail.dart';

class AuthGuard extends Mock implements GoGuard {}

class PinGuard extends Mock implements GoGuard {}

class OnboardGuard extends Mock implements GoGuard {}

class Guard1 extends Mock implements GoGuard {}

class Guard2 extends Mock implements GoGuard {}

class Guard3 extends Mock implements GoGuard {}

class Guard4 extends Mock implements GoGuard {}

Widget simpleBuilder(BuildContext context, GoRouterState state) => Container();

void main() {
  late final ChangeNotifier refreshListenable;

  late final AuthGuard authGuard;
  late final PinGuard pinGuard;
  late final OnboardGuard onboardGuard;

  Future<GuardedGoRouter> pumpGuardedRouter(
    WidgetTester tester, {
    String initialLocation = "/",
    required List<RouteBase> routes,
    required List<GoGuard> guards,
  }) async {
    final guardedRouter = GuardedGoRouter(
      guards: guards,
      routes: routes,
      debugLog: true,
      buildRouter: (routes, rootRedirect) {
        return GoRouter(
          redirect: rootRedirect,
          debugLogDiagnostics: true,
          redirectLimit: 20,
          routes: routes,
          initialLocation: initialLocation,
          refreshListenable: refreshListenable,
        );
      },
    );

    final router = guardedRouter.goRouter;

    final app = MaterialApp.router(
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    return guardedRouter;
  }

  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    String initialLocation = "/",
    required List<RouteBase> routes,
    required List<GoGuard> guards,
  }) async {
    final router = await pumpGuardedRouter(tester, initialLocation: initialLocation, routes: routes, guards: guards);
    return router.goRouter;
  }

  void activateGuard({required GoGuard guard}) {
    when(() => guard.passes()).thenReturn(false);
    when(() => guard.blocks()).thenReturn(true);
    refreshListenable.notifyListeners();
  }

  void deactivateGuard({required GoGuard guard}) {
    when(() => guard.passes()).thenReturn(true);
    when(() => guard.blocks()).thenReturn(false);
    refreshListenable.notifyListeners();
  }

  GuardAwareGoRoute _goRoute(
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
    return goRoute(
      name,
      path: path ?? name,
      discardedBy: discardedBy,
      shieldOf: shieldOf,
      followUp: followUp,
      routes: routes,
      builder: builder ?? simpleBuilder,
      pageBuilder: pageBuilder,
      parentNavigatorKey: parentNavigatorKey,
      redirect: redirect,
      ignoreAsContinueLocation: ignoreAsContinueLocation,
    );
  }

  GuardShell<GuardType> _guardShell<GuardType extends GoGuard>(
    List<RouteBase> routes, {
    bool savesLocation = true,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return GuardShell<GuardType>(
      routes,
      savesLocation: savesLocation,
      navigatorKey: navigatorKey,
    );
  }

  DiscardShell<GuardType> _discardShell<GuardType extends GoGuard>(
    List<RouteBase> routes, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return DiscardShell<GuardType>(
      routes,
      navigatorKey: navigatorKey,
    );
  }

  late List<RouteBase> routeTree;

  setUpAll(() {
    refreshListenable = ChangeNotifier();
    authGuard = AuthGuard();
    pinGuard = PinGuard();
    onboardGuard = OnboardGuard();
  });
  setUp(() {
    reset(authGuard);
    activateGuard(guard: authGuard);

    reset(pinGuard);
    activateGuard(guard: pinGuard);

    reset(onboardGuard);
    activateGuard(guard: onboardGuard);

    routeTree = [
      _goRoute("licenses"),
      _goRoute(
        "auth",
        routes: [
          _goRoute(
            "hello",
            discardedBy: const [AuthGuard],
            routes: [
              _goRoute("sub1"),
            ],
          ),
          _goRoute(
            "login",
            shieldOf: [AuthGuard],
            routes: [
              _goRoute("sub2"),
            ],
          ),
          _guardShell<AuthGuard>([
            _goRoute(
              "pin",
              shieldOf: [PinGuard],
            ),
          ]),
        ],
      ),
      _guardShell<AuthGuard>([
        _guardShell<PinGuard>([
          _goRoute(
            "onboard",
            shieldOf: const [OnboardGuard],
            routes: [
              _goRoute("profile"),
              _goRoute("passphrase"),
            ],
          ),
          _guardShell<OnboardGuard>([
            GoRoute(
              path: '/',
              name: 'root',
              builder: simpleBuilder,
              redirect: (context, state) => '/app/dash',
            ),
            _goRoute(
              "app",
              routes: [
                _goRoute("me"),
                _goRoute(
                  "dash",
                  followUp: [AuthGuard],
                  routes: [
                    _goRoute("item"),
                  ],
                ),
                _goRoute(
                  "subscribe",
                  shieldOf: [Guard1, Guard2],
                ),
                _guardShell<Guard1>([
                  _goRoute(
                    "premium-content",
                    followUp: [Guard1],
                  ),
                  _guardShell<Guard2>([
                    _goRoute(
                      "super-premium-content",
                      followUp: [Guard2],
                    ),
                  ]),
                ]),
              ],
            ),
          ]),
        ]),
      ]),
    ];
  });

  group("GuardedGoRouter", () {
    group('Configuration', () {
      testWidgets("when shield path is not defined for a guard then throw", (WidgetTester tester) async {
        expect(
          () => pumpRouter(
            tester,
            initialLocation: '/app/dash',
            guards: [authGuard],
            routes: [_goRoute("app")],
          ),
          throwsA(isA<ShieldRouteMissingException>()),
        );
      });
      testWidgets("when follower path is not defined for a guard then do not throw", (WidgetTester tester) async {
        expect(
          () => pumpRouter(
            tester,
            initialLocation: '/app/dash',
            guards: [authGuard],
            routes: [
              _goRoute("login", shieldOf: [AuthGuard]),
              _goRoute("app"),
            ],
          ),
          returnsNormally,
        );
      });

      testWidgets("when follower path is not defined and guard has a subordinate route then throw",
          (WidgetTester tester) async {
        expect(
          () async {
            await pumpRouter(
              tester,
              initialLocation: '/hello',
              guards: [authGuard],
              routes: [
                _goRoute("hello", discardedBy: [AuthGuard]),
                _goRoute("login", shieldOf: [AuthGuard]),
                _goRoute("app"),
              ],
            );
          },
          throwsA(isA<FollowUpRouteMissingException>()),
        );
      });

      testWidgets("when a guard has more than one shield path then throw", (WidgetTester tester) async {
        expect(
          () async {
            await pumpRouter(
              tester,
              initialLocation: '/hello',
              guards: [authGuard],
              routes: [
                _goRoute("login1", shieldOf: [AuthGuard]),
                _goRoute("login2", shieldOf: [AuthGuard]),
                _goRoute("app1", followUp: [AuthGuard]),
              ],
            );
          },
          throwsA(isA<MultipleShieldRouteException>()),
        );
      });

      testWidgets("when a guard has more than one followUp route then throw", (WidgetTester tester) async {
        expect(
          () async {
            await pumpRouter(
              tester,
              initialLocation: '/hello',
              guards: [authGuard],
              routes: [
                _goRoute("login", shieldOf: [AuthGuard]),
                _goRoute("app1", followUp: [AuthGuard]),
                _goRoute("app2", followUp: [AuthGuard]),
              ],
            );
          },
          throwsA(isA<MultipleFollowUpRouteException>()),
        );
      });
    });

    group('when destination has some discarding guards (defined by "discardedBy")', () {
      late final Guard1 guard1;
      late final Guard2 guard2;

      setUpAll(() {
        guard1 = Guard1();
        guard2 = Guard2();
      });

      group('any() blocks', () {
        setUp(() {
          reset(guard1);
          deactivateGuard(guard: guard1);

          reset(guard2);
          activateGuard(guard: guard2);
        });

        testWidgets("then stay at destination", (WidgetTester tester) async {
          final router = await pumpRouter(
            tester,
            guards: [guard1, guard2],
            routes: [
              _goRoute("shield1", shieldOf: [Guard1]),
              _goRoute("shield2", shieldOf: [Guard2]),
              _goRoute(
                "root",
                discardedBy: [Guard1],
                routes: [
                  _goRoute(
                    "1",
                    discardedBy: [Guard2],
                    routes: [
                      _goRoute(
                        "2",
                        discardedBy: [Guard2],
                        routes: [
                          _goRoute("3"),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              _goRoute("followUp1", followUp: [Guard1]),
              _goRoute("followUp2", followUp: [Guard2]),
            ],
          );

          router.goNamed("3");

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/root/1/2/3");
        });
      });
      group('every() passes', () {
        setUp(() {
          reset(guard1);
          deactivateGuard(guard: guard1);

          reset(guard2);
          deactivateGuard(guard: guard2);
        });
        group('when current route is not a shield path', () {
          testWidgets("then redirect to first guard's followUp", (WidgetTester tester) async {
            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2],
              routes: [
                _goRoute("shield1", shieldOf: [Guard1]),
                _goRoute("shield2", shieldOf: [Guard2]),
                _goRoute(
                  "root",
                  routes: [
                    _goRoute(
                      "1",
                      discardedBy: [Guard1],
                      routes: [
                        _goRoute(
                          "2",
                          discardedBy: [Guard2],
                          routes: [
                            _goRoute("3"),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                _goRoute("followUp1", followUp: [Guard1]),
                _goRoute("followUp2", followUp: [Guard2]),
              ],
            );

            router.goNamed("3");

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/followUp1");
          });
        });
      });
    });

    group('when destination has some discarding guards (defined by DiscardShell)', () {
      late final Guard1 guard1;
      late final Guard2 guard2;

      setUpAll(() {
        guard1 = Guard1();
        guard2 = Guard2();
      });

      group('any() blocks', () {
        setUp(() {
          reset(guard1);
          deactivateGuard(guard: guard1);

          reset(guard2);
          activateGuard(guard: guard2);
        });

        testWidgets("then stay at destination", (WidgetTester tester) async {
          final router = await pumpRouter(
            tester,
            guards: [guard1, guard2],
            routes: [
              _goRoute("shield1", shieldOf: [Guard1]),
              _goRoute("shield2", shieldOf: [Guard2]),
              _discardShell<Guard1>([
                _goRoute(
                  "root",
                  routes: [
                    _discardShell<Guard2>([
                      _goRoute(
                        "1",
                        routes: [
                          _discardShell<Guard2>([
                            _goRoute(
                              "2",
                              discardedBy: [Guard2],
                              routes: [
                                _goRoute("3"),
                              ],
                            ),
                          ]),
                        ],
                      ),
                    ]),
                  ],
                ),
              ]),
              _goRoute("followUp1", followUp: [Guard1]),
              _goRoute("followUp2", followUp: [Guard2]),
            ],
          );

          router.goNamed("3");

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/root/1/2/3");
        });
      });
      group('every() passes', () {
        setUp(() {
          reset(guard1);
          deactivateGuard(guard: guard1);

          reset(guard2);
          deactivateGuard(guard: guard2);
        });
        group('when current route is not a shield path', () {
          testWidgets("then redirect to first guard's followUp", (WidgetTester tester) async {
            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2],
              routes: [
                _goRoute("shield1", shieldOf: [Guard1]),
                _goRoute("shield2", shieldOf: [Guard2]),
                _goRoute(
                  "root",
                  routes: [
                    _discardShell<Guard1>([
                      _goRoute(
                        "1",
                        routes: [
                          _discardShell([
                            _goRoute(
                              "2",
                              discardedBy: [Guard2],
                              routes: [
                                _goRoute("3"),
                              ],
                            ),
                          ]),
                        ],
                      ),
                    ]),
                  ],
                ),
                _goRoute("followUp1", followUp: [Guard1]),
                _goRoute("followUp2", followUp: [Guard2]),
              ],
            );

            router.goNamed("3");

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/followUp1");
          });
        });
      });
    });

    group('when destination has some parent guards', () {
      late final Guard1 guard1;
      late final Guard2 guard2;
      late final Guard3 guard3;
      late final Guard4 guard4;

      setUpAll(() {
        guard1 = Guard1();
        guard2 = Guard2();
        guard3 = Guard3();
        guard4 = Guard4();
      });

      group('any() blocks', () {
        setUp(() {
          reset(guard1);
          deactivateGuard(guard: guard1);

          reset(guard2);
          activateGuard(guard: guard2);

          reset(guard3);
          activateGuard(guard: guard3);
        });

        group('then go to shield route of first blocking guard', () {
          testWidgets("with appending continue param if destination is not a shield path", (WidgetTester tester) async {
            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2],
              routes: [
                _goRoute("shield1", shieldOf: [Guard1]),
                _goRoute("shield2", shieldOf: [Guard2]),
                _goRoute("shield3", shieldOf: [Guard3]),
                _goRoute(
                  "root",
                  routes: [
                    _guardShell<Guard1>([
                      _goRoute(
                        "1",
                        routes: [
                          _guardShell<Guard2>([
                            _goRoute(
                              "2",
                              routes: [
                                _guardShell<Guard3>([
                                  _goRoute("3"),
                                ]),
                              ],
                            ),
                          ]),
                        ],
                      ),
                    ]),
                  ],
                ),
              ],
            );

            router.goNamed("3", queryParameters: <String, dynamic>{"continue": "/route"});

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/shield2?continue=/root/1/2/3?continue=/route");
          });

          testWidgets(
              "with appending continue param if destination is not a shield path, but ignoreAsContinueLocation: true is added to a node in between",
              (WidgetTester tester) async {
            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2],
              routes: [
                _goRoute("shield1", shieldOf: [Guard1]),
                _goRoute("shield2", shieldOf: [Guard2]),
                _goRoute("shield3", shieldOf: [Guard3]),
                _goRoute(
                  "root",
                  routes: [
                    _guardShell<Guard1>([
                      _goRoute(
                        "1",
                        routes: [
                          _guardShell<Guard2>([
                            _goRoute(
                              ignoreAsContinueLocation: true,
                              "2",
                              routes: [
                                _guardShell<Guard3>([
                                  _goRoute(
                                    "3",
                                  ),
                                ]),
                              ],
                            ),
                          ]),
                        ],
                      ),
                    ]),
                  ],
                ),
              ],
            );

            router.goNamed("3", queryParameters: <String, dynamic>{"continue": "/route"});

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/shield2?continue=/root/1/2/3?continue=/route");
          });

          testWidgets(
              "without appending continue param if destination is not a shield path, but ignoreAsContinueLocation: true",
              (WidgetTester tester) async {
            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2],
              routes: [
                _goRoute("shield1", shieldOf: [Guard1]),
                _goRoute("shield2", shieldOf: [Guard2]),
                _goRoute("shield3", shieldOf: [Guard3]),
                _goRoute(
                  "root",
                  routes: [
                    _guardShell<Guard1>([
                      _goRoute(
                        "1",
                        routes: [
                          _guardShell<Guard2>([
                            _goRoute(
                              "2",
                              routes: [
                                _guardShell<Guard3>([
                                  _goRoute(
                                    ignoreAsContinueLocation: true,
                                    "3",
                                  ),
                                ]),
                              ],
                            ),
                          ]),
                        ],
                      ),
                    ]),
                  ],
                ),
              ],
            );

            router.goNamed("3", queryParameters: <String, dynamic>{"continue": "/route"});

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/shield2?continue=/route");
          });

          testWidgets(
              "without appending continue param if destination is protected by a guard which does not save location",
              (WidgetTester tester) async {
            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2],
              routes: [
                _goRoute("shield1", shieldOf: [Guard1]),
                _goRoute("shield2", shieldOf: [Guard2]),
                _goRoute("shield3", shieldOf: [Guard3]),
                _goRoute(
                  "root",
                  routes: [
                    _guardShell<Guard1>([
                      _goRoute(
                        "1",
                        routes: [
                          _guardShell<Guard2>(savesLocation: false, [
                            _goRoute(
                              "2",
                              routes: [
                                _guardShell<Guard3>(
                                  [
                                    _goRoute("3"),
                                  ],
                                ),
                              ],
                            ),
                          ]),
                        ],
                      ),
                    ]),
                  ],
                ),
              ],
            );

            router.goNamed("3", queryParameters: <String, dynamic>{"continue": "/route"});

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/shield2?continue=/route");
          });
          testWidgets(
              "without appending continue param (only taking over existing) if the route redirected from is also a shield of a guard",
              (
            WidgetTester tester,
          ) async {
            reset(guard4);
            deactivateGuard(guard: guard4);

            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2, guard3, guard4],
              routes: [
                _goRoute("shield1", shieldOf: [Guard1]),
                _goRoute("shield2", shieldOf: [Guard2]),
                _goRoute("shield3", shieldOf: [Guard3]),
                _goRoute(
                  "root",
                  routes: [
                    _guardShell<Guard1>([
                      _goRoute(
                        "1",
                        routes: [
                          _guardShell<Guard2>([
                            _goRoute(
                              "2",
                              shieldOf: [Guard4],
                              routes: [
                                _guardShell<Guard3>([
                                  _goRoute("3"),
                                ]),
                              ],
                            ),
                          ]),
                        ],
                      ),
                    ]),
                  ],
                ),
              ],
            );

            router.goNamed("3", queryParameters: <String, dynamic>{"continue": "/route"});

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/shield2?continue=/route");
          });
        });
      });
      group('every() passes', () {
        setUp(() {
          reset(guard1);
          deactivateGuard(guard: guard1);

          reset(guard2);
          deactivateGuard(guard: guard2);

          reset(guard3);
          deactivateGuard(guard: guard3);
        });

        testWidgets('then stay at destination', (WidgetTester tester) async {
          final router = await pumpRouter(
            tester,
            guards: [guard1, guard2, guard3],
            routes: [
              _goRoute("shield1", shieldOf: [Guard1]),
              _goRoute("shield2", shieldOf: [Guard2]),
              _goRoute("shield3", shieldOf: [Guard3]),
              _goRoute(
                "root",
                routes: [
                  _guardShell<Guard1>([
                    _goRoute(
                      "1",
                      routes: [
                        _guardShell<Guard2>([
                          _goRoute(
                            "2",
                            routes: [
                              _guardShell<Guard3>([
                                _goRoute("3"),
                              ]),
                            ],
                          ),
                        ]),
                      ],
                    ),
                  ]),
                ],
              ),
            ],
          );

          router.goNamed("3");

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/root/1/2/3");
        });

        testWidgets('then resolve continue path if exists', (WidgetTester tester) async {
          final router = await pumpRouter(
            tester,
            guards: [guard1, guard2, guard3],
            routes: [
              _goRoute("shield1", shieldOf: [Guard1]),
              _goRoute("shield2", shieldOf: [Guard2]),
              _goRoute("shield3", shieldOf: [Guard3]),
              _goRoute("route"),
              _goRoute(
                "root",
                routes: [
                  _guardShell<Guard1>([
                    _goRoute(
                      "1",
                      routes: [
                        _guardShell<Guard2>([
                          _goRoute(
                            "2",
                            routes: [
                              _guardShell<Guard3>([
                                _goRoute("3"),
                              ]),
                            ],
                          ),
                        ]),
                      ],
                    ),
                  ]),
                ],
              ),
            ],
          );

          router.goNamed("3", queryParameters: <String, dynamic>{"continue": "/route"});

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/route");
        });
      });
    });

    group('when destination is a shield route of some guards', () {
      late final Guard1 guard1;
      late final Guard2 guard2;

      setUpAll(() {
        guard1 = Guard1();
        guard2 = Guard2();
      });

      group('any() blocks', () {
        setUp(() {
          reset(guard1);
          deactivateGuard(guard: guard1);

          reset(guard2);
          activateGuard(guard: guard2);
        });

        testWidgets("then stay at destination", (WidgetTester tester) async {
          final router = await pumpRouter(
            tester,
            guards: [guard1, guard2],
            routes: [
              _goRoute(
                "root",
                routes: [
                  _goRoute(
                    "multi-shield",
                    shieldOf: [Guard1, Guard2],
                  ),
                ],
              ),
              _goRoute("followUp1", followUp: [Guard1]),
              _goRoute("followUp2", followUp: [Guard2]),
              _goRoute("route"),
            ],
          );

          router.goNamed("multi-shield", queryParameters: <String, dynamic>{"continue": "/route"});

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/root/multi-shield?continue=/route");
        });
      });

      group('every() passes', () {
        setUp(() {
          reset(guard1);
          deactivateGuard(guard: guard1);

          reset(guard2);
          deactivateGuard(guard: guard2);
        });

        group('when there is a continue param, then resolve it', () {
          testWidgets('even when no guard has followUp', (WidgetTester tester) async {
            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2],
              routes: [
                _goRoute(
                  "root",
                  routes: [
                    _goRoute(
                      "multi-shield",
                      shieldOf: [Guard1, Guard2],
                    ),
                  ],
                ),
                _goRoute("followUp1"),
                _goRoute("followUp2"),
                _goRoute("route"),
              ],
            );

            router.goNamed("multi-shield", queryParameters: <String, dynamic>{"continue": "/route"});

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/route");
          });
          testWidgets('even when a guard has followUp', (WidgetTester tester) async {
            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2],
              routes: [
                _goRoute(
                  "root",
                  routes: [
                    _goRoute(
                      "multi-shield",
                      shieldOf: [Guard1, Guard2],
                    ),
                  ],
                ),
                _goRoute("followUp1"),
                _goRoute("followUp2", followUp: [Guard2]),
                _goRoute("route"),
              ],
            );

            router.goNamed("multi-shield", queryParameters: <String, dynamic>{"continue": "/route"});

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/route");
          });
        });
        group('when there is no continue param', () {
          testWidgets('redirect to first followUp', (WidgetTester tester) async {
            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2],
              routes: [
                _goRoute(
                  "root",
                  routes: [
                    _goRoute(
                      "multi-shield",
                      shieldOf: [Guard1, Guard2],
                    ),
                  ],
                ),
                _goRoute("followUp1", followUp: [Guard1]),
                _goRoute("followUp2", followUp: [Guard2]),
              ],
            );

            router.goNamed("multi-shield");

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/followUp1");
          });
          testWidgets('when no guard has followUp then stay', (WidgetTester tester) async {
            final router = await pumpRouter(
              tester,
              guards: [guard1, guard2],
              routes: [
                _goRoute(
                  "root",
                  routes: [
                    _goRoute(
                      "multi-shield",
                      shieldOf: [Guard1, Guard2],
                    ),
                  ],
                ),
                _goRoute("followUp1"),
                _goRoute("followUp2"),
              ],
            );

            router.goNamed("multi-shield");

            await tester.pumpAndSettle();
            expect(router.location.sanitized, "/root/multi-shield");
          });
        });
      });
    });
  });

  group(
    "routeTree example",
    () {
      group('initialLocation of /app/dash', () {
        testWidgets('is guarded by AuthGuard', (WidgetTester tester) async {
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            initialLocation: "/app/dash",
            routes: routeTree,
          );

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/login?continue=/app/dash");
        });

        testWidgets('when [AuthGuard] passes then it is guarded by PinGuard', (
          WidgetTester tester,
        ) async {
          deactivateGuard(guard: authGuard);
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            initialLocation: "/app/dash",
            routes: routeTree,
          );

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/dash");
        });

        testWidgets('when [AuthGuard, PinGuard] passes then it is guarded by OnboardGuard', (
          WidgetTester tester,
        ) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            initialLocation: "/app/dash",
            routes: routeTree,
          );
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/onboard?continue=/app/dash");
        });

        testWidgets('when [AuthGuard, PinGuard, OnboardGuard] passes then location succesfully navigates to /app/dash',
            (
          WidgetTester tester,
        ) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          deactivateGuard(guard: onboardGuard);
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            initialLocation: "/app/dash",
            routes: routeTree,
          );

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/app/dash");
        });
      });

      group('initialLocation of / which redirects to /app/dash', () {
        testWidgets('is guarded by AuthGuard', (WidgetTester tester) async {
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/login?continue=/app/dash");
        });

        testWidgets('when [AuthGuard, PinGuard, OnboardGuard] passes then location succesfully navigates to /app/dash',
            (
          WidgetTester tester,
        ) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          deactivateGuard(guard: onboardGuard);
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/app/dash");
        });
      });

      group('explicit goNamed to me', () {
        testWidgets('is guarded by AuthGuard', (WidgetTester tester) async {
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          router.goNamed("me");

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/login?continue=/app/me");
        });

        testWidgets('when [AuthGuard] passes then it is guarded by PinGuard', (
          WidgetTester tester,
        ) async {
          deactivateGuard(guard: authGuard);
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          router.goNamed("me");

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/me");
        });

        testWidgets('when [AuthGuard, PinGuard] passes then it is guarded by OnboardGuard', (
          WidgetTester tester,
        ) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          router.goNamed("me");

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/onboard?continue=/app/me");
        });

        testWidgets('when [AuthGuard, PinGuard, OnboardGuard] passes then location succesfully navigates to /app/me', (
          WidgetTester tester,
        ) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          deactivateGuard(guard: onboardGuard);
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          router.goNamed("me");

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/app/me");
        });

        testWidgets('when guards eventually pass after render then requested path resolves as continue queryParam',
            (WidgetTester tester) async {
          final router = await pumpRouter(
            tester,
            // TODO support / case
            initialLocation: '/app/dash',
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/login?continue=/app/dash");
          router.goNamed("me");
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/login?continue=/app/me");
          deactivateGuard(guard: authGuard);
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/me");
          deactivateGuard(guard: pinGuard);
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/onboard?continue=/app/me");
          deactivateGuard(guard: onboardGuard);
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/app/me");
        });

        testWidgets('queryParameters of current location are kept in continue queryParam', (WidgetTester tester) async {
          final router = await pumpRouter(
            tester,
            initialLocation: '/app/dash',
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/login?continue=/app/dash");
          router.go("/app/me?foo=bar");
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/login?continue=/app/me?foo=bar");
          deactivateGuard(guard: authGuard);
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/me?foo=bar");
          deactivateGuard(guard: pinGuard);
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/onboard?continue=/app/me?foo=bar");
          deactivateGuard(guard: onboardGuard);
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/app/me?foo=bar");
        });
      });

      group('when a guard becomes active', () {
        testWidgets('then current location is stored as continue queryParam', (WidgetTester tester) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          deactivateGuard(guard: onboardGuard);
          final router = await pumpRouter(
            tester,
            initialLocation: '/app/me?foo=bar',
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          activateGuard(guard: pinGuard);

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/me?foo=bar");
        });

        testWidgets(
            'then current location is not stored as continue queryParam if guard got activated inside neglectContinue wrapper',
            (WidgetTester tester) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          deactivateGuard(guard: onboardGuard);
          final router = await pumpGuardedRouter(
            tester,
            initialLocation: '/app/me?foo=bar',
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          router.neglectContinue(() {
            activateGuard(guard: pinGuard);
          });

          await tester.pumpAndSettle();
          expect(router.goRouter.location.sanitized, "/auth/pin?foo=bar");
        });

        testWidgets(
            'then current location is not stored as continue queryParam if guard got async activated inside neglectContinue wrapper',
            (WidgetTester tester) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          deactivateGuard(guard: onboardGuard);
          final router = await pumpGuardedRouter(
            tester,
            initialLocation: '/app/me?foo=bar',
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          await router.neglectContinue(() async {
            await tester.pump(const Duration(seconds: 10));
            activateGuard(guard: pinGuard);
          });

          await tester.pumpAndSettle();
          expect(router.goRouter.location.sanitized, "/auth/pin?foo=bar");
        });

        testWidgets(
            "and another guard with higher precedence becomes active, then the higher order guard's shield is used",
            (WidgetTester tester) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          deactivateGuard(guard: onboardGuard);
          final router = await pumpRouter(
            tester,
            initialLocation: '/app/me?foo=bar',
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          activateGuard(guard: pinGuard);
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/me?foo=bar");
          activateGuard(guard: authGuard);
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/login?continue=/app/me?foo=bar");
        });

        testWidgets("and another guard with lower precedence becomes active, then location does not change",
            (WidgetTester tester) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          deactivateGuard(guard: onboardGuard);
          final router = await pumpRouter(
            tester,
            initialLocation: '/app/me?foo=bar',
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          activateGuard(guard: pinGuard);
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/me?foo=bar");
          activateGuard(guard: onboardGuard);
          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/me?foo=bar");
        });
      });

      group('when a guard is becomes inactive', () {
        testWidgets("then if location is at guard's shield then it gets redirected to following route", (
          WidgetTester tester,
        ) async {
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
            initialLocation: '/auth/login',
          );

          deactivateGuard(guard: authGuard);

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/dash");
        });

        testWidgets("then if location is at guard's shield sub-route then it gets redirected to following route", (
          WidgetTester tester,
        ) async {
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
            initialLocation: '/auth/login/sub2',
          );

          deactivateGuard(guard: authGuard);

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/dash");
        });

        testWidgets(
            "then if location is at guard's shield sub-route with continue then it gets redirected to following route",
            (
          WidgetTester tester,
        ) async {
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
            initialLocation: '/auth/login/sub2?continue=/app/me',
          );

          deactivateGuard(guard: authGuard);

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin?continue=/app/me");
        });

        testWidgets("then if following route is not specified for guard then app stays at guard's shield route", (
          WidgetTester tester,
        ) async {
          deactivateGuard(guard: authGuard);
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
            initialLocation: '/auth/pin',
          );

          deactivateGuard(guard: pinGuard);

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/auth/pin");
        });
        testWidgets(
            "then if following route is not specified for guard, but continue queryParam exists, then app redirects to continue param",
            (
          WidgetTester tester,
        ) async {
          deactivateGuard(guard: authGuard);
          final router = await pumpRouter(
            tester,
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
            initialLocation: '/auth/pin?continue=/licenses',
          );

          deactivateGuard(guard: pinGuard);
          await tester.pumpAndSettle();

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/licenses");
        });
      });

      group("when location is last guard's shield", () {
        testWidgets("when the guard becomes passing, location should stay", (WidgetTester tester) async {
          deactivateGuard(guard: authGuard);
          deactivateGuard(guard: pinGuard);
          final router = await pumpRouter(
            tester,
            initialLocation: '/onboard/passphrase',
            guards: [authGuard, pinGuard, onboardGuard],
            routes: routeTree,
          );

          deactivateGuard(guard: onboardGuard);

          await tester.pumpAndSettle();
          expect(router.location.sanitized, "/onboard/passphrase");
        });
      });

      group('when there is a route which is the shield for 2 guards', () {
        late final List<RouteBase> _routeTree;
        late final Guard1 guard1;
        late final Guard2 guard2;

        setUpAll(() {
          guard1 = Guard1();
          guard2 = Guard2();
        });

        setUp(() {
          reset(guard1);
          activateGuard(guard: guard1);

          reset(guard2);
          activateGuard(guard: guard2);
        });

        _routeTree = [
          _goRoute(
            "initial",
          ),
          _goRoute(
            "shield",
            shieldOf: [Guard1, Guard2],
          ),
          _guardShell<Guard1>([
            _goRoute(
              "guarded-content",
              followUp: [Guard1],
            ),
            _guardShell<Guard2>([
              _goRoute(
                "super-guarded-content",
                followUp: [Guard2],
              ),
            ]),
          ]),
        ];

        group('when guards are initially active', () {
          group('with initial location of /initial and navigation to /shield', () {
            testWidgets('when both guards are active then app stays at shield', (
              WidgetTester tester,
            ) async {
              final router = await pumpRouter(
                tester,
                initialLocation: '/initial',
                guards: [guard1, guard2],
                routes: _routeTree,
              );

              router.goNamed("shield");

              await tester.pumpAndSettle();
              expect(router.location.sanitized, "/shield");
            });

            testWidgets('when first guard passes but second protects then app stays at shield', (
              WidgetTester tester,
            ) async {
              final router = await pumpRouter(
                tester,
                initialLocation: '/initial',
                guards: [guard1, guard2],
                routes: _routeTree,
              );

              deactivateGuard(guard: guard1);
              router.goNamed("shield");

              await tester.pumpAndSettle();
              expect(router.location.sanitized, "/shield");
            });

            testWidgets('when first guard protects but second passes then app stays at shield', (
              WidgetTester tester,
            ) async {
              final router = await pumpRouter(
                tester,
                initialLocation: '/initial',
                guards: [guard1, guard2],
                routes: _routeTree,
              );

              deactivateGuard(guard: guard2);
              router.goNamed("shield");

              await tester.pumpAndSettle();
              expect(router.location.sanitized, "/shield");
            });

            testWidgets('when both guard passes then app forwards to first guards followUp', (
              WidgetTester tester,
            ) async {
              final router = await pumpRouter(
                tester,
                initialLocation: '/initial',
                guards: [guard1, guard2],
                routes: _routeTree,
              );

              deactivateGuard(guard: guard1);
              deactivateGuard(guard: guard2);
              router.goNamed("shield");

              await tester.pumpAndSettle();
              expect(router.location.sanitized, "/guarded-content");
            });
          });
        });
      });

      testWidgets(
          "pin is guarded by AuthGuard, (and also /auth/pin is a shield path) redirect does not append continue queryParam ",
          (
        WidgetTester tester,
      ) async {
        final router = await pumpRouter(
          tester,
          guards: [authGuard, pinGuard, onboardGuard],
          routes: routeTree,
        );

        router.goNamed("pin");

        await tester.pumpAndSettle();
        expect(router.location.sanitized, "/auth/login");
      });

      testWidgets("subordinate path should be redirect away from to first passing guard's following path",
          (WidgetTester tester) async {
        final router = await pumpRouter(
          tester,
          initialLocation: '/app/dash',
          guards: [authGuard, pinGuard, onboardGuard],
          routes: routeTree,
        );
        await tester.pumpAndSettle();
        expect(router.location.sanitized, "/auth/login?continue=/app/dash");
        router.goNamed("hello");
        await tester.pumpAndSettle();
        expect(router.location.sanitized, "/auth/hello");

        deactivateGuard(guard: authGuard);

        await tester.pumpAndSettle();
        expect(router.location.sanitized, "/auth/pin?continue=/app/dash");
      });

      testWidgets("subordinate's sub path should be redirect away from to first passing guard's following path",
          (WidgetTester tester) async {
        final router = await pumpRouter(
          tester,
          initialLocation: '/app/dash',
          guards: [authGuard, pinGuard, onboardGuard],
          routes: routeTree,
        );
        await tester.pumpAndSettle();
        expect(router.location.sanitized, "/auth/login?continue=/app/dash");
        router.go("/auth/hello/sub1");
        await tester.pumpAndSettle();
        expect(router.location.sanitized, "/auth/hello/sub1");

        deactivateGuard(guard: authGuard);

        await tester.pumpAndSettle();
        expect(router.location.sanitized, "/auth/pin?continue=/app/dash");
      });

      group('Configuration', () {
        testWidgets("when shield path is not defined for a guard then throw", (WidgetTester tester) async {
          expect(
            () => pumpRouter(
              tester,
              initialLocation: '/app/dash',
              guards: [authGuard],
              routes: [_goRoute("app")],
            ),
            throwsA(isA<ShieldRouteMissingException>()),
          );
        });
        testWidgets("when follower path is not defined for a guard then do not throw", (WidgetTester tester) async {
          expect(
            () => pumpRouter(
              tester,
              initialLocation: '/app/dash',
              guards: [authGuard],
              routes: [
                _goRoute("login", shieldOf: [AuthGuard]),
                _goRoute("app"),
              ],
            ),
            returnsNormally,
          );
        });

        testWidgets("when follower path is not defined and guard has a subordinate route then throw",
            (WidgetTester tester) async {
          expect(
            () async {
              await pumpRouter(
                tester,
                initialLocation: '/hello',
                guards: [authGuard],
                routes: [
                  _goRoute("hello", discardedBy: [AuthGuard]),
                  _goRoute("login", shieldOf: [AuthGuard]),
                  _goRoute("app"),
                ],
              );
            },
            throwsA(isA<FollowUpRouteMissingException>()),
          );
        });

        testWidgets("when a guard has more than one followUp route then throw", (WidgetTester tester) async {
          expect(
            () async {
              await pumpRouter(
                tester,
                initialLocation: '/hello',
                guards: [authGuard],
                routes: [
                  _goRoute("login", shieldOf: [AuthGuard]),
                  _goRoute("app1", followUp: [AuthGuard]),
                  _goRoute("app2", followUp: [AuthGuard]),
                ],
              );
            },
            throwsA(isA<MultipleFollowUpRouteException>()),
          );
        });
      });
    },
  );
}
