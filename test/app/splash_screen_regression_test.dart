import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dongine/app/splash_screen.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/family_model.dart';

// ---------------------------------------------------------------------------
// 스플래시 라우팅 매트릭스 (회귀 고정)
//
// | authStateProvider | currentFamilyProvider | 자동 이동 (post-frame) | 오류 CTA →     |
// |-------------------|----------------------|-------------------------|----------------|
// | loading           | (미사용)              | 없음 (스플래시 유지)     | —              |
// | error             | (미사용)              | 없음                    | /login         |
// | data: null        | (미사용)              | /onboarding             | —              |
// | data: User        | loading               | 없음 (스플래시 유지)     | —              |
// | data: User        | error                 | 없음                    | /family-setup  |
// | data: User        | data: null            | /family-setup           | —              |
// | data: User        | data: FamilyModel     | /home                   | —              |
// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test-uid';

  @override
  String? get email => 'test@example.com';

  @override
  String? get displayName => 'Test User';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GoRouter _splashRouter() => GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) =>
              const Scaffold(body: Text('__test_onboarding_route__')),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Text('__test_login_route__')),
        ),
        GoRoute(
          path: '/family-setup',
          builder: (context, state) =>
              const Scaffold(body: Text('__test_family_setup_route__')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Text('__test_home_route__')),
        ),
      ],
    );

Widget _buildSplash(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: _splashRouter()),
  );
}

void _expectNoSplashDestinationRoutes(WidgetTester tester) {
  expect(find.text('__test_onboarding_route__'), findsNothing);
  expect(find.text('__test_login_route__'), findsNothing);
  expect(find.text('__test_family_setup_route__'), findsNothing);
  expect(find.text('__test_home_route__'), findsNothing);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('스플래시 라우팅 매트릭스 (회귀)', () {
    testWidgets('인증 로딩 → 진행·아이콘 표시, 분기 대상 라우트로 이동하지 않는다', (tester) async {
      final controller = StreamController<User?>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildSplash([
          authStateProvider.overrideWith((ref) => controller.stream),
        ]),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsOneWidget);
      _expectNoSplashDestinationRoutes(tester);
    });

    testWidgets('인증 오류 → 오류 UI·CTA 라벨은 로그인, 잘못된 경로로는 이동하지 않는다', (tester) async {
      await tester.pumpWidget(
        _buildSplash([
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.error(Exception('auth-fail')),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('로그인 화면으로'), findsOneWidget);
      expect(find.text('가족 설정으로'), findsNothing);
      _expectNoSplashDestinationRoutes(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('__test_login_route__'), findsOneWidget);
      expect(find.text('__test_onboarding_route__'), findsNothing);
      expect(find.text('__test_family_setup_route__'), findsNothing);
      expect(find.text('__test_home_route__'), findsNothing);
    });

    testWidgets('비로그인 → /onboarding만으로 이동한다', (tester) async {
      await tester.pumpWidget(
        _buildSplash([
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(null),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('__test_onboarding_route__'), findsOneWidget);
      expect(find.text('__test_login_route__'), findsNothing);
      expect(find.text('__test_family_setup_route__'), findsNothing);
      expect(find.text('__test_home_route__'), findsNothing);
    });

    testWidgets('로그인 + 가족 로딩 → 진행 표시, 분기 대상 라우트로 이동하지 않는다', (tester) async {
      await tester.pumpWidget(
        _buildSplash([
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser()),
          ),
          currentFamilyProvider.overrideWithValue(
            const AsyncValue.loading(),
          ),
        ]),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      _expectNoSplashDestinationRoutes(tester);
    });

    testWidgets('로그인 + 가족 오류 → 오류 UI·CTA 라벨은 가족 설정, 잘못된 경로로는 이동하지 않는다', (tester) async {
      await tester.pumpWidget(
        _buildSplash([
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser()),
          ),
          currentFamilyProvider.overrideWithValue(
            AsyncValue.error(Exception('family-fail'), StackTrace.empty),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('가족 설정으로'), findsOneWidget);
      expect(find.text('로그인 화면으로'), findsNothing);
      _expectNoSplashDestinationRoutes(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('__test_family_setup_route__'), findsOneWidget);
      expect(find.text('__test_login_route__'), findsNothing);
      expect(find.text('__test_onboarding_route__'), findsNothing);
      expect(find.text('__test_home_route__'), findsNothing);
    });

    testWidgets('로그인 + 가족 없음 → /family-setup만으로 이동한다', (tester) async {
      await tester.pumpWidget(
        _buildSplash([
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser()),
          ),
          currentFamilyProvider.overrideWithValue(
            const AsyncValue.data(null),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('__test_family_setup_route__'), findsOneWidget);
      expect(find.text('__test_onboarding_route__'), findsNothing);
      expect(find.text('__test_login_route__'), findsNothing);
      expect(find.text('__test_home_route__'), findsNothing);
    });

    testWidgets('로그인 + 가족 있음 → /home만으로 이동한다', (tester) async {
      final family = FamilyModel(
        id: 'fam-1',
        name: '테스트 가족',
        createdBy: 'test-uid',
        inviteCode: 'TST001',
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        _buildSplash([
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser()),
          ),
          currentFamilyProvider.overrideWithValue(
            AsyncValue.data(family),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('__test_home_route__'), findsOneWidget);
      expect(find.text('__test_onboarding_route__'), findsNothing);
      expect(find.text('__test_login_route__'), findsNothing);
      expect(find.text('__test_family_setup_route__'), findsNothing);
    });
  });
}
