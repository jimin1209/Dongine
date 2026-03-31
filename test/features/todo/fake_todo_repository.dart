import 'dart:async';

import 'package:dongine/features/todo/data/todo_repository.dart';
import 'package:dongine/shared/models/todo_model.dart';

/// Firestore 없이 목록 스트림을 유지·갱신한다. 정렬은 [TodoRepository.sortTodosForDisplay]와 동일하다.
class FakeTodoRepository extends TodoRepository {
  FakeTodoRepository([List<TodoModel>? seed])
      : _items = List<TodoModel>.from(seed ?? []),
        super.forTest();

  final List<TodoModel> _items;
  final StreamController<List<TodoModel>> _ctrl =
      StreamController<List<TodoModel>>.broadcast();

  void _emit() {
    if (!_ctrl.isClosed) {
      _ctrl.add(TodoRepository.sortTodosForDisplay(_items));
    }
  }

  @override
  Stream<List<TodoModel>> getTodosStream(String familyId) {
    return () async* {
      yield TodoRepository.sortTodosForDisplay(_items);
      yield* _ctrl.stream;
    }();
  }

  TodoModel? lastCreated;
  TodoModel? lastUpdated;
  String? lastToggledId;
  bool? lastToggledCompleted;
  String? lastToggledUserId;

  @override
  Future<void> createTodo(String familyId, TodoModel todo) async {
    lastCreated = todo;
    _items.add(todo);
    _emit();
  }

  @override
  Future<void> updateTodo(String familyId, TodoModel todo) async {
    lastUpdated = todo;
    final i = _items.indexWhere((t) => t.id == todo.id);
    if (i == -1) return;
    _items[i] = todo;
    _emit();
  }

  @override
  Future<void> toggleTodo(
    String familyId,
    String todoId,
    bool completed,
    String userId,
  ) async {
    lastToggledId = todoId;
    lastToggledCompleted = completed;
    lastToggledUserId = userId;
    final i = _items.indexWhere((t) => t.id == todoId);
    if (i == -1) return;
    final t = _items[i];
    _items[i] = TodoModel(
      id: t.id,
      title: t.title,
      description: t.description,
      assignedTo: t.assignedTo,
      createdBy: t.createdBy,
      category: t.category,
      dueDate: t.dueDate,
      reminders: t.reminders,
      isCompleted: completed,
      completedBy: completed ? userId : null,
      completedAt: completed ? DateTime(2026, 3, 31, 12) : null,
      createdAt: t.createdAt,
    );
    _emit();
  }

  @override
  Future<void> deleteTodo(String familyId, String todoId) async {
    _items.removeWhere((t) => t.id == todoId);
    _emit();
  }
}
