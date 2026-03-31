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
  final List<String> deletedIds = [];

  @override
  Future<void> addExpense(String familyId, ExpenseModel expense) async {}

  @override
  Future<void> deleteExpense(String familyId, String expenseId) async {
    deletedIds.add(expenseId);
  }

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

  @override
  Future<int> deleteDemoExpenses(String familyId) async => 0;
}

List<Override> _expenseScreenOverrides({required DateTime selectedMonth}) {
  final expenses = _testExpenses(selectedMonth);
  final total = expenses.fold<int>(0, (s, e) => s + e.amount);
  return [
    currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
    expenseRepositoryProvider.overrideWithValue(_FakeExpenseRepository()),
    selectedMonthProvider.overrideWith((ref) => selectedMonth),
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

/// 인사이트/차트 섹션까지 포함한 오버라이드
List<Override> _insightOverrides({
  required DateTime selectedMonth,
  required int currentTotal,
  required int previousTotal,
  required Map<String, int> categoryTotals,
}) {
  final expenses = _testExpenses(selectedMonth);
  return [
    currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
    expenseRepositoryProvider.overrideWithValue(_FakeExpenseRepository()),
    selectedMonthProvider.overrideWith((ref) => selectedMonth),
    monthlyExpensesProvider(_testFamilyId).overrideWith(
      (ref) async => expenses,
    ),
    monthlyCategoryTotalsProvider(_testFamilyId).overrideWith(
      (ref) async => categoryTotals,
    ),
    currentMonthTotalProvider(_testFamilyId).overrideWith(
      (ref) async => currentTotal,
    ),
    previousMonthTotalProvider(_testFamilyId).overrideWith(
      (ref) async => previousTotal,
    ),
  ];
}

Widget _buildScreen(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      locale: Locale('ko'),
      home: ExpenseScreen(),
    ),
  );
}

