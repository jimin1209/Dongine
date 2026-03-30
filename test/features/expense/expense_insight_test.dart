import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/expense/domain/expense_insight.dart';

void main() {
  // -----------------------------------------------------------------------
  // computeMonthComparison
  // -----------------------------------------------------------------------
  group('computeMonthComparison', () {
    test('양쪽 모두 0이면 isEmpty', () {
      final r = computeMonthComparison(currentTotal: 0, previousTotal: 0);
      expect(r.isEmpty, isTrue);
      expect(r.isSame, isFalse);
      expect(r.label, isNull);
      expect(r.arrow, isNull);
    });

    test('동일 금액(>0)이면 isSame', () {
      final r = computeMonthComparison(currentTotal: 50000, previousTotal: 50000);
      expect(r.isEmpty, isFalse);
      expect(r.isSame, isTrue);
      expect(r.diff, 0);
      expect(r.label, isNull);
      expect(r.arrow, isNull);
    });

    test('증가 시 label=증가, arrow=▲, percent 계산', () {
      final r = computeMonthComparison(currentTotal: 150000, previousTotal: 100000);
      expect(r.isIncrease, isTrue);
      expect(r.label, '증가');
      expect(r.arrow, '▲');
      expect(r.absDiff, 50000);
      expect(r.percent, 50);
    });

    test('감소 시 label=절약, arrow=▼, percent 계산', () {
      final r = computeMonthComparison(currentTotal: 70000, previousTotal: 100000);
      expect(r.isIncrease, isFalse);
      expect(r.label, '절약');
      expect(r.arrow, '▼');
      expect(r.absDiff, 30000);
      expect(r.percent, 30);
    });

    test('전월이 0이고 당월 > 0이면 percent null', () {
      final r = computeMonthComparison(currentTotal: 80000, previousTotal: 0);
      expect(r.isIncrease, isTrue);
      expect(r.percent, isNull);
      expect(r.label, '증가');
    });

    test('당월 0이고 전월 > 0이면 절약, percent 100', () {
      final r = computeMonthComparison(currentTotal: 0, previousTotal: 60000);
      expect(r.isIncrease, isFalse);
      expect(r.label, '절약');
      expect(r.percent, 100);
      expect(r.absDiff, 60000);
    });

    test('percent는 반올림', () {
      // 33333 / 100000 = 33.333% → 33
      final r = computeMonthComparison(currentTotal: 133333, previousTotal: 100000);
      expect(r.percent, 33);
    });

    test('큰 증가율 정확도', () {
      final r = computeMonthComparison(currentTotal: 300000, previousTotal: 100000);
      expect(r.percent, 200);
    });
  });

  // -----------------------------------------------------------------------
  // computeCategoryAnalysis
  // -----------------------------------------------------------------------
  group('computeCategoryAnalysis', () {
    test('빈 맵이면 null', () {
      expect(computeCategoryAnalysis({}), isNull);
    });

    test('합계가 0이면 null', () {
      expect(computeCategoryAnalysis({'식비': 0, '교통': 0}), isNull);
    });

    test('단일 카테고리', () {
      final a = computeCategoryAnalysis({'식비': 50000});
      expect(a, isNotNull);
      expect(a!.grandTotal, 50000);
      expect(a.topCategory.name, '식비');
      expect(a.topCategory.percent, 100);
      expect(a.sorted.length, 1);
    });

    test('최대 카테고리를 올바르게 찾는다', () {
      final a = computeCategoryAnalysis({
        '식비': 50000,
        '교통': 30000,
        '여가': 20000,
      });
      expect(a, isNotNull);
      expect(a!.topCategory.name, '식비');
      expect(a.grandTotal, 100000);
    });

    test('sorted는 금액 내림차순', () {
      final a = computeCategoryAnalysis({
        '교통': 10000,
        '식비': 50000,
        '여가': 30000,
      })!;
      expect(a.sorted.map((e) => e.name).toList(), ['식비', '여가', '교통']);
    });

    test('percent 합계가 ≈100', () {
      final a = computeCategoryAnalysis({
        '식비': 50000,
        '교통': 30000,
        '여가': 20000,
      })!;
      final sum = a.sorted.fold<int>(0, (s, e) => s + e.percent);
      expect(sum, closeTo(100, 2));
    });

    test('카테고리 비율 계산 정확도', () {
      final a = computeCategoryAnalysis({
        '식비': 60000,
        '교통': 40000,
      })!;
      expect(a.topCategory.percent, 60);
      expect(a.sorted.last.percent, 40);
    });

    test('동일 금액 카테고리 처리', () {
      final a = computeCategoryAnalysis({
        '식비': 50000,
        '교통': 50000,
      })!;
      expect(a.grandTotal, 100000);
      expect(a.topCategory.percent, 50);
      expect(a.sorted.length, 2);
    });
  });
}
