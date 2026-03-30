import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/todo_model.dart';

class TodoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
