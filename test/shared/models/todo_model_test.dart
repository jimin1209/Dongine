import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/shared/models/todo_model.dart';

void main() {
  final baseCreated = DateTime(2026, 3, 30, 10);
  final due = DateTime(2026, 4, 5, 18);
  final r1 = DateTime(2026, 4, 4, 9);
  final r2 = DateTime(2026, 4, 5, 9);

  TodoModel makeTodo({
    List<String>? assignedTo,
    DateTime? dueDate,
    bool includeDueDate = true,
    List<DateTime>? reminders,
  }) {
    return TodoModel(
      id: 'todo-1',
      title: '장보기',
      description: '우유',
      assignedTo: assignedTo ?? const ['u1', 'u2'],
      createdBy: 'owner',
      category: '장보기',
      dueDate: includeDueDate ? (dueDate ?? due) : null,
      reminders: reminders ?? [r1, r2],
      isCompleted: false,
      createdAt: baseCreated,
    );
  }

  group('TodoModel toFirestore', () {
    test('assignedTo가 문자열 리스트로 직렬화된다', () {
      final m = makeTodo(assignedTo: const ['a', 'b']);
      final map = m.toFirestore();
      expect(map['assignedTo'], const ['a', 'b']);
    });

    test('dueDate가 있으면 Timestamp로 직렬화되고 null이면 맵에 null이 들어간다', () {
      final withDue = makeTodo(dueDate: due);
      expect(
        (withDue.toFirestore()['dueDate'] as Timestamp).toDate(),
        due,
      );

      final noDue = makeTodo(includeDueDate: false);
      expect(noDue.toFirestore()['dueDate'], isNull);
    });

    test('reminders가 DateTime마다 Timestamp 리스트로 직렬화된다', () {
      final m = makeTodo(reminders: [r1, r2]);
      final list = m.toFirestore()['reminders'] as List<dynamic>;
      expect(list.length, 2);
      expect((list[0] as Timestamp).toDate(), r1);
      expect((list[1] as Timestamp).toDate(), r2);
    });

    test('reminders가 비어 있으면 빈 리스트로 직렬화된다', () {
      final m = makeTodo(reminders: const []);
      expect(m.toFirestore()['reminders'], isEmpty);
    });
  });

  group('TodoModel fromFirestoreMap', () {
    test('assignedTo·dueDate·reminders가 toFirestore 맵에서 복원된다', () {
      final original = makeTodo();
      final map = Map<String, dynamic>.from(original.toFirestore());
      final restored = TodoModel.fromFirestoreMap(original.id, map);

      expect(restored.assignedTo, original.assignedTo);
      expect(restored.dueDate, original.dueDate);
      expect(restored.reminders, original.reminders);
      expect(restored.title, original.title);
      expect(restored.createdAt, original.createdAt);
    });

    test('assignedTo·reminders 키가 없으면 빈 리스트로 복원된다', () {
      final map = <String, dynamic>{
        'title': 't',
        'createdBy': 'c',
        'createdAt': Timestamp.fromDate(baseCreated),
      };
      final m = TodoModel.fromFirestoreMap('id-x', map);
      expect(m.assignedTo, isEmpty);
      expect(m.reminders, isEmpty);
    });
  });

  group('TodoModel copyWith', () {
    test('assignedTo·dueDate·reminders를 각각 덮어쓸 수 있다', () {
      final base = makeTodo();
      final singleReminder = DateTime(2026, 4, 30);
      final next = base.copyWith(
        assignedTo: const ['only-me'],
        dueDate: DateTime(2026, 5, 1),
        reminders: [singleReminder],
      );

      expect(next.assignedTo, const ['only-me']);
      expect(next.dueDate, DateTime(2026, 5, 1));
      expect(next.reminders, [singleReminder]);
      expect(next.title, base.title);
      expect(next.id, base.id);
    });

    test('인자를 생략하면 assignedTo·dueDate·reminders가 유지된다', () {
      final base = makeTodo();
      final same = base.copyWith(title: '다른 제목');

      expect(same.assignedTo, base.assignedTo);
      expect(same.dueDate, base.dueDate);
      expect(same.reminders, base.reminders);
      expect(same.title, '다른 제목');
    });
  });
}
