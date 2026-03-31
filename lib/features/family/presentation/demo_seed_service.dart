import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:dongine/features/todo/data/todo_repository.dart';
import 'package:dongine/features/cart/data/cart_repository.dart';
import 'package:dongine/features/expense/data/expense_repository.dart';
import 'package:dongine/features/calendar/data/calendar_repository.dart';
import 'package:dongine/shared/models/todo_model.dart';
import 'package:dongine/shared/models/expense_model.dart';
import 'package:dongine/shared/models/event_model.dart';

/// Summary of what [DemoSeedService.seed] created.
class SeedResult {
  final int todoCount;
  final int cartCount;
  final int expenseCount;
  final int eventCount;

  const SeedResult({
    required this.todoCount,
    required this.cartCount,
    required this.expenseCount,
    required this.eventCount,
  });

  int get total => todoCount + cartCount + expenseCount + eventCount;
}

/// Debug-only service that populates a family with sample data for demos.
///
/// All generated documents share a `[DEMO]` prefix in their title/name so
/// they can be identified (and the duplicate guard can detect prior runs).
class DemoSeedService {
  static const _demoPrefix = '[DEMO]';
  static const _uuid = Uuid();

  final TodoRepository _todoRepo;
  final CartRepository _cartRepo;
  final ExpenseRepository _expenseRepo;
  final CalendarRepository _calendarRepo;

  DemoSeedService({
    required TodoRepository todoRepo,
    required CartRepository cartRepo,
    required ExpenseRepository expenseRepo,
    required CalendarRepository calendarRepo,
  })  : _todoRepo = todoRepo,
        _cartRepo = cartRepo,
        _expenseRepo = expenseRepo,
        _calendarRepo = calendarRepo;

  /// Returns `true` if seed data already exists for [familyId].
  Future<bool> hasSeedData(String familyId) async {
    return _todoRepo.hasDemoTodos(familyId);
  }

  /// Deletes all `[DEMO]`-prefixed data across every collection for [familyId].
  ///
  /// Returns a [SeedResult] summarising the deleted item counts.
  /// Only items whose title/name starts with `[DEMO]` are removed;
  /// user-created data is never touched.
  Future<SeedResult> reset(String familyId) async {
    assert(kDebugMode, 'DemoSeedService must only run in debug mode');

    final results = await Future.wait([
      _todoRepo.deleteDemoTodos(familyId),
      _cartRepo.deleteDemoItems(familyId),
      _expenseRepo.deleteDemoExpenses(familyId),
      _calendarRepo.deleteDemoEvents(familyId),
    ]);

    return SeedResult(
      todoCount: results[0],
      cartCount: results[1],
      expenseCount: results[2],
      eventCount: results[3],
    );
  }

  /// Seeds sample TODO / cart / expense / calendar data for [familyId].
  ///
  /// Returns a [SeedResult] summarising the created items.
  /// Throws in release mode. Callers must gate on [kDebugMode].
  Future<SeedResult> seed(String familyId, String userId) async {
    assert(kDebugMode, 'DemoSeedService must only run in debug mode');

    final now = DateTime.now();

    final results = await Future.wait<int>([
      _seedTodos(familyId, userId, now),
      _seedCart(familyId, userId),
      _seedExpenses(familyId, userId, now),
      _seedEvents(familyId, userId, now),
    ]);

    return SeedResult(
      todoCount: results[0],
      cartCount: results[1],
      expenseCount: results[2],
      eventCount: results[3],
    );
  }

  // ─── Todos ───

  Future<int> _seedTodos(
      String familyId, String userId, DateTime now) async {
    final todos = [
      TodoModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 우유 사오기',
        description: '저지방 1L짜리로',
        assignedTo: [userId],
        createdBy: userId,
        category: '장보기',
        dueDate: now.add(const Duration(days: 1)),
        createdAt: now,
      ),
      TodoModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 거실 청소',
        assignedTo: [userId],
        createdBy: userId,
        category: '집안일',
        dueDate: now.add(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      TodoModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 병원 예약 확인',
        createdBy: userId,
        category: '기타',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      TodoModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 수학 문제집 풀기',
        assignedTo: [userId],
        createdBy: userId,
        category: '학교',
        dueDate: now.add(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ];

    for (final todo in todos) {
      await _todoRepo.createTodo(familyId, todo);
    }
    return todos.length;
  }

  // ─── Cart ───

  Future<int> _seedCart(String familyId, String userId) async {
    final items = [
      ('$_demoPrefix 바나나', 2, '과일'),
      ('$_demoPrefix 두부', 1, '채소'),
      ('$_demoPrefix 삼겹살 600g', 1, '육류'),
      ('$_demoPrefix 우유 1L', 2, '유제품'),
      ('$_demoPrefix 주방세제', 1, '생활용품'),
    ];

    for (final (name, qty, cat) in items) {
      await _cartRepo.addItem(familyId, name, userId,
          quantity: qty, category: cat);
    }
    return items.length;
  }

  // ─── Expenses ───

  Future<int> _seedExpenses(
      String familyId, String userId, DateTime now) async {
    final expenses = [
      ExpenseModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 마트 장보기',
        amount: 45000,
        category: '식비',
        createdBy: userId,
        paidBy: userId,
        date: now,
        createdAt: now,
      ),
      ExpenseModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 지하철 교통카드 충전',
        amount: 20000,
        category: '교통',
        createdBy: userId,
        paidBy: userId,
        date: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      ExpenseModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 세탁소',
        amount: 12000,
        category: '생활',
        createdBy: userId,
        paidBy: userId,
        date: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      ExpenseModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 소아과 진료',
        amount: 8000,
        category: '의료',
        createdBy: userId,
        paidBy: userId,
        date: now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      ExpenseModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 문제집 구매',
        amount: 15000,
        category: '교육',
        createdBy: userId,
        paidBy: userId,
        date: now.subtract(const Duration(days: 4)),
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ];

    for (final expense in expenses) {
      await _expenseRepo.addExpense(familyId, expense);
    }
    return expenses.length;
  }

  // ─── Events ───

  Future<int> _seedEvents(
      String familyId, String userId, DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);

    final events = [
      EventModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 가족 저녁 식사',
        type: 'meal',
        startAt: today.add(const Duration(hours: 18)),
        endAt: today.add(const Duration(hours: 19, minutes: 30)),
        assignedTo: [userId],
        createdBy: userId,
        createdAt: now,
      ),
      EventModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 결혼기념일',
        type: 'anniversary',
        startAt: today.add(const Duration(days: 5)),
        endAt: today.add(const Duration(days: 5, hours: 23, minutes: 59)),
        isAllDay: true,
        dday: true,
        assignedTo: [userId],
        createdBy: userId,
        createdAt: now,
      ),
      EventModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 소아과 방문',
        type: 'hospital',
        startAt: today.add(const Duration(days: 2, hours: 10)),
        endAt: today.add(const Duration(days: 2, hours: 11)),
        assignedTo: [userId],
        createdBy: userId,
        createdAt: now,
      ),
      EventModel(
        id: _uuid.v4(),
        title: '$_demoPrefix 주말 나들이',
        type: 'date',
        startAt: today.add(const Duration(days: 6, hours: 11)),
        endAt: today.add(const Duration(days: 6, hours: 17)),
        budget: 100000,
        assignedTo: [userId],
        createdBy: userId,
        createdAt: now,
      ),
    ];

    for (final event in events) {
      await _calendarRepo.createEvent(familyId, event);
    }
    return events.length;
  }
}
