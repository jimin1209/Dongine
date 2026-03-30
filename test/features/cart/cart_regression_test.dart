import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/cart/domain/cart_helpers.dart';
import 'package:dongine/shared/models/cart_item_model.dart';

// ---------------------------------------------------------------------------
// Helper to build a CartItemModel quickly
// ---------------------------------------------------------------------------
CartItemModel _item(
  String name, {
  String id = '',
  int quantity = 1,
  bool isChecked = false,
  String? category,
}) {
  return CartItemModel(
    id: id.isEmpty ? name : id,
    name: name,
    quantity: quantity,
    isChecked: isChecked,
    addedBy: 'u1',
    createdAt: DateTime(2026, 1, 1),
    category: category,
  );
}

void main() {
  // =========================================================================
  // 1. 같은 이름 미체크 항목 수량 합치기 (addOrMerge 핵심 로직)
  // =========================================================================
  group('수량 합치기 (addOrMerge)', () {
    test('미체크 목록에 같은 이름이 있으면 중복으로 판정', () {
      final items = [_item('우유'), _item('달걀')];
      expect(hasUncheckedDuplicate(items, '우유'), isTrue);
    });

    test('체크된 항목은 중복 판정 대상에서 제외', () {
      final items = [_item('우유', isChecked: true)];
      expect(hasUncheckedDuplicate(items, '우유'), isFalse);
    });

    test('목록이 비어 있으면 중복 아님', () {
      expect(hasUncheckedDuplicate([], '우유'), isFalse);
    });

    test('이름이 다르면 중복 아님', () {
      final items = [_item('두유')];
      expect(hasUncheckedDuplicate(items, '우유'), isFalse);
    });

    test('기본 수량 1+1 합치기', () {
      expect(computeMergedQuantity(1, 1), 2);
    });

    test('기존 수량 3에 2를 더하면 5', () {
      expect(computeMergedQuantity(3, 2), 5);
    });

    test('기존 수량 0에 1을 더하면 1', () {
      expect(computeMergedQuantity(0, 1), 1);
    });

    test('같은 이름의 미체크 항목이 여러 개 있어도 하나만 매칭되면 true', () {
      final items = [_item('우유'), _item('우유')];
      expect(hasUncheckedDuplicate(items, '우유'), isTrue);
    });

    test('미체크 + 체크 동일 이름 혼재 시 미체크만 감지', () {
      final items = [
        _item('우유', isChecked: true),
        _item('우유', isChecked: false),
      ];
      expect(hasUncheckedDuplicate(items, '우유'), isTrue);
    });

    test('모든 동일 이름이 체크되어 있으면 중복 아님', () {
      final items = [
        _item('우유', isChecked: true),
        _item('우유', isChecked: true),
      ];
      expect(hasUncheckedDuplicate(items, '우유'), isFalse);
    });
  });

  // =========================================================================
  // 2. 추천 항목 필터링 (중복 제거)
  // =========================================================================
  group('추천 항목 필터링', () {
    test('미체크 목록과 겹치는 추천은 제거', () {
      final suggestions = ['우유', '달걀', '빵'];
      final unchecked = {'우유', '달걀'};
      expect(filterSuggestions(suggestions, unchecked), ['빵']);
    });

    test('겹치는 항목이 없으면 전부 반환', () {
      final suggestions = ['우유', '달걀'];
      expect(filterSuggestions(suggestions, {}), ['우유', '달걀']);
    });

    test('모든 추천이 미체크에 포함되면 빈 리스트', () {
      final suggestions = ['우유', '달걀'];
      final unchecked = {'우유', '달걀', '빵'};
      expect(filterSuggestions(suggestions, unchecked), isEmpty);
    });

    test('빈 추천 목록이면 빈 리스트', () {
      expect(filterSuggestions([], {'우유'}), isEmpty);
    });

    test('미체크 목록이 비어있고 추천이 있으면 전부 반환', () {
      expect(filterSuggestions(['우유'], {}), ['우유']);
    });

    test('순서가 보존된다', () {
      final suggestions = ['빵', '달걀', '우유', '치즈'];
      final unchecked = {'달걀'};
      expect(filterSuggestions(suggestions, unchecked), ['빵', '우유', '치즈']);
    });
  });

  // =========================================================================
  // 3. 항목 편집 업데이트 필드 계산
  // =========================================================================
  group('항목 편집 (computeItemUpdateFields)', () {
    test('아무것도 변경하지 않으면 빈 맵', () {
      final fields = computeItemUpdateFields(
        newName: '우유',
        oldName: '우유',
        newQuantity: 2,
        oldQuantity: 2,
        newCategory: '유제품',
        oldCategory: '유제품',
      );
      expect(fields, isEmpty);
    });

    test('이름만 변경', () {
      final fields = computeItemUpdateFields(
        newName: '두유',
        oldName: '우유',
        newQuantity: 1,
        oldQuantity: 1,
        newCategory: null,
        oldCategory: null,
      );
      expect(fields, {'name': '두유'});
    });

    test('수량만 변경', () {
      final fields = computeItemUpdateFields(
        newName: '우유',
        oldName: '우유',
        newQuantity: 3,
        oldQuantity: 1,
        newCategory: null,
        oldCategory: null,
      );
      expect(fields, {'quantity': 3});
    });

    test('카테고리 변경', () {
      final fields = computeItemUpdateFields(
        newName: '우유',
        oldName: '우유',
        newQuantity: 1,
        oldQuantity: 1,
        newCategory: '음료',
        oldCategory: '유제품',
      );
      expect(fields, {'category': '음료'});
    });

    test('카테고리 제거 (null로 변경)', () {
      final fields = computeItemUpdateFields(
        newName: '우유',
        oldName: '우유',
        newQuantity: 1,
        oldQuantity: 1,
        newCategory: null,
        oldCategory: '유제품',
      );
      expect(fields, {'category': null});
    });

    test('수량이 0 이하면 업데이트에 포함하지 않음', () {
      final fields = computeItemUpdateFields(
        newName: '우유',
        oldName: '우유',
        newQuantity: 0,
        oldQuantity: 1,
        newCategory: null,
        oldCategory: null,
      );
      expect(fields, isEmpty);
    });

    test('전체 필드 동시 변경', () {
      final fields = computeItemUpdateFields(
        newName: '두유',
        oldName: '우유',
        newQuantity: 5,
        oldQuantity: 1,
        newCategory: '음료',
        oldCategory: '유제품',
      );
      expect(fields, {'name': '두유', 'quantity': 5, 'category': '음료'});
    });
  });

  // =========================================================================
  // 4. 삭제 확인 흐름 - 수량 경계값 (clampQuantity)
  // =========================================================================
  group('수량 경계값 (clampQuantity)', () {
    test('1 미만은 1로 클램프', () {
      expect(clampQuantity(0), 1);
      expect(clampQuantity(-5), 1);
    });

    test('99 초과는 99로 클램프', () {
      expect(clampQuantity(100), 99);
      expect(clampQuantity(999), 99);
    });

    test('범위 내 값은 그대로', () {
      expect(clampQuantity(1), 1);
      expect(clampQuantity(50), 50);
      expect(clampQuantity(99), 99);
    });
  });

  // =========================================================================
  // 5. 자주 구매 항목 계산 (computeFrequentItems)
  // =========================================================================
  group('자주 구매 항목 계산', () {
    test('빈 리스트면 빈 결과', () {
      expect(computeFrequentItems([]), isEmpty);
    });

    test('빈 문자열은 무시', () {
      expect(computeFrequentItems(['', '', '우유']), ['우유']);
    });

    test('빈도 내림차순 정렬', () {
      final names = ['우유', '달걀', '우유', '빵', '달걀', '우유'];
      expect(computeFrequentItems(names), ['우유', '달걀', '빵']);
    });

    test('limit 적용', () {
      final names = List.generate(20, (i) => '항목$i');
      final result = computeFrequentItems(names, limit: 5);
      expect(result.length, 5);
    });

    test('항목 수가 limit보다 적으면 전체 반환', () {
      expect(computeFrequentItems(['우유', '달걀']), ['우유', '달걀']);
    });

    test('동일 빈도 항목도 모두 포함', () {
      final names = ['우유', '달걀', '빵'];
      final result = computeFrequentItems(names);
      expect(result.length, 3);
      expect(result, containsAll(['우유', '달걀', '빵']));
    });
  });

  // =========================================================================
  // 6. CartItemModel 기본 동작 회귀
  // =========================================================================
  group('CartItemModel 회귀', () {
    test('copyWith로 이름 변경 시 나머지 필드 유지', () {
      final item = _item('우유', quantity: 3, category: '유제품');
      final edited = item.copyWith(name: '두유');
      expect(edited.name, '두유');
      expect(edited.quantity, 3);
      expect(edited.category, '유제품');
      expect(edited.isChecked, false);
    });

    test('copyWith로 체크 토글', () {
      final item = _item('우유');
      final checked = item.copyWith(isChecked: true, checkedBy: 'u2');
      expect(checked.isChecked, true);
      expect(checked.checkedBy, 'u2');
      expect(checked.name, '우유');
    });

    test('toFirestore 왕복 일관성', () {
      final item = _item('우유', quantity: 2, category: '유제품');
      final map = item.toFirestore();
      expect(map['name'], '우유');
      expect(map['quantity'], 2);
      expect(map['category'], '유제품');
      expect(map['isChecked'], false);
    });

    test('categories 상수에 7개 카테고리 포함', () {
      expect(CartItemModel.categories.length, 7);
      expect(CartItemModel.categories, contains('과일'));
      expect(CartItemModel.categories, contains('기타'));
    });
  });
}
