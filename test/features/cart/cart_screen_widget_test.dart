import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/cart/data/cart_repository.dart';
import 'package:dongine/features/cart/domain/cart_provider.dart';
import 'package:dongine/features/cart/presentation/cart_screen.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/cart_item_model.dart';
import 'package:dongine/shared/models/family_model.dart';

const _familyId = 'fam-cart-widget';
const _userId = 'user-cart-widget';

final _testFamily = FamilyModel(
  id: _familyId,
  name: '장보기 위젯 테스트',
  createdBy: _userId,
  inviteCode: 'CARTWT',
  createdAt: DateTime(2026, 3, 31),
);

class _FakeUser extends Fake implements User {
  @override
  String get uid => _userId;
}

CartItemModel _item(
  String name, {
  String id = '',
  int quantity = 1,
  bool isChecked = false,
  String? category,
}) {
  return CartItemModel(
    id: id.isEmpty ? 'id-$name' : id,
    name: name,
    quantity: quantity,
    category: category,
    isChecked: isChecked,
    addedBy: _userId,
    createdAt: DateTime(2026, 3, 31),
  );
}

/// Firestore 없이 장보기 목록 스트림을 유지·갱신하는 fake repository.
class _FakeCartRepository extends CartRepository {
  _FakeCartRepository([List<CartItemModel>? seed])
      : _items = List<CartItemModel>.from(seed ?? []);

  final List<CartItemModel> _items;
  final StreamController<List<CartItemModel>> _ctrl =
      StreamController<List<CartItemModel>>.broadcast();

  Stream<List<CartItemModel>>? _stream;
  List<String> frequentItems = [];
  int addOrMergeCallCount = 0;
  String? lastAddedName;
  int clearCheckedCallCount = 0;

