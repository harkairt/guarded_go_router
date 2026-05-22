import 'package:flutter_test/flutter_test.dart';
import 'package:guarded_go_router/src/route_id.dart';

void main() {
  group('RouteId equality', () {
    test('equal when same name and default path', () {
      const a = RouteId(name: 'home');
      const b = RouteId(name: 'home');
      expect(a, equals(b));
    });

    test('equal when same name, path, and pathAliases', () {
      const a = RouteId(name: 'home', path: '/home', pathAliases: ['/h']);
      const b = RouteId(name: 'home', path: '/home', pathAliases: ['/h']);
      expect(a, equals(b));
    });

    test('not equal when names differ', () {
      const a = RouteId(name: 'home');
      const b = RouteId(name: 'settings');
      expect(a, isNot(equals(b)));
    });

    test('not equal when paths differ', () {
      const a = RouteId(name: 'home', path: '/home');
      const b = RouteId(name: 'home', path: '/dashboard');
      expect(a, isNot(equals(b)));
    });

    test('not equal when pathAliases differ', () {
      const a = RouteId(name: 'home', pathAliases: ['/h']);
      const b = RouteId(name: 'home', pathAliases: ['/ho']);
      expect(a, isNot(equals(b)));
    });

    test('not equal when pathAliases order differs', () {
      const a = RouteId(name: 'home', pathAliases: ['/a', '/b']);
      const b = RouteId(name: 'home', pathAliases: ['/b', '/a']);
      expect(a, isNot(equals(b)));
    });

    test('not equal to non-RouteId object', () {
      const a = RouteId(name: 'home');
      expect(a, isNot(equals('home')));
    });

    test('identical instance is equal', () {
      const a = RouteId(name: 'home');
      expect(a, equals(a));
    });
  });

  group('RouteId hashCode', () {
    test('same for equal instances', () {
      const a = RouteId(name: 'home', path: '/home', pathAliases: ['/h']);
      const b = RouteId(name: 'home', path: '/home', pathAliases: ['/h']);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('works correctly in Set', () {
      const a = RouteId(name: 'home');
      const b = RouteId(name: 'home');
      final set = {a, b};
      expect(set.length, 1);
    });

    test('works correctly as Map key', () {
      const a = RouteId(name: 'home');
      const b = RouteId(name: 'home');
      final map = {a: 'value'};
      expect(map[b], 'value');
    });
  });

  group('RouteId toString', () {
    test('includes all fields', () {
      const id = RouteId(name: 'home', path: '/home', pathAliases: ['/h']);
      expect(id.toString(), 'RouteId(name: home, path: /home, pathAliases: [/h])');
    });

    test('path defaults to name', () {
      const id = RouteId(name: 'home');
      expect(id.toString(), 'RouteId(name: home, path: home, pathAliases: [])');
    });
  });

  group('RouteId constructors', () {
    test('path defaults to name when not provided', () {
      const id = RouteId(name: 'home');
      expect(id.path, 'home');
    });

    test('RouteId.path sets both name and path', () {
      const id = RouteId.path('/home');
      expect(id.name, '/home');
      expect(id.path, '/home');
    });

    test('pathAliases defaults to empty list', () {
      const id = RouteId(name: 'home');
      expect(id.pathAliases, isEmpty);
    });
  });
}
