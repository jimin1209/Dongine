import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/expense/data/expense_repository.dart';
import 'package:dongine/features/expense/domain/expense_provider.dart';
import 'package:dongine/features/expense/presentation/expense_screen.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/expense_model.dart';
import 'package:dongine/shared/models/family_model.dart';

const _testFamilyId = 'fam-expense-test';

final _testFamily = FamilyModel(
  id: _testFamilyId,
  name: '테스트 가족',
  createdBy: 'uid-1',
  inviteCode: 'TEST01',
  createdAt: DateTime(2026, 1, 1),
);

List<ExpenseModel> _testExpenses(DateTime month) => [
      ExpenseModel(
        id: 'exp-1',
        title: '점심',
        amount: 10000,
        category: '식비',
        createdBy: 'uid-1',
        paidBy: 'uid-1',
        date: DateTime(month.year, month.month, 15),
        createdAt: DateTime(month.year, month.month, 15),
      ),
      ExpenseModel(
        id: 'exp-2',
        title: '버스',
        amount: 1500,
        category: '교통',
        createdBy: 'uid-1',
        paidBy: 'uid-1',
        date: DateTime(month.year, month.month, 16),
        createdAt: DateTime(month.year, month.month, 16),
      ),
    ];

/// Firebase에 접속하지 않는 저장소 스텁 (위젯 트리가 repo를 읽을 때 안전하게)
class _FakeExpenseRepository implements ExpenseRepository {
  @override
  Future<void> addExpense(String familyId, ExpenseModel expense) async {}

  @override
  Future<void> deleteExpense(String familyId, String expenseId) async {}

  @override
  Stream<List<ExpenseModel>> getExpensesStream(String familyId) =>
      Stream.value(const []);

  @override
  Future<List<ExpenseModel>> getMonthlyExpenses(
    String familyId,
    int year,
    int month,
  ) async =>
      const [];

  @override
  Future<int> getMonthlyTotal(String familyId, int year, int month) async => 0;

  @override
  Future<Map<String, int>> getCategoryTotals(
    String familyId,
    int year,
    int month,
  ) async =>
      {};

  @override
  Future<void> updateExpense(String familyId, ExpenseModel expense) async {}
}

List<Override> _expenseScreenOverrides({required DateTime selectedMonth}) {
  final expenses = _testExpenses(selectedMonth);
  final total = expenses.fold<int>(0, (s, e) => s + e.amount);
  return [
    currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
    expenseRepositoryProvider.overrideWithValue(_FakeExpenseRepository()),
    selectedMonthProvider.overrideWith(
      (ref) => StateController<DateTime>(selectedMonth),
    ),
    monthlyExpensesProvider(_testFamilyId).overrideWith(
      (ref) async => expenses,
    ),
    // 차트/요약 블록을 비워 필터 칩과 목록에만 집중 (카테고리 라벨 중복 방지)
    monthlyCategoryTotalsProvider(_testFamilyId).overrideWith(
      (ref) async => <String, int>{},
    ),
    currentMonthTotalProvider(_testFamilyId).overrideWith(
      (ref) async => total,
    ),
    previousMonthTotalProvider(_testFamilyId).overrideWith(
      (ref) async => 0,
    ),
  ];
}

void main() {
  group('ExpenseScreen', () {
    testWidgets('카테고리 필터 칩으로 목록이 해당 카테고리만 보인다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _expenseScreenOverrides(selectedMonth: month),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ExpenseScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('점심'), findsOneWidget);
      expect(find.text('버스'), findsOneWidget);

      final transportChip = find.text('교통');
      await tester.ensureVisible(transportChip);
      await tester.tap(transportChip);
      await tester.pumpAndSettle();

      expect(find.text('점심'), findsNothing);
      expect(find.text('버스'), findsOneWidget);
    });

    testWidgets('지출 항목 탭 시 지출 수정 바텀시트가 열린다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _expenseScreenOverrides(selectedMonth: month),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ExpenseScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('버스'));
      await tester.pumpAndSettle();

      expect(find.text('지출 수정'), findsOneWidget);
    });

    testWidgets('스와이프 삭제 시 삭제 확인 다이얼로그가 표시된다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _expenseScreenOverrides(selectedMonth: month),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ExpenseScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dismissible = find.byKey(const ValueKey('exp-1'));
      await tester.ensureVisible(dismissible);
      await tester.drag(dismissible, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('지출 삭제'), findsOneWidget);
      expect(find.text('이 지출 항목을 삭제하시겠습니까?'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.text('지출 삭제'), findsNothing);
    });
  });
}
