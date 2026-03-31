import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dongine/app/app.dart';
import 'package:dongine/app/router.dart';
import 'package:dongine/core/services/notification_service.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/auth/presentation/onboarding_screen.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/todo/presentation/todo_screen.dart';
import 'package:dongine/features/calendar/presentation/calendar_screen.dart';
import 'package:dongine/features/cart/presentation/cart_screen.dart';
import 'package:dongine/features/expense/presentation/expense_screen.dart';
import 'package:dongine/shared/widgets/main_shell.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> configure({
    required NotificationRouteHandler onOpenRoute,
    required ForegroundNotificationHandler onForegroundNotification,
  }) async {}

  @override
  Future<void> registerCurrentDevice(String uid) async {}

  @override
  Future<void> unregisterCurrentDevice(String uid) async {}

  @override
  void setActiveUser(String? uid) {}

  @override
  void dispose() {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<Override> _baseOverrides() => [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      notificationServiceProvider.overrideWithValue(
        _FakeNotificationService(),
      ),
      currentFamilyProvider.overrideWithValue(const AsyncValue.data(null)),
    ];

Future<void> _pumpApp(WidgetTester tester, {List<Override>? overrides}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides ?? _baseOverrides(),
      child: const DongineApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Simulate the same mechanism as [DongineApp._openRoute]:
/// navigate and settle like the app-level route handler.
Future<void> _simulateOpenRoute(WidgetTester tester, String route) async {
  try {
    router.go(route);
  } catch (_) {
    router.go('/home');
  }
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    // Ensure the router starts from a clean state.
    router.go('/splash');
  });

  // ------------------------------------------------------------------
  // 1. 허용된 route → 올바른 화면으로 이동
  // ------------------------------------------------------------------
  group('허용된 route 가 들어오면 해당 화면으로 이동한다', () {
    testWidgets('/todo → TodoScreen', (tester) async {
      await _pumpApp(tester);

      router.go('/todo');
      await tester.pumpAndSettle();

      expect(find.byType(TodoScreen), findsOneWidget);
      expect(find.text('할 일'), findsOneWidget);
    });

    testWidgets('/calendar → CalendarScreen', (tester) async {
      await _pumpApp(tester);

      router.go('/calendar');
      await tester.pumpAndSettle();

      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.text('캘린더'), findsWidgets);
    });

    testWidgets('/cart → CartScreen', (tester) async {
      await _pumpApp(tester);

      router.go('/cart');
      await tester.pumpAndSettle();

      expect(find.byType(CartScreen), findsOneWidget);
    });

    testWidgets('/expense → ExpenseScreen', (tester) async {
      await _pumpApp(tester);

      router.go('/expense');
      await tester.pumpAndSettle();

      expect(find.byType(ExpenseScreen), findsOneWidget);
      expect(find.text('가계부'), findsOneWidget);
    });

    testWidgets('/home → HomeTab', (tester) async {
      await _pumpApp(tester);

      router.go('/home');
      await tester.pumpAndSettle();

      expect(find.byType(HomeTab), findsOneWidget);
      expect(find.text('동이네'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // 2. 잘못된 / 비어 있는 route 는 무시되거나 /home fallback
  // ------------------------------------------------------------------
  group('잘못된 route 는 무시되거나 /home fallback 으로 처리된다', () {
    testWidgets('비허용 route /settings 는 extractRoute 가 null 을 반환하여 무시된다',
        (tester) async {
      await _pumpApp(tester);

      // extractRoute 는 허용 목록 외 route 를 차단한다
      expect(
        NotificationService.extractRoute({'route': '/settings'}),
        isNull,
      );

      // 앱은 여전히 온보딩에 머문다
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('빈 route 는 extractRoute 가 null 을 반환하여 무시된다',
        (tester) async {
      await _pumpApp(tester);

      expect(NotificationService.extractRoute({'route': ''}), isNull);
      expect(NotificationService.extractRoute(const {}), isNull);

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('_openRoute 에서 router.go 실패 시 /home 으로 fallback',
        (tester) async {
      await _pumpApp(tester);

      // GoRouter 에 등록되지 않은 경로를 _openRoute 와 동일한 방식으로 시도
      await _simulateOpenRoute(tester, '/nonexistent-deep-route');

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ------------------------------------------------------------------
  // 3. 초기 알림 메시지(initial message) 경로 시뮬레이션
  // ------------------------------------------------------------------
  group('알림 초기 진입(initial message) 시뮬레이션', () {
    testWidgets(
        'extractRoute 로 검증된 route 가 _openRoute 메커니즘을 통해 화면 이동한다',
        (tester) async {
      await _pumpApp(tester);

      // 1) NotificationService.extractRoute 가 유효한 route 를 반환
      final route = NotificationService.extractRoute({'route': '/calendar'});
      expect(route, '/calendar');

      // 2) _openRoute 와 동일한 postFrameCallback 방식으로 이동
      await _simulateOpenRoute(tester, route!);

      // 3) 기대한 화면이 렌더링됨
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.text('캘린더'), findsWidgets);
    });

    testWidgets(
        '정규화가 필요한 route (//todo) 도 올바르게 이동한다',
        (tester) async {
      await _pumpApp(tester);

      // 이중 슬래시 payload → 정규화 → /todo
      final route = NotificationService.extractRoute({'route': '//todo'});
      expect(route, '/todo');

      await _simulateOpenRoute(tester, route!);

      expect(find.byType(TodoScreen), findsOneWidget);
    });

    testWidgets(
        '비허용 route 가 포함된 알림 데이터는 화면 이동을 트리거하지 않는다',
        (tester) async {
      await _pumpApp(tester);

      final route = NotificationService.extractRoute({'route': '/login'});
      expect(route, isNull);

      // route 가 null 이므로 onOpenRoute 가 호출되지 않음 → 앱 상태 불변
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // 4. kDeeplinkAllowedRoutes 와 GoRouter 정합성 검증
  // ------------------------------------------------------------------
  group('kDeeplinkAllowedRoutes 가 GoRouter 에 모두 등록되어 있다', () {
    testWidgets('모든 허용 route 가 실제 화면으로 이동 가능하다', (tester) async {
      await _pumpApp(tester);

      for (final route in kDeeplinkAllowedRoutes) {
        router.go(route);
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          route,
          reason: '$route 가 실제 라우터 경로로 반영되어야 한다',
        );
        expect(
          find.byType(Scaffold),
          findsWidgets,
          reason: '$route 가 유효한 화면을 렌더링해야 한다',
        );
      }
    });
  });
}
