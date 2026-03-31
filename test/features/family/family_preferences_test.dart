import 'package:dongine/features/family/data/family_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// setMockInitialValues 키는 FamilyPreferences 의 저장 키와 동일해야 한다.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FamilyPreferences', () {
    test('초기 상태에서는 선택된 가족 ID가 없다', () async {
      final prefs = FamilyPreferences();
      expect(await prefs.getSelectedFamilyId(), isNull);
    });

    test('set 후 get 이 동일한 가족 ID를 반환한다', () async {
      final prefs = FamilyPreferences();
      await prefs.setSelectedFamilyId('family-abc');

      expect(await prefs.getSelectedFamilyId(), 'family-abc');
    });

    test('같은 키에 set 을 반복하면 마지막 값으로 덮어쓴다', () async {
      final prefs = FamilyPreferences();
      await prefs.setSelectedFamilyId('family-first');
      await prefs.setSelectedFamilyId('family-second');

      expect(await prefs.getSelectedFamilyId(), 'family-second');
    });

    test('clearSelectedFamilyId 후 get 은 null 이다', () async {
      final prefs = FamilyPreferences();
      await prefs.setSelectedFamilyId('family-to-clear');
      await prefs.clearSelectedFamilyId();

      expect(await prefs.getSelectedFamilyId(), isNull);
    });

    test('SharedPreferences 에 이미 값이 있으면 get 만으로 조회된다', () async {
      SharedPreferences.setMockInitialValues({
        'selected_family_id': 'preseed-family',
      });
      final prefs = FamilyPreferences();

      expect(await prefs.getSelectedFamilyId(), 'preseed-family');
    });

    test('기존 값 위에 set 하면 새 ID로 덮어쓴다', () async {
      SharedPreferences.setMockInitialValues({
        'selected_family_id': 'old-family',
      });
      final prefs = FamilyPreferences();
      await prefs.setSelectedFamilyId('new-family');

      expect(await prefs.getSelectedFamilyId(), 'new-family');
    });
  });
}
