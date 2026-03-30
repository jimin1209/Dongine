import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/todo/data/todo_repository.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/features/todo/presentation/todo_screen.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/todo_model.dart';

const _familyId = 'fam-todo-regression';

final _testFamily = FamilyModel(
  id: _familyId,
  name: '할 일 테스트 가족',
  createdBy: 'user-1',
  inviteCode: 'TODO1',
  createdAt: DateTime(2026, 3, 1),
);

final _testMember = FamilyMember(
  uid: 'user-1',
  role: 'admin',
  nickname: '테스트',
  joinedAt: DateTime(2026, 3, 1),
);

/// Firestore 없이 목록 스트림을 유지·갱신한다. [TodoRepository]의 lazy Firestore 필드는 사용하지 않는다.
class FakeTodoRepository extends TodoRepository {
  FakeTodoRepository([List<TodoModel>? seed])
      : _items = List<TodoModel>.from(seed ?? []);

  final List<TodoModel> _items;
  final StreamController<List<TodoModel>> _ctrl =
      StreamController<List<TodoModel>>.broadcast();

  Stream<List<TodoModel>>? _stream;

  List<TodoModel> _sorted() {
    final copy = List<TodoModel>.from(_items);
    copy.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }

  void _emit() {
    if (!_ctrl.isClosed) {
      _ctrl.add(_sorted());
    }
  }

  @override
  Stream<List<TodoModel>> getTodosStream(String familyId) {
    return _stream ??= () async* {
      yield _sorted();
      yield* _ctrl.stream;
    }();
  }

  TodoModel? lastCreated;

  @override
  Future<void> createTodo(String familyId, TodoModel todo) async {
    lastCreated = todo;
    _items.add(todo);
    _emit();
  }

  @override
  Future<void> updateTodo(String familyId, TodoModel todo) async {
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
    final i = _items.indexWhere((t) => t.id == todoId);
    if (i == -1) return;
    final t = _items[i];
    _items[i] = t.copyWith(
      isCompleted: completed,
      completedBy: completed ? userId : null,
      completedAt: completed ? DateTime(2026, 3, 31, 12) : null,
    );
    _emit();
  }

  @override
  Future<void> deleteTodo(String familyId, String todoId) async {
    _items.removeWhere((t) => t.id == todoId);
    _emit();
  }
}

class _FakeAuthUser extends Fake implements User {
  _FakeAuthUser(this._uid);
  final String _uid;

  @override
  String get uid => _uid;
}

List<Override> _todoScreenOverrides(FakeTodoRepository repo) {
  return [
    currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
    authStateProvider.overrideWith(
      (ref) => Stream<User?>.value(_FakeAuthUser('user-1')),
    ),
    todoRepositoryProvider.overrideWithValue(repo),
    familyMembersProvider(_familyId).overrideWith(
      (ref) => Stream<List<FamilyMember>>.value([_testMember]),
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  group('TodoScreen 회귀', () {
    testWidgets('FAB로 바텀시트를 열고 제목 입력 후 추가하면 저장되고 시트가 닫힌다', (tester) async {
      final repo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _todoScreenOverrides(repo),
          child: const MaterialApp(
            locale: Locale('ko', 'KR'),
            home: TodoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('할 일 추가'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        '장보기 우유',
      );
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(find.text('할 일 추가'), findsNothing);
      expect(repo.lastCreated?.title, '장보기 우유');
      expect(find.text('장보기 우유'), findsOneWidget);
    });

    testWidgets('제목 없이 추가는 시트를 닫지 않는다', (tester) async {
      final repo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _todoScreenOverrides(repo),
          child: const MaterialApp(
            locale: Locale('ko', 'KR'),
            home: TodoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(find.text('할 일 추가'), findsOneWidget);
      expect(repo.lastCreated, isNull);
    });

    testWidgets('미완료·완료 섹션이 나뉘어 표시된다', (tester) async {
      final repo = FakeTodoRepository([
        TodoModel(
          id: 't-pending',
          title: '진행 중',
          createdBy: 'user-1',
          createdAt: DateTime(2026, 3, 31, 10),
        ),
        TodoModel(
          id: 't-done',
          title: '끝난 일',
          createdBy: 'user-1',
          isCompleted: true,
          completedBy: 'user-1',
          completedAt: DateTime(2026, 3, 30),
          createdAt: DateTime(2026, 3, 30),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _todoScreenOverrides(repo),
          child: const MaterialApp(
            locale: Locale('ko', 'KR'),
            home: TodoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('미완료 (1)'), findsOneWidget);
      expect(find.text('완료 (1)'), findsOneWidget);
      expect(find.text('진행 중'), findsOneWidget);
      expect(find.text('끝난 일'), findsOneWidget);
    });

    testWidgets('체크박스로 완료 처리하면 완료 섹션으로 옮겨진다', (tester) async {
      final repo = FakeTodoRepository([
        TodoModel(
          id: 't1',
          title: '토글 대상',
          createdBy: 'user-1',
          createdAt: DateTime(2026, 3, 31),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _todoScreenOverrides(repo),
          child: const MaterialApp(
            locale: Locale('ko', 'KR'),
            home: TodoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('미완료 (1)'), findsOneWidget);
      expect(find.text('완료 (1)'), findsNothing);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.text('미완료 (1)'), findsNothing);
      expect(find.text('완료 (1)'), findsOneWidget);
      expect(find.text('토글 대상'), findsOneWidget);
    });

    testWidgets('완료 항목을 체크 해제하면 미완료 섹션으로 돌아간다', (tester) async {
      final repo = FakeTodoRepository([
        TodoModel(
          id: 't-done',
          title: '다시 미완료로',
          createdBy: 'user-1',
          isCompleted: true,
          completedBy: 'user-1',
          completedAt: DateTime(2026, 3, 30),
          createdAt: DateTime(2026, 3, 30),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _todoScreenOverrides(repo),
          child: const MaterialApp(
            locale: Locale('ko', 'KR'),
            home: TodoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('완료 (1)'), findsOneWidget);
      expect(find.text('미완료 (1)'), findsNothing);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.text('미완료 (1)'), findsOneWidget);
      expect(find.text('완료 (1)'), findsNothing);
    });

    testWidgets('편집 아이콘으로 시트가 열리고 기존 제목이 반영되며 저장 시 목록이 갱신된다',
        (tester) async {
      final repo = FakeTodoRepository([
        TodoModel(
          id: 'edit-1',
          title: '원래 제목',
          description: '설명',
          createdBy: 'user-1',
          createdAt: DateTime(2026, 3, 31),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _todoScreenOverrides(repo),
          child: const MaterialApp(
            locale: Locale('ko', 'KR'),
            home: TodoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('편집'));
      await tester.pumpAndSettle();

      expect(find.text('할 일 편집'), findsOneWidget);
      expect(find.widgetWithText(TextField, '원래 제목'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        '바꾼 제목',
      );
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('할 일 편집'), findsNothing);
      expect(find.text('바꾼 제목'), findsOneWidget);
      expect(find.text('원래 제목'), findsNothing);
    });
  });

}
