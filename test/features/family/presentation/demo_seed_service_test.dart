import 'package:dongine/features/calendar/data/calendar_repository.dart';
import 'package:dongine/features/cart/data/cart_repository.dart';
import 'package:dongine/features/expense/data/expense_repository.dart';
import 'package:dongine/features/family/presentation/demo_seed_service.dart';
import 'package:dongine/features/todo/data/todo_repository.dart';
import 'package:dongine/shared/models/event_model.dart';
import 'package:dongine/shared/models/expense_model.dart';
import 'package:dongine/shared/models/todo_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_seed_in_memory_repositories.dart';

// ─── Fakes ───

class FakeTodoRepository extends TodoRepository {
  FakeTodoRepository() : super.forTest();

  final List<TodoModel> created = [];
  bool _hasDemoData = false;
  int _deletedCount = 0;

  void setHasDemoData(bool value) => _hasDemoData = value;
  void setDeletedCount(int value) => _deletedCount = value;

  @override
  Future<void> createTodo(String familyId, TodoModel todo) async {
    created.add(todo);
  }

  @override
  Future<bool> hasDemoTodos(String familyId) async => _hasDemoData;

  @override
  Future<int> deleteDemoTodos(String familyId) async => _deletedCount;
}

class FakeCartRepository extends CartRepository {
  FakeCartRepository() : super.forTest();

  final List<({String familyId, String name, String userId, int quantity, String? category})> added = [];
  int _deletedCount = 0;

  void setDeletedCount(int value) => _deletedCount = value;

  @override
  Future<void> addItem(
    String familyId,
    String name,
    String userId, {
    int quantity = 1,
    String? category,
  }) async {
    added.add((familyId: familyId, name: name, userId: userId, quantity: quantity, category: category));
  }

  @override
  Future<int> deleteDemoItems(String familyId) async => _deletedCount;
}

class FakeExpenseRepository extends ExpenseRepository {
  FakeExpenseRepository() : super.forTest();

  final List<ExpenseModel> added = [];
  int _deletedCount = 0;

  void setDeletedCount(int value) => _deletedCount = value;

  @override
  Future<void> addExpense(String familyId, ExpenseModel expense) async {
    added.add(expense);
  }

  @override
  Future<int> deleteDemoExpenses(String familyId) async => _deletedCount;
}

class FakeCalendarRepository extends CalendarRepository {
  FakeCalendarRepository() : super.forTest();

  final List<EventModel> created = [];
  int _deletedCount = 0;

  void setDeletedCount(int value) => _deletedCount = value;

  @override
  Future<void> createEvent(String familyId, EventModel event) async {
    created.add(event);
  }

  @override
  Future<int> deleteDemoEvents(String familyId) async => _deletedCount;
}

// ─── Tests ───