void main() {
  group('ExpenseScreen – 카테고리 필터', () {
    testWidgets('카테고리 필터 칩으로 목록이 해당 카테고리만 보인다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_expenseScreenOverrides(selectedMonth: month)),
      );
      await tester.pumpAndSettle();

      expect(find.text('점심'), findsOneWidget);
      expect(find.text('버스'), findsOneWidget);

      final transportChip = find.widgetWithText(ChoiceChip, '교통');
      await tester.ensureVisible(transportChip);
      await tester.tap(transportChip);
      await tester.pumpAndSettle();

      expect(find.text('점심'), findsNothing);
      expect(find.text('버스'), findsOneWidget);
    });

    testWidgets('전체 칩을 누르면 필터가 초기화된다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_expenseScreenOverrides(selectedMonth: month)),
      );
      await tester.pumpAndSettle();

      // 교통 필터 적용
      final transportChip = find.widgetWithText(ChoiceChip, '교통');
      await tester.ensureVisible(transportChip);
      await tester.tap(transportChip);
      await tester.pumpAndSettle();
      expect(find.text('점심'), findsNothing);

      // 전체 칩 탭 → 초기화
      final allChip = find.widgetWithText(ChoiceChip, '전체');
      await tester.ensureVisible(allChip);
      await tester.tap(allChip);
      await tester.pumpAndSettle();

      expect(find.text('점심'), findsOneWidget);
      expect(find.text('버스'), findsOneWidget);
    });

    testWidgets('같은 카테고리 칩을 다시 탭하면 필터가 해제된다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_expenseScreenOverrides(selectedMonth: month)),
      );
      await tester.pumpAndSettle();

      final transportChip = find.widgetWithText(ChoiceChip, '교통');
      await tester.ensureVisible(transportChip);
      await tester.tap(transportChip);
      await tester.pumpAndSettle();
      expect(find.text('점심'), findsNothing);

      // 다시 탭 → 해제
      await tester.tap(find.widgetWithText(ChoiceChip, '교통'));
      await tester.pumpAndSettle();

      expect(find.text('점심'), findsOneWidget);
      expect(find.text('버스'), findsOneWidget);
    });
  });

  group('ExpenseScreen – 편집 진입', () {
    testWidgets('지출 항목 탭 시 지출 수정 바텀시트가 열린다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_expenseScreenOverrides(selectedMonth: month)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('버스'));
      await tester.pumpAndSettle();

      expect(find.text('지출 수정'), findsOneWidget);
    });

    testWidgets('수정 바텀시트에 기존 값이 채워져 있다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_expenseScreenOverrides(selectedMonth: month)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('점심'));
      await tester.pumpAndSettle();

      // 기존 제목과 금액이 입력 필드에 채워져 있어야 함
      expect(
        find.widgetWithText(TextField, '점심'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, '10000'),
        findsOneWidget,
      );
    });
  });

  group('ExpenseScreen – 삭제 확인', () {
    testWidgets('스와이프 삭제 시 삭제 확인 다이얼로그가 표시된다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_expenseScreenOverrides(selectedMonth: month)),
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

    testWidgets('삭제 확인 다이얼로그에서 삭제 버튼이 존재하고 탭 가능하다', (tester) async {
      final month = DateTime(2026, 3, 1);
      final fakeRepo = _FakeExpenseRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._expenseScreenOverrides(selectedMonth: month),
            expenseRepositoryProvider.overrideWithValue(fakeRepo),
          ],
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

      // 삭제 버튼(FilledButton)이 존재하는지 확인
      expect(find.widgetWithText(FilledButton, '삭제'), findsOneWidget);
    });
  });

  group('ExpenseScreen – 월 이동', () {
    testWidgets('이전 달 버튼을 누르면 월 표시가 갱신된다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_expenseScreenOverrides(selectedMonth: month)),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026년 3월'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('2026년 2월'), findsOneWidget);
      expect(find.text('2026년 3월'), findsNothing);
    });

    testWidgets('다음 달 버튼을 누르면 월 표시가 갱신된다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_expenseScreenOverrides(selectedMonth: month)),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026년 3월'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('2026년 4월'), findsOneWidget);
      expect(find.text('2026년 3월'), findsNothing);
    });
  });

  group('ExpenseScreen – 인사이트/차트 섹션', () {
    testWidgets('월간 총액이 원화 형식으로 표시된다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_insightOverrides(
          selectedMonth: month,
          currentTotal: 125000,
          previousTotal: 100000,
          categoryTotals: {'식비': 80000, '교통': 45000},
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('125,000원'), findsOneWidget);
    });

    testWidgets('전월 대비 증가 시 증가 레이블이 표시된다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_insightOverrides(
          selectedMonth: month,
          currentTotal: 125000,
          previousTotal: 100000,
          categoryTotals: {'식비': 80000, '교통': 45000},
        )),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('증가'), findsOneWidget);
      expect(find.textContaining('지난달 대비'), findsOneWidget);
    });

    testWidgets('전월 대비 절약 시 절약 레이블이 표시된다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_insightOverrides(
          selectedMonth: month,
          currentTotal: 80000,
          previousTotal: 100000,
          categoryTotals: {'식비': 50000, '교통': 30000},
        )),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('절약'), findsOneWidget);
      expect(find.textContaining('20,000원'), findsOneWidget);
    });

    testWidgets('카테고리 분석 차트에 LinearProgressIndicator가 렌더링된다',
        (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_insightOverrides(
          selectedMonth: month,
          currentTotal: 11500,
          previousTotal: 0,
          categoryTotals: {'식비': 10000, '교통': 1500},
        )),
      );
      await tester.pumpAndSettle();

      // 카테고리 개수만큼 막대가 렌더링됨
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });

    testWidgets('최다 지출 카테고리 요약 카드가 표시된다', (tester) async {
      final month = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _buildScreen(_insightOverrides(
          selectedMonth: month,
          currentTotal: 11500,
          previousTotal: 0,
          categoryTotals: {'식비': 10000, '교통': 1500},
        )),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('이번 달 최다 지출은'), findsOneWidget);
      expect(find.textContaining('식비'), findsWidgets);
    });
  });
}
