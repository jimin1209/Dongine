/// Pure calculation helpers for expense insights.
///
/// These are intentionally free functions so they can be unit-tested without
/// any widget, provider, or Firebase dependency.
library;

class MonthComparison {
  final int currentTotal;
  final int previousTotal;
  final int diff;
  final int absDiff;
  final bool isIncrease;

  /// Percentage change relative to previous month.
  /// `null` when previousTotal is 0 (cannot compute ratio).
  final int? percent;

  /// Display label: '증가' | '절약' | null when diff == 0.
  final String? label;

  /// Arrow character: ▲ | ▼ | null when diff == 0.
  final String? arrow;

  MonthComparison._({
    required this.currentTotal,
    required this.previousTotal,
    required this.diff,
    required this.absDiff,
    required this.isIncrease,
    required this.percent,
    required this.label,
    required this.arrow,
  });

  bool get isEmpty => currentTotal == 0 && previousTotal == 0;
  bool get isSame => diff == 0 && !isEmpty;
}

/// Computes month-over-month comparison from two totals.
MonthComparison computeMonthComparison({
  required int currentTotal,
  required int previousTotal,
}) {
  final diff = currentTotal - previousTotal;
  final absDiff = diff.abs();
  final isIncrease = diff > 0;
  final int? percent = (previousTotal > 0)
      ? (absDiff / previousTotal * 100).round()
      : null;

  String? label;
  String? arrow;
  if (diff != 0 || (currentTotal == 0 && previousTotal == 0)) {
    if (diff != 0) {
      label = isIncrease ? '증가' : '절약';
      arrow = isIncrease ? '\u25B2' : '\u25BC';
    }
  }

  return MonthComparison._(
    currentTotal: currentTotal,
    previousTotal: previousTotal,
    diff: diff,
    absDiff: absDiff,
    isIncrease: isIncrease,
    percent: percent,
    label: label,
    arrow: arrow,
  );
}

class CategoryInsight {
  final String name;
  final int amount;
  final int percent;

  const CategoryInsight({
    required this.name,
    required this.amount,
    required this.percent,
  });
}

class CategoryAnalysis {
  final int grandTotal;
  final CategoryInsight topCategory;
  final List<CategoryInsight> sorted;

  const CategoryAnalysis({
    required this.grandTotal,
    required this.topCategory,
    required this.sorted,
  });
}

/// Analyses category totals and returns [CategoryAnalysis], or `null` when
/// there is no data (empty map or zero grand total).
CategoryAnalysis? computeCategoryAnalysis(Map<String, int> categoryTotals) {
  if (categoryTotals.isEmpty) return null;

  int grandTotal = 0;
  for (final v in categoryTotals.values) {
    grandTotal += v;
  }
  if (grandTotal == 0) return null;

  final entries = categoryTotals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final sorted = entries
      .map((e) => CategoryInsight(
            name: e.key,
            amount: e.value,
            percent: (e.value / grandTotal * 100).round(),
          ))
      .toList();

  return CategoryAnalysis(
    grandTotal: grandTotal,
    topCategory: sorted.first,
    sorted: sorted,
  );
}
