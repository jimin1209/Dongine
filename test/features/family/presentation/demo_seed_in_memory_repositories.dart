import 'package:dongine/features/calendar/data/calendar_repository.dart';
import 'package:dongine/features/cart/data/cart_repository.dart';
import 'package:dongine/features/expense/data/expense_repository.dart';
import 'package:dongine/features/todo/data/todo_repository.dart';
import 'package:dongine/shared/models/event_model.dart';
import 'package:dongine/shared/models/expense_model.dart';
import 'package:dongine/shared/models/todo_model.dart';

/// Firestore와 동일하게 제목·이름이 `[DEMO]`로 시작하는 문서만 삭제하는 인메모리 페이크.
/// 데모 초기화가 일반 데이터를 건드리지 않는 회귀 테스트에 사용한다.
class InMemoryDemoTodoRepository extends TodoRepository {
  InMemoryDemoTodoRepository() : super.forTest();

  final Map<String, List<TodoModel>> _byFamily = {};

  List<TodoModel> todosInFamily(String familyId) =>
      List.unmodifiable(_byFamily[familyId] ?? const []);

  @override
  Future<void> createTodo(String familyId, TodoModel todo) async {
    _byFamily.putIfAbsent(familyId, () => []).add(todo);
  }

  @override
  Future<bool> hasDemoTodos(String familyId) async {
    return (_byFamily[familyId] ?? const [])
        .any((t) => t.title.startsWith('[DEMO]'));
  }

  @override
  Future<int> deleteDemoTodos(String familyId) async {
    final list = _byFamily[familyId];
    if (list == null || list.isEmpty) return 0;
    final removed =
        list.where((t) => t.title.startsWith('[DEMO]')).length;
    list.removeWhere((t) => t.title.startsWith('[DEMO]'));
    return removed;
  }
}

class InMemoryDemoCartRepository extends CartRepository {
  InMemoryDemoCartRepository() : super.forTest();

  final List<
      ({
        String familyId,
        String name,
        String userId,
        int quantity,
        String? category,
      })> _rows = [];

  List<String> namesInFamily(String familyId) => _rows
      .where((r) => r.familyId == familyId)
      .map((r) => r.name)
      .toList(growable: false);

  @override
  Future<void> addItem(
    String familyId,
    String name,
    String userId, {
    int quantity = 1,
    String? category,
  }) async {
    _rows.add((
      familyId: familyId,
      name: name,
      userId: userId,
      quantity: quantity,
      category: category,
    ));
  }

  @override
  Future<int> deleteDemoItems(String familyId) async {
    var n = 0;
    _rows.removeWhere((r) {
      if (r.familyId != familyId) return false;
      if (!r.name.startsWith('[DEMO]')) return false;
      n++;
      return true;
    });
    return n;
  }
}

class InMemoryDemoExpenseRepository extends ExpenseRepository {
  InMemoryDemoExpenseRepository() : super.forTest();

  final Map<String, List<ExpenseModel>> _byFamily = {};

  List<ExpenseModel> expensesInFamily(String familyId) =>
      List.unmodifiable(_byFamily[familyId] ?? const []);

  @override
  Future<void> addExpense(String familyId, ExpenseModel expense) async {
    _byFamily.putIfAbsent(familyId, () => []).add(expense);
  }

  @override
  Future<int> deleteDemoExpenses(String familyId) async {
    final list = _byFamily[familyId];
    if (list == null || list.isEmpty) return 0;
    final removed =
        list.where((e) => e.title.startsWith('[DEMO]')).length;
    list.removeWhere((e) => e.title.startsWith('[DEMO]'));
    return removed;
  }
}

class InMemoryDemoCalendarRepository extends CalendarRepository {
  InMemoryDemoCalendarRepository() : super.forTest();

  final Map<String, List<EventModel>> _byFamily = {};

  List<EventModel> eventsInFamily(String familyId) =>
      List.unmodifiable(_byFamily[familyId] ?? const []);

  @override
  Future<void> createEvent(String familyId, EventModel event) async {
    _byFamily.putIfAbsent(familyId, () => []).add(event);
  }

  @override
  Future<int> deleteDemoEvents(String familyId) async {
    final list = _byFamily[familyId];
    if (list == null || list.isEmpty) return 0;
    final removed =
        list.where((e) => e.title.startsWith('[DEMO]')).length;
    list.removeWhere((e) => e.title.startsWith('[DEMO]'));
    return removed;
  }
}
