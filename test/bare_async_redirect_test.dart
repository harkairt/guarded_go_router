import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('should redirect async', () {
    testWidgets('initial location', (tester) async {
      final router = await pumpGoRouter(
        tester,
        initialLocation: '/a',
        routes: [
          GoRoute(
            path: '/a',
            redirect: (context, state) async => Future.delayed(const Duration(milliseconds: 1000), () => '/b'),
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const SizedBox(),
          ),
        ],
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 1000));
      expect(router.routeInformationProvider.value.uri.toString(), '/b');
    });

    testWidgets('explicit go', (tester) async {
      final router = await pumpGoRouter(
        tester,
        routes: [
          GoRoute(
            path: '/a',
            redirect: (context, state) async => Future.delayed(const Duration(milliseconds: 1000), () => '/b'),
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const SizedBox(),
          ),
        ],
      );

      router.go('/a');
      await tester.pumpAndSettle(const Duration(milliseconds: 1000));
      expect(router.routeInformationProvider.value.uri.toString(), '/b');
    });
  });
}

Future<GoRouter> pumpGoRouter(
  WidgetTester tester, {
  String initialLocation = "/",
  required List<RouteBase> routes,
}) async {
  final router = GoRouter(
    debugLogDiagnostics: true,
    redirectLimit: 20,
    routes: routes,
    initialLocation: initialLocation,
  );

  final app = MaterialApp.router(
    routerDelegate: router.routerDelegate,
    routeInformationParser: router.routeInformationParser,
    routeInformationProvider: router.routeInformationProvider,
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  return router;
}