  List<CartItemModel> _sorted() {
    final copy = List<CartItemModel>.from(_items);
    copy.sort((a, b) {
      if (a.isChecked != b.isChecked) return a.isChecked ? 1 : -1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return copy;
  }

  void _emit() {
    if (!_ctrl.isClosed) _ctrl.add(_sorted());
  }

  @override
  Stream<List<CartItemModel>> getCartItemsStream(String familyId) {
    return _stream ??= () async* {
      yield _sorted();
      yield* _ctrl.stream;
    }();
  }

  @override
  Future<void> addOrMergeItem(
    String familyId,
    String name,
    String userId, {
    int quantity = 1,
    String? category,
  }) async {
    addOrMergeCallCount++;
    lastAddedName = name;
    _items.add(_item(name, quantity: quantity, category: category));
    _emit();
  }

  @override
  Future<void> toggleItem(
    String familyId,
    String itemId,
    bool checked,
    String userId,
  ) async {
    final i = _items.indexWhere((it) => it.id == itemId);
    if (i == -1) return;
    _items[i] = _items[i].copyWith(isChecked: checked);
    _emit();
  }

  @override
  Future<void> updateQuantity(
    String familyId,
    String itemId,
    int quantity,
  ) async {
    final i = _items.indexWhere((it) => it.id == itemId);
    if (i == -1) return;
    _items[i] = _items[i].copyWith(quantity: quantity);
    _emit();
  }

  @override
  Future<void> deleteItem(String familyId, String itemId) async {
    _items.removeWhere((it) => it.id == itemId);
    _emit();
  }

  @override
  Future<void> clearCheckedItems(String familyId) async {
    clearCheckedCallCount++;
    _items.removeWhere((it) => it.isChecked);
    _emit();
  }

  @override
  Future<List<String>> getFrequentItems(String familyId) async {
    return frequentItems;
  }

  @override
  Future<void> updateItem(
    String familyId,
    String itemId, {
    String? name,
    int? quantity,
    String? category,
    bool clearCategory = false,
  }) async {
    final i = _items.indexWhere((it) => it.id == itemId);
    if (i == -1) return;
    var item = _items[i];
    if (name != null) item = item.copyWith(name: name);
    if (quantity != null) item = item.copyWith(quantity: quantity);
    if (clearCategory) {
      // copyWith doesn't handle null category, but for test purposes
      // we create a new item without category
      item = CartItemModel(
        id: item.id,
        name: item.name,
        quantity: item.quantity,
        category: null,
        isChecked: item.isChecked,
        addedBy: item.addedBy,
        createdAt: item.createdAt,
      );
    } else if (category != null) {
      item = item.copyWith(category: category);
    }
    _items[i] = item;
    _emit();
  }
}

List<Override> _cartOverrides(_FakeCartRepository repo) {
  return [
    authStateProvider.overrideWith(
      (ref) => Stream<User?>.value(_FakeUser()),
    ),
    currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
    cartRepositoryProvider.overrideWithValue(repo),
    cartItemsProvider(_familyId).overrideWith(
      (ref) => repo.getCartItemsStream(_familyId),
    ),
    frequentItemsProvider(_familyId).overrideWith(
      (ref) async => repo.frequentItems,
    ),
    familyMembersProvider(_familyId).overrideWith(
      (ref) => Stream<List<FamilyMember>>.value(const []),
    ),
  ];
}

Widget _buildApp(_FakeCartRepository repo) {
  return ProviderScope(
    overrides: _cartOverrides(repo),
    child: const MaterialApp(home: CartScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartScreen quick add 흐름', () {
    testWidgets('텍스트 입력 후 추가 버튼을 누르면 항목이 추가된다', (tester) async {
      // FAB와 하단 바 겹침 방지를 위해 화면 크기를 넉넉하게 설정
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository();

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // 빈 상태 확인
      expect(find.text('장보기 목록이 비어있어요'), findsOneWidget);

      // quick add 입력
      await tester.enterText(
        find.byType(TextField).first,
        '우유',
      );
      // IconButton.filled 의 onPressed 직접 호출 (hit-test 안정성 확보)
      final addBtnFinder = find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(IconButton),
      ).first;
      final addBtn = tester.widget<IconButton>(addBtnFinder);
      addBtn.onPressed!();
      await tester.pumpAndSettle();

      expect(repo.addOrMergeCallCount, 1);
      expect(repo.lastAddedName, '우유');
      expect(find.text('우유'), findsOneWidget);
    });

    testWidgets('빈 입력은 추가하지 않는다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository();

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // 빈 상태에서 추가 버튼 탭
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(repo.addOrMergeCallCount, 0);
    });

    testWidgets('엔터(onSubmitted)로도 항목이 추가된다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository();

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '계란');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repo.addOrMergeCallCount, 1);
      expect(repo.lastAddedName, '계란');
    });
  });

  group('CartScreen 추천 항목 표시', () {
    testWidgets('포커스 시 추천 항목 칩이 표시된다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository();
      repo.frequentItems = ['우유', '계란', '빵'];

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // 포커스를 주면 추천이 나타난다
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      expect(find.text('우유'), findsOneWidget);
      expect(find.text('계란'), findsOneWidget);
      expect(find.text('빵'), findsOneWidget);
    });

    testWidgets('이미 목록에 있는 항목은 추천에서 제외된다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository([_item('우유')]);
      repo.frequentItems = ['우유', '계란'];

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      // '우유'는 이미 목록에 있으므로 추천에는 안 나오고 목록에만 나온다
      final actionChips = find.byType(ActionChip);
      // 계란만 추천 칩으로 나와야 한다
      expect(
        find.descendant(of: actionChips, matching: find.text('계란')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: actionChips, matching: find.text('우유')),
        findsNothing,
      );
    });

    testWidgets('체크된(완료) 항목은 추천 필터링에서 제외된다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // '우유'가 체크된 상태 → 추천에서 제거되면 안 됨
      final repo = _FakeCartRepository([_item('우유', isChecked: true)]);
      repo.frequentItems = ['우유', '계란'];

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      // 체크된 항목은 currentItemNames 에 포함되지 않으므로 추천에 남아야 한다
      final actionChips = find.byType(ActionChip);
      expect(
        find.descendant(of: actionChips, matching: find.text('우유')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: actionChips, matching: find.text('계란')),
        findsOneWidget,
      );
    });

    testWidgets('모든 추천이 미체크 목록과 중복이면 추천 영역이 표시되지 않는다',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository([_item('우유'), _item('계란')]);
      repo.frequentItems = ['우유', '계란'];

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      // 추천 칩이 전혀 표시되지 않아야 한다
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('추천 칩 탭 시 항목이 추가된다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository();
      repo.frequentItems = ['두부'];

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // 포커스 -> 추천 표시
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ActionChip, '두부'));
      await tester.pumpAndSettle();

      expect(repo.addOrMergeCallCount, 1);
      expect(repo.lastAddedName, '두부');
    });
  });

  group('CartScreen 카테고리 필터 칩', () {
    testWidgets('전체 및 7개 카테고리 필터 칩이 렌더링된다', (tester) async {
      final repo = _FakeCartRepository([_item('사과', category: '과일')]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // 전체 칩
      expect(find.widgetWithText(FilterChip, '전체'), findsOneWidget);
      // 카테고리 칩들
      for (final cat in CartItemModel.categories) {
        expect(find.widgetWithText(FilterChip, cat), findsOneWidget);
      }
    });

    testWidgets('카테고리 필터 선택 시 해당 카테고리 항목만 표시된다', (tester) async {
      final repo = _FakeCartRepository([
        _item('사과', category: '과일'),
        _item('당근', category: '채소'),
      ]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // 초기에 둘 다 보임
      expect(find.text('사과'), findsOneWidget);
      expect(find.text('당근'), findsOneWidget);

      // '과일' 필터 선택
      await tester.tap(find.widgetWithText(FilterChip, '과일'));
      await tester.pumpAndSettle();

      expect(find.text('사과'), findsOneWidget);
      // 당근은 '채소' 카테고리이므로 안 보임 → 빈 목록 혹은 남은 항목에서 제외
      expect(find.text('당근'), findsNothing);
    });
  });

  group('CartScreen 빈 목록 / 완료 항목 섹션', () {
    testWidgets('항목이 없으면 빈 목록 안내가 표시된다', (tester) async {
      final repo = _FakeCartRepository();

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('장보기 목록이 비어있어요'), findsOneWidget);
    });

    testWidgets('미완료/완료 섹션이 올바르게 나뉜다', (tester) async {
      final repo = _FakeCartRepository([
        _item('우유', id: 'milk'),
        _item('빵', id: 'bread', isChecked: true),
      ]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // 남은 항목 헤더
      expect(find.text('남은 항목: 1개'), findsOneWidget);
      // 완료 섹션 헤더
      expect(find.text('구매 완료 (1)'), findsOneWidget);
      // 각 항목
      expect(find.text('우유'), findsOneWidget);
      expect(find.text('빵'), findsOneWidget);
    });

    testWidgets('완료 항목이 없으면 완료 섹션 헤더가 표시되지 않는다', (tester) async {
      final repo = _FakeCartRepository([_item('우유')]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('남은 항목: 1개'), findsOneWidget);
      expect(find.textContaining('구매 완료'), findsNothing);
    });

    testWidgets('체크박스 토글 시 완료 섹션으로 이동한다', (tester) async {
      final repo = _FakeCartRepository([_item('우유', id: 'milk')]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('남은 항목: 1개'), findsOneWidget);
      expect(find.textContaining('구매 완료'), findsNothing);

      // 체크박스 토글
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // 빈 목록 표시 (필터 기준 unchecked 0개, checked 1개 → filtered 전체 1개이므로 섹션 표시)
      expect(find.text('남은 항목: 0개'), findsOneWidget);
      expect(find.text('구매 완료 (1)'), findsOneWidget);
    });

    testWidgets('구매 완료 항목 삭제 다이얼로그가 동작한다', (tester) async {
      final repo = _FakeCartRepository([
        _item('우유', id: 'milk', isChecked: true),
      ]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // 삭제 아이콘 탭
      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();

      expect(find.text('구매 완료 항목 삭제'), findsOneWidget);
      expect(find.text('체크된 항목을 모두 삭제하시겠어요?'), findsOneWidget);

      // 삭제 확인
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      expect(repo.clearCheckedCallCount, 1);
    });
  });

  group('CartScreen 인라인 수량 변경', () {
    testWidgets('+ 버튼으로 수량이 증가한다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository([_item('우유', id: 'milk', quantity: 2)]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);

      // trailing Row 내부의 + 버튼을 onPressed 직접 호출
      final trailingAdd = find.descendant(
        of: find.byType(ListTile),
        matching: find.widgetWithIcon(IconButton, Icons.add),
      ).first;
      final btn = tester.widget<IconButton>(trailingAdd);
      btn.onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('- 버튼으로 수량이 감소한다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository([_item('우유', id: 'milk', quantity: 3)]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);

      final removeBtn = find.descendant(
        of: find.byType(ListTile),
        matching: find.widgetWithIcon(IconButton, Icons.remove),
      ).first;
      final btn = tester.widget<IconButton>(removeBtn);
      btn.onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('수량 1일 때 - 버튼이 비활성이다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository([_item('우유', id: 'milk', quantity: 1)]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      final removeBtn = find.descendant(
        of: find.byType(ListTile),
        matching: find.widgetWithIcon(IconButton, Icons.remove),
      ).first;
      final btn = tester.widget<IconButton>(removeBtn);

      expect(btn.onPressed, isNull);
    });

    testWidgets('수량 99일 때 + 버튼이 비활성이다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo =
          _FakeCartRepository([_item('우유', id: 'milk', quantity: 99)]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      final addBtn = find.descendant(
        of: find.byType(ListTile),
        matching: find.widgetWithIcon(IconButton, Icons.add),
      ).first;
      final btn = tester.widget<IconButton>(addBtn);

      expect(btn.onPressed, isNull);
    });
  });

  group('CartScreen 항목 편집 흐름', () {
    testWidgets('항목 탭 시 편집 시트가 열리고 기존 값이 채워진다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository([
        _item('우유', id: 'milk', quantity: 2, category: '유제품'),
      ]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // ListTile 탭 → 편집 시트 열기
      await tester.tap(find.text('우유'));
      await tester.pumpAndSettle();

      // 편집 시트 타이틀
      expect(find.text('항목 편집'), findsOneWidget);
      // 이름 필드에 기존 값
      expect(
        find.widgetWithText(TextField, '우유'),
        findsOneWidget,
      );
      // 수량 표시
      expect(find.text('2'), findsWidgets);
      // 저장 버튼
      expect(find.text('저장'), findsOneWidget);
    });

    testWidgets('편집 시트에서 이름을 변경하고 저장할 수 있다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository([
        _item('우유', id: 'milk', quantity: 1),
      ]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // 편집 시트 열기
      await tester.tap(find.text('우유'));
      await tester.pumpAndSettle();

      // 이름 변경
      final nameField = find.widgetWithText(TextField, '우유');
      await tester.enterText(nameField, '두유');

      // 저장
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      // 시트가 닫히고 변경된 이름이 반영
      expect(find.text('항목 편집'), findsNothing);
      expect(find.text('두유'), findsOneWidget);
    });

    testWidgets('편집 시트에서 수량을 변경하고 저장할 수 있다', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeCartRepository([
        _item('우유', id: 'milk', quantity: 1),
      ]);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // 편집 시트 열기
      await tester.tap(find.text('우유'));
      await tester.pumpAndSettle();

      // 수량 + 버튼 (편집 시트 내 add_circle_outline 아이콘)
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      // 저장
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      // 시트 닫힌 후 수량 3이 반영
      expect(find.text('항목 편집'), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
