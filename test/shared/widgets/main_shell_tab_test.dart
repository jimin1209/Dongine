import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dongine/features/location/domain/location_provider.dart';
import 'package:dongine/shared/widgets/main_shell.dart';

// ---------------------------------------------------------------------------
// 탭 별 스텁 화면
// ---------------------------------------------------------------------------

Widget _stub(String tag) => Scaffold(body: Text(tag));

// ---------------------------------------------------------------------------
// MainShell 전용 라우터: StatefulShellRoute + 5 탭 브랜치
// ---------------------------------------------------------------------------

GoRouter _shellRouter({String initial = '/home'}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home',
                builder: (context, state) => _stub('__tab_home__')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/chat',
                builder: (context, state) => _stub('__tab_chat__')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/map',
                builder: (context, state) => _stub('__tab_map__')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/files',
                builder: (context, state) => _stub('__tab_files__')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/calendar',
                builder: (context, state) => _stub('__tab_calendar__')),
          ]),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Provider overrides: MainShell이 watch하는 최소 provider만 스텁 처리
// ---------------------------------------------------------------------------

List<Override> _shellOverrides() {
  return [
    // MainShell.build에서 watch하는 유일한 provider
    familyLocationTrackingBootstrapProvider.overrideWithValue(null),
  ];
}

Future<void> _pumpShell(WidgetTester tester, {String initial = '/home'}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _shellOverrides(),
      child: MaterialApp.router(routerConfig: _shellRouter(initial: initial)),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MainShell NavigationBar 렌더링', () {
    testWidgets('하단 내비게이션에 5개 탭 라벨이 모두 표시된다', (tester) async {
      await _pumpShell(tester);

      for (final label in ['홈', '채팅', '지도', '파일', '캘린더']) {
        expect(find.text(label), findsOneWidget, reason: '$label 탭 누락');
      }
    });

    testWidgets('초기 탭은 홈(index 0)이다', (tester) async {
      await _pumpShell(tester);

      expect(find.text('__tab_home__'), findsOneWidget);
      // 다른 탭 본문은 보이지 않음
      expect(find.text('__tab_chat__'), findsNothing);
    });
  });

  group('MainShell 탭 전환', () {
    testWidgets('채팅 탭 탭 → 채팅 화면이 표시된다', (tester) async {
      await _pumpShell(tester);

      await tester.tap(find.text('채팅'));
      await tester.pumpAndSettle();

      expect(find.text('__tab_chat__'), findsOneWidget);
      expect(find.text('__tab_home__'), findsNothing);
    });

    testWidgets('지도 탭 탭 → 지도 화면이 표시된다', (tester) async {
      await _pumpShell(tester);

      await tester.tap(find.text('지도'));
      await tester.pumpAndSettle();

      expect(find.text('__tab_map__'), findsOneWidget);
    });

    testWidgets('파일 탭 탭 → 파일 화면이 표시된다', (tester) async {
      await _pumpShell(tester);

      await tester.tap(find.text('파일'));
      await tester.pumpAndSettle();

      expect(find.text('__tab_files__'), findsOneWidget);
    });

    testWidgets('캘린더 탭 탭 → 캘린더 화면이 표시된다', (tester) async {
      await _pumpShell(tester);

      await tester.tap(find.text('캘린더'));
      await tester.pumpAndSettle();

      expect(find.text('__tab_calendar__'), findsOneWidget);
    });

    testWidgets('탭 전환 후 홈 탭 복귀 시 홈 화면이 다시 표시된다', (tester) async {
      await _pumpShell(tester);

      // 채팅으로 이동
      await tester.tap(find.text('채팅'));
      await tester.pumpAndSettle();
      expect(find.text('__tab_chat__'), findsOneWidget);

      // 홈으로 복귀
      await tester.tap(find.text('홈'));
      await tester.pumpAndSettle();
      expect(find.text('__tab_home__'), findsOneWidget);
    });

    testWidgets('여러 탭을 순회해도 마지막 탭이 정상 표시된다', (tester) async {
      await _pumpShell(tester);

      final tabs = ['채팅', '지도', '파일', '캘린더'];
      final stubs = [
        '__tab_chat__',
        '__tab_map__',
        '__tab_files__',
        '__tab_calendar__',
      ];

      for (var i = 0; i < tabs.length; i++) {
        await tester.tap(find.text(tabs[i]));
        await tester.pumpAndSettle();
        expect(find.text(stubs[i]), findsOneWidget, reason: '${tabs[i]} 탭 전환 실패');
      }
    });
  });
}
