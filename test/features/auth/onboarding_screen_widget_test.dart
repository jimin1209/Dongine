import 'package:dongine/features/auth/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// /login 으로 이동했는지 확인하기 위한 간이 라우터
GoRouter _testRouter() => GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('LOGIN_SCREEN')),
          ),
        ),
      ],
    );

Widget _buildTestApp() {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: _testRouter(),
    ),
  );
}

void main() {
  // ─── 핵심 소개 UI 렌더링 ─────────────────────────────────────────
  group('핵심 소개 텍스트 및 아이콘 렌더링', () {
    testWidgets('앱 이름, 부제, pets 아이콘이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('동이네'), findsOneWidget);
      expect(find.text('우리 가족만의 공유 허브'), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsOneWidget);
    });

    testWidgets('시작하기 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, '시작하기'), findsOneWidget);
    });
  });

  // ─── 주요 기능 카드 렌더링 ───────────────────────────────────────
  group('주요 기능 카드 렌더링', () {
    testWidgets('4개 기능 제목이 모두 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('가족 채팅'), findsOneWidget);
      expect(find.text('공유 캘린더'), findsOneWidget);
      expect(find.text('장보기 목록'), findsOneWidget);
      expect(find.text('가족 앨범'), findsOneWidget);
    });

    testWidgets('4개 기능 설명이 모두 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('우리 가족만의 대화 공간'), findsOneWidget);
      expect(find.text('일정을 한눈에 확인하고 관리'), findsOneWidget);
      expect(find.text('함께 만드는 장보기 리스트'), findsOneWidget);
      expect(find.text('소중한 순간을 함께 기록'), findsOneWidget);
    });

    testWidgets('각 기능 아이콘이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    });
  });

  // ─── 시작하기 버튼 → /login 이동 ────────────────────────────────
  group('시작하기 버튼 탭 → /login 이동', () {
    testWidgets('시작하기 버튼 탭 시 로그인 화면으로 이동한다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      // 테스트 라우터의 /login 화면에 배치된 마커 텍스트 확인
      expect(find.text('LOGIN_SCREEN'), findsOneWidget);
      // 온보딩 소개 텍스트가 사라졌는지 확인
      expect(find.text('우리 가족만의 공유 허브'), findsNothing);
    });
  });
}
