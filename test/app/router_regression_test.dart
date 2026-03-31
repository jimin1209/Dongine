import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dongine/app/router.dart';

/// GoRouter 설정에 등록된 경로를 순회하며 path 문자열을 수집한다.
List<String> _collectPaths(List<RouteBase> routes) {
  final paths = <String>[];
  for (final route in routes) {
    if (route is GoRoute) {
      paths.add(route.path);
    }
    if (route is StatefulShellRoute) {
      for (final branch in route.branches) {
        paths.addAll(_collectPaths(branch.routes));
      }
    }
    if (route is GoRoute && route.routes.isNotEmpty) {
      paths.addAll(_collectPaths(route.routes));
    }
  }
  return paths;
}

void main() {
  group('GoRouter 경로 등록 검증', () {
    test('initialLocation은 /splash이다', () {
      expect(router.routeInformationProvider.value.uri.path, '/splash');
    });

    test('splash 분기 대상 경로가 모두 등록되어 있다', () {
      final paths = _collectPaths(router.configuration.routes);

      // SplashScreen: 비로그인 → /onboarding, 가족 없음·오류 CTA → /family-setup,
      // 가족 있음 → /home, 인증 오류 CTA → /login (splash_screen.dart와 동기화)
      const splashGoTargets = <String>[
        '/onboarding',
        '/login',
        '/family-setup',
        '/home',
      ];
      expect(paths, contains('/splash'));
      for (final path in splashGoTargets) {
        expect(paths, contains(path), reason: '$path 가 스플래시 라우팅과 일치해야 함');
      }
    });

    test('StatefulShellRoute 탭 경로 5개가 모두 등록되어 있다', () {
      final paths = _collectPaths(router.configuration.routes);

      for (final tab in ['/home', '/chat', '/map', '/files', '/calendar']) {
        expect(paths, contains(tab), reason: '$tab 경로 누락');
      }
    });

    test('바로가기 대상 독립 경로가 모두 등록되어 있다', () {
      final paths = _collectPaths(router.configuration.routes);

      for (final route in [
        '/cart',
        '/expense',
        '/album',
        '/iot',
        '/todo',
        '/settings',
      ]) {
        expect(paths, contains(route), reason: '$route 경로 누락');
      }
    });

    test('album 상세 경로(:albumId)가 등록되어 있다', () {
      final paths = _collectPaths(router.configuration.routes);
      expect(paths, contains('/album/:albumId'));
    });
  });
}
