import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/shared/models/todo_model.dart';

import 'fake_todo_repository.dart';

void main() {
  const familyId = 'fam-provider-test';

  test(
      'todosProvider는 저장소 스트림과 동일하게 미완료 우선·최근 생성 순으로 정렬한다',
      () async {
    final repo = FakeTodoRepository([
      TodoModel(
        id: 'done-old',
        title: '완료 오래됨',
        createdBy: 'u',
        isCompleted: true,
        completedBy: 'u',
        completedAt: DateTime(2026, 2, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
      TodoModel(
        id: 'pend-old',
        title: '진행 오래됨',
        createdBy: 'u',
        createdAt: DateTime(2026, 2, 1),
      ),
      TodoModel(
        id: 'pend-new',
        title: '진행 최근',
        createdBy: 'u',
        createdAt: DateTime(2026, 3, 1),
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        todoRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final list = await container.read(todosProvider(familyId).future);
    expect(list.map((e) => e.id), ['pend-new', 'pend-old', 'done-old']);
  });
}
