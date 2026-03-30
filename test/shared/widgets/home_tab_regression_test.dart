import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:dongine/core/services/mqtt_service.dart';
import 'package:dongine/features/calendar/data/google_calendar_sync_preferences.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/features/cart/domain/cart_provider.dart';
import 'package:dongine/features/expense/domain/expense_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/iot/domain/iot_provider.dart';
import 'package:dongine/features/location/domain/location_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/todo_model.dart';
import 'package:dongine/shared/widgets/main_shell.dart';

/// 테스트에서 SharedPreferences를 타지 않도록 하는 스텁.
class _NoopGoogleCalendarSyncPreferences extends GoogleCalendarSyncPreferences {
  @override
  Future<GoogleCalendarSyncPersisted?> load() async => null;

  @override
  Future<void> save({
    required DateTime completedAt,
    required bool success,
    required String message,
  }) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  const familyId = 'home-regression-family';

  final testFamily = FamilyModel(
    id: familyId,
    name: '회귀 테스트 가족',
    createdBy: 'user-1',
    inviteCode: 'HOME1',
    createdAt: DateTime(2026, 3, 1),
  );

  final sampleTodo = TodoModel(
    id: 't1',
    title: '회귀 테스트 할 일',
    createdBy: 'user-1',
    createdAt: DateTime(2026, 3, 31),
  );

  List<Override> homeOverrides({
    List<TodoModel> todos = const [],
  }) {
    return [
      currentFamilyProvider.overrideWithValue(AsyncValue.data(testFamily)),
      todosProvider(familyId).overrideWith((ref) => Stream.value(todos)),
      eventsProvider(familyId).overrideWith((ref) => Stream.value(const [])),
      cartItemsProvider(familyId).overrideWith((ref) => Stream.value(const [])),
      expensesProvider(familyId).overrideWith((ref) => Stream.value(const [])),
      googleCalendarSyncPreferencesProvider
          .overrideWith((ref) => _NoopGoogleCalendarSyncPreferences()),
      locationSharingEnabledProvider.overrideWithValue(false),
      locationPermissionSnapshotProvider.overrideWith((ref) async {
        return const LocationPermissionSnapshot(
          serviceEnabled: true,
          permission: LocationPermission.always,
        );
      }),
      mqttBrokerConfiguredProvider.overrideWithValue(false),
      mqttConnectionStatusProvider.overrideWith((ref) {
        return Stream.value(MqttConnectionStatus.disconnected);
      }),
    ];
  }

  /// 홈 탭과 바로가기·할 일 진입 검증용 최소 라우터.
  GoRouter testHomeRouter() {
    return GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeTab(),
        ),
        GoRoute(
          path: '/todo',
          builder: (context, state) => const Scaffold(
            body: Text('__test_todo_route__'),
          ),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const Scaffold(
            body: Text('__test_cart_route__'),
          ),
        ),
        GoRoute(
          path: '/expense',
          builder: (context, state) => const Scaffold(
            body: Text('__test_expense_route__'),
          ),
        ),
        GoRoute(
          path: '/album',
          builder: (context, state) => const Scaffold(
            body: Text('__test_album_route__'),
          ),
        ),
        GoRoute(
          path: '/iot',
          builder: (context, state) => const Scaffold(
            body: Text('__test_iot_route__'),
          ),
        ),
      ],
    );
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    List<TodoModel> todos = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: homeOverrides(todos: todos),
        child: MaterialApp.router(routerConfig: testHomeRouter()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }

  Finder tappableForText(String text) {
    return find.ancestor(
      of: find.text(text),
      matching: find.byType(InkWell),
    );
  }

  testWidgets('홈 바로가기 카드(장보기/가계부/앨범/IoT/할 일)가 노출된다', (tester) async {
    await pumpHome(tester);

    await scrollToText(tester, '바로가기');

    for (final label in ['장보기', '가계부', '앨범', 'IoT', '할 일']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('바로가기'), findsOneWidget);
  });

  testWidgets('시스템 상태 요약 surface가 본문과 함께 렌더링된다', (tester) async {
    await pumpHome(tester);

    expect(find.text('시스템 상태'), findsOneWidget);
    expect(find.text('위치 공유 꺼짐'), findsOneWidget);
    await scrollToText(tester, '바로가기');
    expect(find.text('바로가기'), findsOneWidget);
    expect(find.text('한눈에 보기'), findsOneWidget);
  });

  testWidgets('전체 보기는 /todo로 이동한다', (tester) async {
    await pumpHome(tester, todos: [sampleTodo]);

    await scrollToText(tester, '전체 보기');
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();

    expect(find.text('__test_todo_route__'), findsOneWidget);
  });

  testWidgets('할 일이 없을 때도 전체 보기로 /todo에 진입한다', (tester) async {
    await pumpHome(tester);

    await scrollToText(tester, '오늘의 할 일');
    expect(find.text('모든 할 일을 완료했어요!'), findsOneWidget);

    await scrollToText(tester, '전체 보기');
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();

    expect(find.text('__test_todo_route__'), findsOneWidget);
  });

  testWidgets('오늘의 할 일 미리보기와 한눈에 보기 할 일 카드가 /todo로 진입한다', (tester) async {
    final router = testHomeRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: homeOverrides(todos: [sampleTodo]),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await scrollToText(tester, '오늘의 할 일');
    expect(find.text('오늘의 할 일'), findsOneWidget);
    expect(find.text('회귀 테스트 할 일'), findsOneWidget);

    final summaryTodoIcon = find.byIcon(Icons.checklist).first;
    await tester.ensureVisible(summaryTodoIcon);
    await tester.tap(summaryTodoIcon, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('__test_todo_route__'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();

    await scrollToText(tester, '바로가기');
    final quickTodoIcon = find.byIcon(Icons.checklist).last;
    await tester.ensureVisible(quickTodoIcon);
    await tester.tap(quickTodoIcon, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('__test_todo_route__'), findsOneWidget);
  });

  testWidgets('장보기 바로가기 카드는 /cart로 이동한다', (tester) async {
    await pumpHome(tester);

    await scrollToText(tester, '장보기');
    await tester.tap(tappableForText('장보기').first);
    await tester.pumpAndSettle();

    expect(find.text('__test_cart_route__'), findsOneWidget);
  });

  testWidgets('가계부·앨범·IoT 바로가기는 각 화면 경로로 이동한다', (tester) async {
    final router = testHomeRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: homeOverrides(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await scrollToText(tester, '가계부');
    await tester.tap(tappableForText('가계부').first);
    await tester.pumpAndSettle();
    expect(find.text('__test_expense_route__'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();

    await scrollToText(tester, '앨범');
    await tester.tap(tappableForText('앨범').first);
    await tester.pumpAndSettle();
    expect(find.text('__test_album_route__'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();

    await scrollToText(tester, 'IoT');
    await tester.tap(tappableForText('IoT').first);
    await tester.pumpAndSettle();
    expect(find.text('__test_iot_route__'), findsOneWidget);
  });
}
