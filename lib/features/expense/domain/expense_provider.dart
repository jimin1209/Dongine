import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/expense/data/expense_repository.dart';
import 'package:dongine/shared/models/expense_model.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expensesProvider =
    StreamProvider.family<List<ExpenseModel>, String>((ref, familyId) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpensesStream(familyId);
});

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthlyExpensesProvider =
    FutureProvider.family<List<ExpenseModel>, String>((ref, familyId) {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getMonthlyExpenses(
    familyId,
    selectedMonth.year,
    selectedMonth.month,
  );
});

final expenseCategoryFilterProvider = StateProvider<String?>((ref) => null);

final monthlyCategoryTotalsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, familyId) {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getCategoryTotals(
    familyId,
    selectedMonth.year,
    selectedMonth.month,
  );
});

final currentMonthTotalProvider =
    FutureProvider.family<int, String>((ref, familyId) {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getMonthlyTotal(familyId, selectedMonth.year, selectedMonth.month);
});

final previousMonthTotalProvider =
    FutureProvider.family<int, String>((ref, familyId) {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final prev = DateTime(selectedMonth.year, selectedMonth.month - 1);
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getMonthlyTotal(familyId, prev.year, prev.month);
});
