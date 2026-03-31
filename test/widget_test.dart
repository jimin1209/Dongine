import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/app/app.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/core/services/notification_service.dart';

/// Firebase 없이 동작하는 Fake NotificationService
class FakeNotificationService extends NotificationService {
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

List<Override> get _testOverrides => [
      authStateProvider.overrideWith(
        (ref) => Stream<User?>.value(null),
      ),
      notificationServiceProvider.overrideWithValue(
        FakeNotificationService(),
      ),
    ];

void main() {
  test('FCM data.route 계약: 주요 딥링크 경로는 extractRoute를 통과한다', () {
    const expectedRoutes = [
      '/chat',
      '/calendar',
      '/todo',
      '/cart',
      '/expense',
    ];
    for (final path in expectedRoutes) {
      expect(NotificationService.extractRoute({'route': path}), path);
    }
  });

  testWidgets('앱은 온보딩 화면으로 시작한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _testOverrides,
        child: const DongineApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('동이네'), findsOneWidget);
    expect(find.text('가족의 일상을 하나로 연결하는 공유 허브'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, '새 계정으로 시작하기'),
      findsOneWidget,
    );
  });

  testWidgets('온보딩 시작하기 버튼은 로그인 화면으로 이동한다',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _testOverrides,
        child: const DongineApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('새 계정으로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('이메일'), findsAtLeastNWidgets(1));
  });
}
