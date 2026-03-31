import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/cart/data/cart_repository.dart';

void main() {
  group('CartRepository.addOrMergeItem 회귀 (순수 분기)', () {
    test('같은 이름·미체크·같은 카테고리면 합치기 대상', () {
      expect(
        cartItemMatchesMergeTarget(
          {'name': '우유', 'isChecked': false, 'category': '유제품'},
          '우유',
          '유제품',
        ),
        isTrue,
      );
    });

    test('같은 이름 미체크라도 카테고리가 다르면 합치지 않음', () {
      expect(
        cartItemMatchesMergeTarget(
          {'name': '우유', 'isChecked': false, 'category': '유제품'},
          '우유',
          '음료',
        ),
        isFalse,
      );
    });

    test('둘 다 카테고리 null이면 같은 줄로 간주해 합칠 수 있음', () {
      expect(
        cartItemMatchesMergeTarget(
          {'name': '우유', 'isChecked': false},
          '우유',
          null,
        ),
        isTrue,
      );
      expect(
        cartItemMatchesMergeTarget(
          {'name': '우유', 'isChecked': false, 'category': null},
          '우유',
          null,
        ),
        isTrue,
      );
    });

    test('한쪽만 카테고리가 있으면 합치지 않음', () {
      expect(
        cartItemMatchesMergeTarget(
          {'name': '우유', 'isChecked': false, 'category': '유제품'},
          '우유',
          null,
        ),
        isFalse,
      );
      expect(
        cartItemMatchesMergeTarget(
          {'name': '우유', 'isChecked': false},
          '우유',
          '유제품',
        ),
        isFalse,
      );
    });

    test('체크된 동일 이름은 합치기 대상에서 제외', () {
      expect(
        cartItemMatchesMergeTarget(
          {'name': '우유', 'isChecked': true, 'category': '유제품'},
          '우유',
          '유제품',
        ),
        isFalse,
      );
    });

    test('미체크 동일 이름 합칠 때 수량은 기존+추가 (기본 수량 1)', () {
      expect(
        nextMergedQuantity({'quantity': 1}, 1),
        2,
      );
    });

    test('미체크 동일 이름 합칠 때 수량은 기존+추가 (임의 수량)', () {
      expect(nextMergedQuantity({'quantity': 3}, 2), 5);
      expect(nextMergedQuantity({}, 4), 5);
    });
  });

  group('CartRepository.getFrequentItems 회귀 (aggregateTopFrequentNames)', () {
    test('빈 문서면 빈 결과', () {
      expect(aggregateTopFrequentNames([]), isEmpty);
    });

    test('빈 이름 필드는 집계에서 제외', () {
      final rows = [
        {'name': ''},
        {'name': '우유'},
      ];
      expect(aggregateTopFrequentNames(rows), ['우유']);
    });

    test('최근 100건 순서로 넘긴 문서들에서 이름 빈도 내림차순', () {
      final rows = [
        {'name': '빵'},
        {'name': '우유'},
        {'name': '우유'},
        {'name': '달걀'},
        {'name': '우유'},
      ];
      expect(aggregateTopFrequentNames(rows), ['우유', '빵', '달걀']);
    });

    test('상위 10개만 반환', () {
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < 15; i++) {
        rows.add({'name': '항목$i'});
        rows.add({'name': '항목$i'});
      }
      final out = aggregateTopFrequentNames(rows, takeTop: 10);
      expect(out.length, 10);
    });
  });
}
