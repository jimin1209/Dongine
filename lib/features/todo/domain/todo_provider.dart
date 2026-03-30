import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/todo/data/todo_repository.dart';
import 'package:dongine/shared/models/todo_model.dart';

final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository();
});

final todosProvider =
    StreamProvider.family<List<TodoModel>, String>((ref, familyId) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.getTodosStream(familyId);
});
