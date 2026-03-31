import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/expense_model.dart';

class ExpenseRepository {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _expenseCollection(String familyId) {
    return _firestore.collection(FirestorePaths.expenses(familyId));
  }

  Stream<List<ExpenseModel>> getExpensesStream(String familyId) {
    return _expenseCollection(familyId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromFirestore(doc))
            .toList());
  }

  Future<List<ExpenseModel>> getMonthlyExpenses(
    String familyId,
    int year,
    int month,
  ) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    final snapshot = await _expenseCollection(familyId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ExpenseModel.fromFirestore(doc))
        .toList();
  }

  Future<void> addExpense(String familyId, ExpenseModel expense) async {
    await _expenseCollection(familyId).add(expense.toFirestore());
  }

  Future<void> updateExpense(String familyId, ExpenseModel expense) async {
    await _expenseCollection(familyId)
        .doc(expense.id)
        .update(expense.toFirestore());
  }

  Future<void> deleteExpense(String familyId, String expenseId) async {
    await _expenseCollection(familyId).doc(expenseId).delete();
  }

  Future<int> getMonthlyTotal(
    String familyId,
    int year,
    int month,
  ) async {
    final expenses = await getMonthlyExpenses(familyId, year, month);
    int total = 0;
    for (final e in expenses) {
      total += e.amount;
    }
    return total;
  }

  Future<Map<String, int>> getCategoryTotals(
    String familyId,
    int year,
    int month,
  ) async {
    final expenses = await getMonthlyExpenses(familyId, year, month);
    final totals = <String, int>{};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    return totals;
  }
}
