import 'package:dongine/features/calendar/data/google_calendar_sync_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save 후 load 가 동일한 값을 반환한다', () async {
    final prefs = GoogleCalendarSyncPreferences();
    final at = DateTime(2026, 3, 30, 14, 5);
    await prefs.save(completedAt: at, success: true, message: '1개 추가');

    final loaded = await prefs.load();
    expect(loaded, isNotNull);
    expect(loaded!.success, true);
    expect(loaded.message, '1개 추가');
    expect(loaded.completedAt.millisecondsSinceEpoch, at.millisecondsSinceEpoch);
  });

  test('clear 후 load 는 null', () async {
    final prefs = GoogleCalendarSyncPreferences();
    await prefs.save(
      completedAt: DateTime.now(),
      success: false,
      message: '동기화 실패',
    );
    await prefs.clear();

    expect(await prefs.load(), isNull);
  });

  test('키가 불완전하면 load 는 null', () async {
    SharedPreferences.setMockInitialValues({
      'google_calendar_last_sync_at_ms': 1,
    });
    final prefs = GoogleCalendarSyncPreferences();
    expect(await prefs.load(), isNull);
  });
}
