import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/features/todo/data/todo_repository.dart';
import 'package:dongine/shared/models/todo_model.dart';

import 'fake_todo_repository.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  final t1 = DateTime(2026, 2, 1);
  final t2 = DateTime(2026, 3, 1);
  final due = DateTime(2026, 4, 10, 15);

  group('TodoRepository.sortTodosForDisplay', () {
    test('미완료가 항상 완료보다 앞에 온다', () {
      final sorted = TodoRepository.sortTodosForDisplay([
        TodoModel(
          id: 'done',
          title: '완료',
          createdBy: 'u',
          isCompleted: true,
          completedBy: 'u',
          completedAt: t2,
          createdAt: t2,
        ),
        TodoModel(
          id: 'pend',
          title: '진행',
          createdBy: 'u',
          createdAt: t0,
        ),
      ]);
      expect(sorted.map((e) => e.id), ['pend', 'done']);
    });

    test('같은 완료 여부에서는 createdAt 내림차순이다', () {
      final sorted = TodoRepository.sortTodosForDisplay([
        TodoModel(
          id: 'old',
          title: '옛날',
          createdBy: 'u',
          createdAt: t0,
        ),
        TodoModel(
          id: 'new',
          title: '최근',
          createdBy: 'u',
          createdAt: t2,
        ),
        TodoModel(
          id: 'mid',
          title: '중간',
          createdBy: 'u',
          createdAt: t1,
        ),
      ]);
      expect(sorted.map((e) => e.id), ['new', 'mid', 'old']);
    });
  });

  group('TodoRepository.updatePayloadForTodo', () {
    TodoModel base() {
      return TodoModel(
        id: 'id-1',
        title: '제목',
        description: '본문',
        assignedTo: const ['a', 'b'],
        createdBy: 'owner',
        category: '장보기',
        dueDate: due,
        createdAt: t1,
      );
    }

    test('description·category·dueDate가 보존된다', () {
      final m = base();
      final map = TodoRepository.updatePayloadForTodo(m);
      expect(map['title'], '제목');
      expect(map['assignedTo'], const ['a', 'b']);
      expect(map['description'], '본문');
      expect(map['category'], '장보기');
      expect((map['dueDate'] as Timestamp).toDate(), due);
    });

    test('공백만 있는 description·category는 FieldValue.delete()로 보낸다', () {
      final m = base().copyWith(description: '  ', category: '\t');
      final map = TodoRepository.updatePayloadForTodo(m);
      expect(map['description'], isA<FieldValue>());
      expect(map['category'], isA<FieldValue>());
    });

    test('dueDate가 null이면 FieldValue.delete()로 보낸다', () {
      final m = TodoModel(
        id: 'id-1',
        title: '제목',
        description: '본문',
        assignedTo: const ['a', 'b'],
        createdBy: 'owner',
        category: '장보기',
        createdAt: t1,
      );
      final map = TodoRepository.updatePayloadForTodo(m);
      expect(map['dueDate'], isA<FieldValue>());
    });
  });

  group('TodoRepository.toggleUpdatePayload', () {
    test('완료 시 isCompleted·completedBy·completedAt이 설정된다', () {
      final ts = Timestamp.fromDate(t2);
      final map = TodoRepository.toggleUpdatePayload(
        completed: true,
        userId: 'user-9',
        completedAt: ts,
      );
      expect(map['isCompleted'], isTrue);
      expect(map['completedBy'], 'user-9');
      expect(map['completedAt'], ts);
    });

    test('미완료로 돌리면 completedBy·completedAt이 null이다', () {
      final map = TodoRepository.toggleUpdatePayload(
        completed: false,
        userId: 'user-9',
        completedAt: null,
      );
      expect(map['isCompleted'], isFalse);
      expect(map['completedBy'], isNull);
      expect(map['completedAt'], isNull);
    });
  });

  group('FakeTodoRepository 핵심 흐름', () {
    test('createTodo가 dueDate·category·description을 유지한 채 반영된다', () async {
      final repo = FakeTodoRepository(const []);
      final todo = TodoModel(
        id: 'new-1',
        title: '장보기',
        description: '우유',
        category: '장보기',
        dueDate: due,
        createdBy: 'u1',
        createdAt: t2,
      );
      await repo.createTodo('fam', todo);
      expect(repo.lastCreated?.description, '우유');
      expect(repo.lastCreated?.category, '장보기');
      expect(repo.lastCreated?.dueDate, due);

      final snap = await repo.getTodosStream('fam').first;
      expect(snap.single.description, '우유');
      expect(snap.single.category, '장보기');
      expect(snap.single.dueDate, due);
    });

    test('updateTodo가 필드를 갱신하고 나머지 메타가 스트림에 남는다', () async {
      final orig = TodoModel(
        id: 'e1',
        title: '옛제목',
        description: '옛설명',
        category: '기타',
        dueDate: t0,
        createdBy: 'u',
        createdAt: t2,
      );
      final repo = FakeTodoRepository([orig]);

      final next = orig.copyWith(
        title: '새제목',
        description: '새설명',
        category: '학교',
        dueDate: due,
      );
      await repo.updateTodo('fam', next);

      expect(repo.lastUpdated?.title, '새제목');
      expect(repo.lastUpdated?.description, '새설명');
      expect(repo.lastUpdated?.category, '학교');
      expect(repo.lastUpdated?.dueDate, due);

      final after = await repo.getTodosStream('fam').first;
      final one = after.single;
      expect(one.title, '새제목');
      expect(one.description, '새설명');
      expect(one.category, '학교');
      expect(one.dueDate, due);
      expect(one.createdAt, t2);
    });

    test('toggleTodo가 완료 플래그를 바꾼다', () async {
      final repo = FakeTodoRepository([
        TodoModel(
          id: 't1',
          title: '토글',
          createdBy: 'u',
          createdAt: t1,
        ),
      ]);
      await repo.toggleTodo('fam', 't1', true, 'u');
      expect(repo.lastToggledId, 't1');
      expect(repo.lastToggledCompleted, isTrue);
      expect(repo.lastToggledUserId, 'u');

      final list = await repo.getTodosStream('fam').first;
      expect(list.single.isCompleted, isTrue);
      expect(list.single.completedBy, 'u');

      await repo.toggleTodo('fam', 't1', false, 'u');
      final again = await repo.getTodosStream('fam').first;
      expect(again.single.isCompleted, isFalse);
      expect(again.single.completedBy, isNull);
    });
  });
}
