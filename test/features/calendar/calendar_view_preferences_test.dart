import 'package:dongine/features/calendar/data/calendar_view_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('기본 load 값은 탭 0, 월간, focusedDay null, 전체 카테고리', () async {
    final prefs = CalendarViewPreferences();
    final result = await prefs.load();

    expect(result.tabIndex, 0);
    expect(result.calendarFormat, CalendarFormat.month);
    expect(result.focusedDay, isNull);
    expect(result.todoCategory, '전체');
  });

  test('saveTabIndex 후 load 가 동일한 값을 반환한다', () async {
    final prefs = CalendarViewPreferences();
    await prefs.saveTabIndex(2);

    final result = await prefs.load();
    expect(result.tabIndex, 2);
  });

  test('saveCalendarFormat 후 load 가 동일한 포맷을 반환한다', () async {
    final prefs = CalendarViewPreferences();
    await prefs.saveCalendarFormat(CalendarFormat.week);

    final result = await prefs.load();
    expect(result.calendarFormat, CalendarFormat.week);
  });

  test('saveFocusedDay 후 load 가 동일한 날짜를 반환한다', () async {
    final prefs = CalendarViewPreferences();
    final day = DateTime(2026, 3, 15);
    await prefs.saveFocusedDay(day);

    final result = await prefs.load();
    expect(result.focusedDay, day);
  });

  test('saveTodoCategory 후 load 가 동일한 카테고리를 반환한다', () async {
    final prefs = CalendarViewPreferences();
    await prefs.saveTodoCategory('장보기');

    final result = await prefs.load();
    expect(result.todoCategory, '장보기');
  });

  test('모든 값을 저장 후 한 번에 복원한다', () async {
    final prefs = CalendarViewPreferences();
    await prefs.saveTabIndex(1);
    await prefs.saveCalendarFormat(CalendarFormat.twoWeeks);
    await prefs.saveFocusedDay(DateTime(2026, 6, 20));
    await prefs.saveTodoCategory('집안일');

    final result = await prefs.load();
    expect(result.tabIndex, 1);
    expect(result.calendarFormat, CalendarFormat.twoWeeks);
    expect(result.focusedDay, DateTime(2026, 6, 20));
    expect(result.todoCategory, '집안일');
  });

  test('유효하지 않은 포맷 인덱스는 month로 폴백한다', () async {
    SharedPreferences.setMockInitialValues({
      'calendar_view_format': 99,
    });
    final prefs = CalendarViewPreferences();
    final result = await prefs.load();
    expect(result.calendarFormat, CalendarFormat.month);
  });
}
