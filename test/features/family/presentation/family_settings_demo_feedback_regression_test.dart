import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/cart/domain/cart_provider.dart';
import 'package:dongine/features/expense/domain/expense_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/family/presentation/family_settings_screen.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/todo_model.dart';
import 'package:dongine/shared/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'demo_seed_in_memory_repositories.dart';

/// 데모 시드/초기화 피드백(다이얼로그 문구·요약) 전용 회귀 테스트.
/// [family_settings_screen_test.dart]의 넓은 시나리오와 겹치지 않게 최소 범위만 다룬다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  final baseTime = DateTime(2026, 3, 15, 12, 0, 0);

  FamilyModel family({
    required String id,
    required String name,
    List<String>? memberIds,
    String inviteCode = 'CODE123',
    DateTime? inviteExpiresAt,
  }) {
    return FamilyModel(
      id: id,
      name: name,
      createdBy: 'admin-uid',
      memberIds: memberIds ?? ['demo-uid'],
      inviteCode: inviteCode,
      inviteExpiresAt: inviteExpiresAt ?? baseTime.add(const Duration(days: 30)),
      createdAt: baseTime,
    );
  }

  List<Override> baseOverrides({
    required FamilySessionUser session,
    required List<FamilyModel> families,
    required FamilyModel? current,
    required String? currentFamilyId,
    required List<FamilyMember> members,
  }) {
    final fid = current?.id;
    return [
      familySessionUserProvider.overrideWithValue(session),
      currentUserProfileProvider.overrideWith(
        (ref) => Future<UserModel?>.value(null),
      ),
      userFamiliesProvider.overrideWithValue(AsyncValue.data(families)),
      currentFamilyProvider.overrideWithValue(AsyncValue.data(current)),
      currentFamilyIdProvider.overrideWithValue(AsyncValue.data(currentFamilyId)),
      if (fid != null)
        familyMembersProvider(fid).overrideWith(
          (ref) => Stream<List<FamilyMember>>.value(members),
        ),
    ];
  }

  Widget buildTestApp(List<Override> overrides) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const FamilySettingsScreen(),
        ),
        GoRoute(
          path: '/family-setup',
          builder: (context, state) => const Scaffold(
            body: Text('family-setup-stub'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('데모 피드백 UI 회귀 (debug)', () {
    testWidgets('채우기 성공 시 총 건수·항목별 요약·초기화 안내가 다이얼로그에 보인다',
        (tester) async {
      final fam = family(id: 'fam-reg', name: '회귀 가족');
      final todoRepo = InMemoryDemoTodoRepository();
      final cartRepo = InMemoryDemoCartRepository();
      final expenseRepo = InMemoryDemoExpenseRepository();
      final calendarRepo = InMemoryDemoCalendarRepository();

      await tester.pumpWidget(
        buildTestApp([
          ...baseOverrides(
            session: const FamilySessionUser(
              uid: 'demo-uid',
              email: 'demo@test.com',
            ),
            families: [fam],
            current: fam,
            currentFamilyId: 'fam-reg',
            members: [
              FamilyMember(
                uid: 'demo-uid',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
            ],
          ),
          todoRepositoryProvider.overrideWithValue(todoRepo),
          cartRepositoryProvider.overrideWithValue(cartRepo),
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
          calendarRepositoryProvider.overrideWithValue(calendarRepo),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('데모 데이터 채우기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('데모 데이터 채우기'));
      await tester.pumpAndSettle();

      expect(find.text('데모 데이터를 채웠습니다'), findsOneWidget);
      expect(
        find.textContaining('현재 가족에 아래 샘플이 추가되었습니다. (총 18건)'),
        findsOneWidget,
      );
      expect(find.text('할 일 4건'), findsWidgets);
      expect(find.text('장보기 5건'), findsWidgets);
      expect(find.text('가계부 5건'), findsWidgets);
      expect(find.text('캘린더 일정 4건'), findsWidgets);
      expect(
        find.textContaining('「데모 데이터 초기화」를 사용하세요'),
        findsOneWidget,
      );
      expect(
        find.textContaining('모든 항목 이름은 [DEMO]로 시작합니다'),
        findsOneWidget,
      );
      expect(
        find.textContaining('시연 후 정리할 때는'),
        findsOneWidget,
      );
    });

    testWidgets('이미 데모가 있으면 중복 경고와 초기화 후 재채우기 안내가 다이얼로그에 보인다',
        (tester) async {
      final fam = family(id: 'fam-dup', name: '중복 가족');
      final todoRepo = InMemoryDemoTodoRepository();
      final cartRepo = InMemoryDemoCartRepository();
      final expenseRepo = InMemoryDemoExpenseRepository();
      final calendarRepo = InMemoryDemoCalendarRepository();

      await todoRepo.createTodo(
        fam.id,
        TodoModel(
          id: 'seed-marker',
          title: '[DEMO] 기존 마커',
          createdBy: 'demo-uid',
          createdAt: baseTime,
        ),
      );

      await tester.pumpWidget(
        buildTestApp([
          ...baseOverrides(
            session: const FamilySessionUser(
              uid: 'demo-uid',
              email: 'demo@test.com',
            ),
            families: [fam],
            current: fam,
            currentFamilyId: 'fam-dup',
            members: [
              FamilyMember(
                uid: 'demo-uid',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
            ],
          ),
          todoRepositoryProvider.overrideWithValue(todoRepo),
          cartRepositoryProvider.overrideWithValue(cartRepo),
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
          calendarRepositoryProvider.overrideWithValue(calendarRepo),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('데모 데이터 채우기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final todosBefore = todoRepo.todosInFamily(fam.id).length;
      final cartBefore = cartRepo.namesInFamily(fam.id).length;
      final expensesBefore = expenseRepo.expensesInFamily(fam.id).length;
      final eventsBefore = calendarRepo.eventsInFamily(fam.id).length;

      await tester.tap(find.text('데모 데이터 채우기'));
      await tester.pumpAndSettle();

      expect(find.text('이미 데모 데이터가 있습니다'), findsOneWidget);
      expect(
        find.textContaining('[DEMO]로 시작하는 샘플이 이미 들어 있습니다'),
        findsOneWidget,
      );
      expect(
        find.textContaining('중복으로 쌓이지 않도록'),
        findsOneWidget,
      );
      expect(
        find.textContaining('다시 채우려면 아래 순서로 진행하세요'),
        findsOneWidget,
      );
      expect(
        find.textContaining('「데모 데이터 초기화」를 실행합니다'),
        findsOneWidget,
      );
      expect(
        find.textContaining('「데모 데이터 채우기」를 다시 누릅니다'),
        findsOneWidget,
      );
      expect(
        find.textContaining('직접 만든 데이터는 그대로 둡니다'),
        findsOneWidget,
      );
      expect(
        find.textContaining('할 일·장보기·가계부·일정만'),
        findsOneWidget,
      );

      // 차단: 시드가 다시 돌지 않아 저장소 건수·내용이 그대로인지
      expect(todoRepo.todosInFamily(fam.id), hasLength(todosBefore));
      expect(todoRepo.todosInFamily(fam.id).single.title, '[DEMO] 기존 마커');
      expect(cartRepo.namesInFamily(fam.id), hasLength(cartBefore));
      expect(expenseRepo.expensesInFamily(fam.id), hasLength(expensesBefore));
      expect(calendarRepo.eventsInFamily(fam.id), hasLength(eventsBefore));
    });

    testWidgets('초기화 대상이 없을 때 빈 상태 안내와 채우기 유도 문구가 다이얼로그에 보인다',
        (tester) async {
      final fam = family(id: 'fam-empty', name: '빈 가족');
      final todoRepo = InMemoryDemoTodoRepository();
      final cartRepo = InMemoryDemoCartRepository();
      final expenseRepo = InMemoryDemoExpenseRepository();
      final calendarRepo = InMemoryDemoCalendarRepository();

      await tester.pumpWidget(
        buildTestApp([
          ...baseOverrides(
            session: const FamilySessionUser(
              uid: 'demo-uid',
              email: 'demo@test.com',
            ),
            families: [fam],
            current: fam,
            currentFamilyId: 'fam-empty',
            members: [
              FamilyMember(
                uid: 'demo-uid',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
            ],
          ),
          todoRepositoryProvider.overrideWithValue(todoRepo),
          cartRepositoryProvider.overrideWithValue(cartRepo),
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
          calendarRepositoryProvider.overrideWithValue(calendarRepo),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('데모 데이터 초기화'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('데모 데이터 초기화'));
      await tester.pumpAndSettle();

      expect(find.text('삭제할 데모 데이터가 없습니다'), findsOneWidget);
      expect(
        find.textContaining('「데모 데이터 채우기」를 눌러 추가하세요'),
        findsOneWidget,
      );
    });

    testWidgets(
        '채운 뒤 초기화 성공 시 다음 단계 안내(확인·재채우기 유도)가 다이얼로그에 보인다',
        (tester) async {
      final fam = family(id: 'fam-reset-guide', name: '초기화 안내 가족');
      final todoRepo = InMemoryDemoTodoRepository();
      final cartRepo = InMemoryDemoCartRepository();
      final expenseRepo = InMemoryDemoExpenseRepository();
      final calendarRepo = InMemoryDemoCalendarRepository();

      await tester.pumpWidget(
        buildTestApp([
          ...baseOverrides(
            session: const FamilySessionUser(
              uid: 'demo-uid',
              email: 'demo@test.com',
            ),
            families: [fam],
            current: fam,
            currentFamilyId: 'fam-reset-guide',
            members: [
              FamilyMember(
                uid: 'demo-uid',
                role: 'admin',
                nickname: '관리자',
                joinedAt: baseTime,
              ),
            ],
          ),
          todoRepositoryProvider.overrideWithValue(todoRepo),
          cartRepositoryProvider.overrideWithValue(cartRepo),
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
          calendarRepositoryProvider.overrideWithValue(calendarRepo),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('데모 데이터 채우기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('데모 데이터 채우기'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, '확인'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('데모 데이터 초기화'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('데모 데이터 초기화'));
      await tester.pumpAndSettle();

      expect(find.text('데모 데이터를 초기화했습니다'), findsOneWidget);
      expect(find.textContaining('다음에 할 일'), findsOneWidget);
      expect(
        find.textContaining('홈·할 일·장보기·가계부·캘린더에서 목록이 기대대로 비었는지'),
        findsOneWidget,
      );
      expect(
        find.textContaining('다시 시연용 샘플이 필요하면 「데모 데이터 채우기」를 누르세요'),
        findsOneWidget,
      );
    });
  });
}
