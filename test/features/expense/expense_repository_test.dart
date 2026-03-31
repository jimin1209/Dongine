import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/features/expense/data/expense_repository.dart';
import 'package:dongine/shared/models/expense_model.dart';

/// Firestore와 동일한 월 경계·정렬 규칙으로 월별 목록을 구현하고,
/// 상위 클래스의 월 합계·카테고리 집계 메서드가 프로덕션 집계 루프를 그대로 탄다.
class _InMemoryExpenseRepository extends ExpenseRepository {
  _InMemoryExpenseRepository() : super.forTest();

  final Map<String, Map<String, ExpenseModel>> _byFamily = {};

  Map<String, ExpenseModel> _docs(String familyId) =>
      _byFamily.putIfAbsent(familyId, () => {});

  int _seq = 0;
  String _allocId() => 'mem_${_seq++}';

  @override
  Future<void> addExpense(String familyId, ExpenseModel expense) async {
    final id = _allocId();
    _docs(familyId)[id] = expense.copyWith(id: id);
  }

  @override
  Future<void> updateExpense(String familyId, ExpenseModel expense) async {
    _docs(familyId)[expense.id] = expense;
  }

  @override
  Future<void> deleteExpense(String familyId, String expenseId) async {
    _docs(familyId).remove(expenseId);
  }

  @override
  Future<List<ExpenseModel>> getMonthlyExpenses(
    String familyId,
    int year,
    int month,
  ) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final filtered = _docs(familyId)
        .values
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
        .toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }
}

ExpenseModel _expense({
  required String id,
  required DateTime date,
  int amount = 1000,
  String category = '식비',
  String title = '항목',
}) {
  final createdAt = DateTime(date.year, date.month, 1);
  return ExpenseModel(
    id: id,
    title: title,
    amount: amount,
    category: category,
    createdBy: 'u1',
    paidBy: 'u1',
    date: date,
    createdAt: createdAt,
  );
}

void main() {
  const familyId = 'fam-repo-test';

  group('ExpenseRepository.forTest', () {
    test('Firestore에 연결되지 않은 인스턴스는 스트림 조회 시 StateError', () {
      final repo = ExpenseRepository.forTest();
      expect(
        () => repo.getExpensesStream(familyId),
        throwsStateError,
      );
    });
  });

  group('_InMemoryExpenseRepository CRUD·월 조회', () {
    late _InMemoryExpenseRepository repo;

    setUp(() {
      repo = _InMemoryExpenseRepository();
    });

    test('addExpense 후 해당 월 getMonthlyExpenses에 포함되고 id가 부여된다', () async {
      final date = DateTime(2026, 3, 15);
      await repo.addExpense(
        familyId,
        _expense(id: '', date: date, title: '커피'),
      );

      final list = await repo.getMonthlyExpenses(familyId, 2026, 3);
      expect(list, hasLength(1));
      expect(list.single.title, '커피');
      expect(list.single.id, startsWith('mem_'));
      expect(list.single.date, date);
    });

    test('updateExpense가 금액·카테고리를 반영한다', () async {
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 3, 10), amount: 1000),
      );
      final added = (await repo.getMonthlyExpenses(familyId, 2026, 3)).single;
      final updated = added.copyWith(
        amount: 5000,
        category: '교통',
        title: '버스',
      );
      await repo.updateExpense(familyId, updated);

      final again = await repo.getMonthlyExpenses(familyId, 2026, 3);
      expect(again.single.amount, 5000);
      expect(again.single.category, '교통');
      expect(again.single.title, '버스');
    });

    test('deleteExpense 후 월 목록에서 제거된다', () async {
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 3, 5)),
      );
      final id = (await repo.getMonthlyExpenses(familyId, 2026, 3)).single.id;
      await repo.deleteExpense(familyId, id);

      expect(await repo.getMonthlyExpenses(familyId, 2026, 3), isEmpty);
    });

    test('월 경계: 이전·다음 달 지출은 해당 월 조회에 포함되지 않는다', () async {
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 2, 28), title: '2월'),
      );
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 3, 1), title: '3월초'),
      );
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 3, 31, 23, 59), title: '3월말'),
      );
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 4, 1), title: '4월'),
      );

      final mar = await repo.getMonthlyExpenses(familyId, 2026, 3);
      expect(mar.map((e) => e.title).toSet(), {'3월초', '3월말'});
    });

    test('getMonthlyExpenses는 date 내림차순이다', () async {
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 5, 1), title: 'a'),
      );
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 5, 20), title: 'b'),
      );
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 5, 10), title: 'c'),
      );

      final list = await repo.getMonthlyExpenses(familyId, 2026, 5);
      expect(list.map((e) => e.title).toList(), ['b', 'c', 'a']);
    });
  });

  group('월 합계·카테고리 집계 (상위 클래스 구현)', () {
    late _InMemoryExpenseRepository repo;

    setUp(() {
      repo = _InMemoryExpenseRepository();
    });

    test('getMonthlyTotal은 해당 월 지출 금액의 합이다', () async {
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 7, 1), amount: 3000),
      );
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 7, 15), amount: 7000),
      );
      await repo.addExpense(
        familyId,
        _expense(id: '', date: DateTime(2026, 8, 1), amount: 99999),
      );

      expect(await repo.getMonthlyTotal(familyId, 2026, 7), 10000);
    });

    test('getCategoryTotals는 카테고리별 금액을 합산한다', () async {
      await repo.addExpense(
        familyId,
        _expense(
          id: '',
          date: DateTime(2026, 9, 2),
          amount: 4000,
          category: '식비',
        ),
      );
      await repo.addExpense(
        familyId,
        _expense(
          id: '',
          date: DateTime(2026, 9, 3),
          amount: 1000,
          category: '식비',
        ),
      );
      await repo.addExpense(
        familyId,
        _expense(
          id: '',
          date: DateTime(2026, 9, 4),
          amount: 2500,
          category: '교통',
        ),
      );

      final totals = await repo.getCategoryTotals(familyId, 2026, 9);
      expect(totals['식비'], 5000);
      expect(totals['교통'], 2500);
      expect(totals.length, 2);
    });

    test('수정·삭제 후 집계가 갱신된다', () async {
      await repo.addExpense(
        familyId,
        _expense(
          id: '',
          date: DateTime(2026, 10, 5),
          amount: 2000,
          category: '생활',
        ),
      );
      await repo.addExpense(
        familyId,
        _expense(
          id: '',
          date: DateTime(2026, 10, 6),
          amount: 3000,
          category: '생활',
        ),
      );

      var row =
          (await repo.getMonthlyExpenses(familyId, 2026, 10)).firstWhere(
        (e) => e.amount == 2000,
      );
      await repo.updateExpense(
        familyId,
        row.copyWith(amount: 500, category: '기타'),
      );

      row = (await repo.getMonthlyExpenses(familyId, 2026, 10)).firstWhere(
        (e) => e.amount == 3000,
      );
      await repo.deleteExpense(familyId, row.id);

      expect(await repo.getMonthlyTotal(familyId, 2026, 10), 500);
      final totals = await repo.getCategoryTotals(familyId, 2026, 10);
      expect(totals, {'기타': 500});
    });
  });
}