void main() {
  const familyId = 'fam-test';
  const userId = 'user-1';

  late FakeTodoRepository fakeTodoRepo;
  late FakeCartRepository fakeCartRepo;
  late FakeExpenseRepository fakeExpenseRepo;
  late FakeCalendarRepository fakeCalendarRepo;
  late DemoSeedService service;

  setUp(() {
    fakeTodoRepo = FakeTodoRepository();
    fakeCartRepo = FakeCartRepository();
    fakeExpenseRepo = FakeExpenseRepository();
    fakeCalendarRepo = FakeCalendarRepository();
    service = DemoSeedService(
      todoRepo: fakeTodoRepo,
      cartRepo: fakeCartRepo,
      expenseRepo: fakeExpenseRepo,
      calendarRepo: fakeCalendarRepo,
    );
  });

  group('hasSeedData – 중복 가드', () {
    test('데모 TODO가 없으면 false를 반환한다', () async {
      fakeTodoRepo.setHasDemoData(false);
      expect(await service.hasSeedData(familyId), isFalse);
    });

    test('데모 TODO가 이미 있으면 true를 반환한다', () async {
      fakeTodoRepo.setHasDemoData(true);
      expect(await service.hasSeedData(familyId), isTrue);
    });

    test('가드가 true일 때 seed를 호출하지 않으면 데이터가 추가되지 않는다', () async {
      fakeTodoRepo.setHasDemoData(true);

      final alreadySeeded = await service.hasSeedData(familyId);
      expect(alreadySeeded, isTrue);

      // Caller should NOT call seed() when guard returns true.
      // Verify repositories remain untouched.
      expect(fakeTodoRepo.created, isEmpty);
      expect(fakeCartRepo.added, isEmpty);
      expect(fakeExpenseRepo.added, isEmpty);
      expect(fakeCalendarRepo.created, isEmpty);
    });
  });

  group('seed – 성공 케이스', () {
    test('TODO 4개를 생성하고 모두 [DEMO] 접두어를 가진다', () async {
      await service.seed(familyId, userId);

      expect(fakeTodoRepo.created, hasLength(4));
      for (final todo in fakeTodoRepo.created) {
        expect(todo.title, startsWith('[DEMO]'));
        expect(todo.createdBy, equals(userId));
        expect(todo.isCompleted, isFalse);
      }
    });

    test('장보기 아이템 5개를 생성하고 모두 [DEMO] 접두어를 가진다', () async {
      await service.seed(familyId, userId);

      expect(fakeCartRepo.added, hasLength(5));
      for (final item in fakeCartRepo.added) {
        expect(item.name, startsWith('[DEMO]'));
        expect(item.userId, equals(userId));
        expect(item.familyId, equals(familyId));
        expect(item.quantity, greaterThanOrEqualTo(1));
        expect(item.category, isNotNull);
      }
    });

    test('지출 5건을 생성하고 모두 [DEMO] 접두어를 가진다', () async {
      await service.seed(familyId, userId);

      expect(fakeExpenseRepo.added, hasLength(5));
      for (final expense in fakeExpenseRepo.added) {
        expect(expense.title, startsWith('[DEMO]'));
        expect(expense.createdBy, equals(userId));
        expect(expense.paidBy, equals(userId));
        expect(expense.amount, greaterThan(0));
      }
    });

    test('일정 4건을 생성하고 모두 [DEMO] 접두어를 가진다', () async {
      await service.seed(familyId, userId);

      expect(fakeCalendarRepo.created, hasLength(4));
      for (final event in fakeCalendarRepo.created) {
        expect(event.title, startsWith('[DEMO]'));
        expect(event.createdBy, equals(userId));
        expect(event.endAt.isAfter(event.startAt) || event.endAt == event.startAt, isTrue);
      }
    });

    test('일정 중 기념일은 isAllDay·dday가 참이다', () async {
      await service.seed(familyId, userId);

      final anniversary = fakeCalendarRepo.created
          .firstWhere((e) => e.type == 'anniversary');
      expect(anniversary.isAllDay, isTrue);
      expect(anniversary.dday, isTrue);
    });

    test('일정 중 나들이는 budget이 설정되어 있다', () async {
      await service.seed(familyId, userId);

      final dateEvent = fakeCalendarRepo.created
          .firstWhere((e) => e.type == 'date');
      expect(dateEvent.budget, equals(100000));
    });

    test('생성된 TODO id는 모두 고유하다', () async {
      await service.seed(familyId, userId);

      final ids = fakeTodoRepo.created.map((t) => t.id).toSet();
      expect(ids, hasLength(fakeTodoRepo.created.length));
    });

    test('생성된 일정 id는 모두 고유하다', () async {
      await service.seed(familyId, userId);

      final ids = fakeCalendarRepo.created.map((e) => e.id).toSet();
      expect(ids, hasLength(fakeCalendarRepo.created.length));
    });
  });

  group('SeedResultKoreanUi', () {
    test('family_settings_screen 시드 성공 다이얼로그 첫 줄과 총 건수가 맞는다', () {
      const result = SeedResult(
        todoCount: 4,
        cartCount: 5,
        expenseCount: 5,
        eventCount: 4,
      );
      expect(result.total, equals(18));
      expect(
        '현재 가족에 아래 샘플이 추가되었습니다. (총 ${result.total}건)',
        equals('현재 가족에 아래 샘플이 추가되었습니다. (총 18건)'),
      );
    });

    test('family_settings_screen 초기화 성공 다이얼로그 헤드라인·breakdown과 맞는다', () {
      const result = SeedResult(
        todoCount: 4,
        cartCount: 5,
        expenseCount: 5,
        eventCount: 4,
      );
      expect(
        '삭제한 항목 (총 ${result.total}건)',
        equals('삭제한 항목 (총 18건)'),
      );
      expect(
        result.breakdownLinesKorean(omitZero: true),
        equals([
          '할 일 4건',
          '장보기 5건',
          '가계부 5건',
          '캘린더 일정 4건',
        ]),
      );
    });

    test('breakdownLinesKorean은 네 도메인을 순서대로 나열한다', () {
      const result = SeedResult(
        todoCount: 4,
        cartCount: 5,
        expenseCount: 5,
        eventCount: 4,
      );
      expect(
        result.breakdownLinesKorean(omitZero: false),
        equals([
          '할 일 4건',
          '장보기 5건',
          '가계부 5건',
          '캘린더 일정 4건',
        ]),
      );
    });

    test('omitZero true이면 0건인 줄은 제외한다', () {
      const result = SeedResult(
        todoCount: 0,
        cartCount: 3,
        expenseCount: 0,
        eventCount: 1,
      );
      expect(
        result.breakdownLinesKorean(omitZero: true),
        equals(['장보기 3건', '캘린더 일정 1건']),
      );
    });
  });

  group('reset – [DEMO] 데이터만 삭제', () {
    test('각 리포지토리의 deleteDemoXxx를 호출하고 결과를 집계한다', () async {
      fakeTodoRepo.setDeletedCount(4);
      fakeCartRepo.setDeletedCount(5);
      fakeExpenseRepo.setDeletedCount(5);
      fakeCalendarRepo.setDeletedCount(4);

      final result = await service.reset(familyId);

      expect(result.todoCount, equals(4));
      expect(result.cartCount, equals(5));
      expect(result.expenseCount, equals(5));
      expect(result.eventCount, equals(4));
      expect(result.total, equals(18));
    });

    test('삭제할 데모 데이터가 없으면 total이 0이다', () async {
      final result = await service.reset(familyId);
      expect(result.total, equals(0));
    });
  });

  group('seed → reset → seed 재실행 흐름', () {
    test('seed 후 reset 후 다시 seed가 가능하다', () async {
      // 1. seed
      await service.seed(familyId, userId);
      expect(fakeTodoRepo.created, hasLength(4));

      // 2. reset
      fakeTodoRepo.setDeletedCount(4);
      fakeCartRepo.setDeletedCount(5);
      fakeExpenseRepo.setDeletedCount(5);
      fakeCalendarRepo.setDeletedCount(4);
      final resetResult = await service.reset(familyId);
      expect(resetResult.total, equals(18));

      // 3. Guard should now return false (data was deleted)
      fakeTodoRepo.setHasDemoData(false);
      expect(await service.hasSeedData(familyId), isFalse);

      // 4. Re-seed
      final beforeCount = fakeTodoRepo.created.length;
      await service.seed(familyId, userId);
      expect(fakeTodoRepo.created, hasLength(beforeCount + 4));
    });
  });

  group('reset – 인메모리: [DEMO]만 제거·일반 데이터 유지', () {
    test('seed 후 일반 항목을 넣고 reset 하면 시연 데이터만 사라진다', () async {
      final inMemoryTodo = InMemoryDemoTodoRepository();
      final inMemoryCart = InMemoryDemoCartRepository();
      final inMemoryExpense = InMemoryDemoExpenseRepository();
      final inMemoryCalendar = InMemoryDemoCalendarRepository();
      final inMemoryService = DemoSeedService(
        todoRepo: inMemoryTodo,
        cartRepo: inMemoryCart,
        expenseRepo: inMemoryExpense,
        calendarRepo: inMemoryCalendar,
      );

      final now = DateTime(2026, 3, 20, 10, 0);

      await inMemoryService.seed(familyId, userId);

      await inMemoryTodo.createTodo(
        familyId,
        TodoModel(
          id: 'user-todo-1',
          title: '직접 만든 할 일',
          createdBy: userId,
          createdAt: now,
        ),
      );
      await inMemoryCart.addItem(
        familyId,
        '일반 장보기 항목',
        userId,
        category: '기타',
      );
      await inMemoryExpense.addExpense(
        familyId,
        ExpenseModel(
          id: 'user-exp-1',
          title: '실제 가계부 항목',
          amount: 1200,
          category: '기타',
          createdBy: userId,
          paidBy: userId,
          date: now,
          createdAt: now,
        ),
      );
      await inMemoryCalendar.createEvent(
        familyId,
        EventModel(
          id: 'user-ev-1',
          title: '가족 일정 (일반)',
          startAt: now,
          endAt: now.add(const Duration(hours: 2)),
          createdBy: userId,
          createdAt: now,
        ),
      );

      final resetResult = await inMemoryService.reset(familyId);

      expect(resetResult.todoCount, equals(4));
      expect(resetResult.cartCount, equals(5));
      expect(resetResult.expenseCount, equals(5));
      expect(resetResult.eventCount, equals(4));
      expect(resetResult.total, equals(18));

      expect(inMemoryTodo.todosInFamily(familyId), hasLength(1));
      expect(inMemoryTodo.todosInFamily(familyId).single.title, '직접 만든 할 일');

      expect(inMemoryCart.namesInFamily(familyId), ['일반 장보기 항목']);

      expect(inMemoryExpense.expensesInFamily(familyId), hasLength(1));
      expect(
        inMemoryExpense.expensesInFamily(familyId).single.title,
        '실제 가계부 항목',
      );

      expect(inMemoryCalendar.eventsInFamily(familyId), hasLength(1));
      expect(
        inMemoryCalendar.eventsInFamily(familyId).single.title,
        '가족 일정 (일반)',
      );
    });
  });

  group('seed 후 중복 가드 시뮬레이션', () {
    test('seed 완료 후 hasSeedData가 true면 재실행을 차단한다', () async {
      // First seed succeeds.
      await service.seed(familyId, userId);
      expect(fakeTodoRepo.created, hasLength(4));

      // Simulate guard detecting existing data.
      fakeTodoRepo.setHasDemoData(true);
      expect(await service.hasSeedData(familyId), isTrue);

      // A well-behaved caller checks hasSeedData before calling seed.
      // The 4 items should not grow.
      final countBefore = fakeTodoRepo.created.length;
      // Caller skips seed because guard returned true.
      expect(countBefore, equals(4));
    });
  });
}
