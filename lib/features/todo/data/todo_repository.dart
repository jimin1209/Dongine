import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/todo_model.dart';

class TodoRepository {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _todosRef(String familyId) {
    return _firestore.collection(FirestorePaths.todos(familyId));
  }

  Stream<List<TodoModel>> getTodosStream(String familyId) {
    return _todosRef(familyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final todos =
          snapshot.docs.map((doc) => TodoModel.fromFirestore(doc)).toList();
      // Sort: uncompleted first, then completed
      todos.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      return todos;
    });
  }

  Future<void> createTodo(String familyId, TodoModel todo) async {
    await _todosRef(familyId).doc(todo.id).set(todo.toFirestore());
  }

  /// Returns `true` if any todo with the `[DEMO]` prefix exists.
  Future<bool> hasDemoTodos(String familyId) async {
    const prefix = '[DEMO]';
    final snap = await _todosRef(familyId)
        .where('title', isGreaterThanOrEqualTo: prefix)
        .where('title', isLessThanOrEqualTo: '$prefix\uf8ff')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// 제목·설명·카테고리·마감·담당자만 갱신한다. 완료 상태 필드는 건드리지 않는다.
  Future<void> updateTodo(String familyId, TodoModel todo) async {
    final data = <String, dynamic>{
      'title': todo.title,
      'assignedTo': todo.assignedTo,
    };
    final desc = todo.description?.trim();
    data['description'] =
        desc == null || desc.isEmpty ? FieldValue.delete() : desc;
    final cat = todo.category?.trim();
    data['category'] =
        cat == null || cat.isEmpty ? FieldValue.delete() : cat;
    data['dueDate'] = todo.dueDate != null
        ? Timestamp.fromDate(todo.dueDate!)
        : FieldValue.delete();
    await _todosRef(familyId).doc(todo.id).update(data);
  }

  Future<void> toggleTodo(
      String familyId, String todoId, bool completed, String userId) async {
    await _todosRef(familyId).doc(todoId).update({
      'isCompleted': completed,
      'completedBy': completed ? userId : null,
      'completedAt': completed ? Timestamp.now() : null,
    });
  }

  Future<void> deleteTodo(String familyId, String todoId) async {
    await _todosRef(familyId).doc(todoId).delete();
  }
}
