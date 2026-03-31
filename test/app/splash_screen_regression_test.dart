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
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _s) =>
              const Scaffold(body: Text('__test_onboarding_route__')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _s) =>
              const Scaffold(body: Text('__test_login_route__')),
        ),
        GoRoute(
          path: '/family-setup',
          builder: (_, _s) =>
              const Scaffold(body: Text('__test_family_setup_route__')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _s) =>
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('로그인 전 빈 상태', () {
    testWidgets('인증 로딩 중 → 진행 표시기와 pets 아이콘이 표시된다', (tester) async {
      final controller = StreamController<User?>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildSplash([
          authStateProvider.overrideWith((ref) => controller.stream),
        ]),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsOneWidget);
    });

    testWidgets('사용자 없음 → /onboarding으로 이동한다', (tester) async {
      await tester.pumpWidget(
        _buildSplash([
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(null),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('__test_onboarding_route__'), findsOneWidget);
    });

    testWidgets('인증 오류 → 오류 아이콘과 CTA 버튼이 표시된다', (tester) async {
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
    });

    testWidgets('인증 오류 CTA 탭 → /login으로 이동한다', (tester) async {
      await tester.pumpWidget(
        _buildSplash([
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.error(Exception('auth-fail')),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('__test_login_route__'), findsOneWidget);
    });
  });

  group('가족 없음 빈 상태 (인증 후)', () {
    testWidgets('사용자 있음 + 가족 없음 → /family-setup으로 이동한다', (tester) async {
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
    });

    testWidgets('가족 로딩 중 → 진행 표시기가 표시된다', (tester) async {
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
    });

    testWidgets('가족 정보 오류 → 오류 아이콘과 CTA가 표시된다', (tester) async {
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
    });

    testWidgets('가족 오류 CTA 탭 → /family-setup으로 이동한다', (tester) async {
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

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('__test_family_setup_route__'), findsOneWidget);
    });
  });

  group('가족 있음 → 홈 이동', () {
    testWidgets('사용자 + 가족 있음 → /home으로 이동한다', (tester) async {
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
    });
  });
}
