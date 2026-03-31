import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/features/todo/presentation/todo_screen.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/todo_model.dart';

import 'fake_todo_repository.dart';

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
