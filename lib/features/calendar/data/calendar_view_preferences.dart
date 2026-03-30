import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

/// 캘린더 화면의 보기 상태를 `shared_preferences`에 보관한다.
class CalendarViewPreferences {
  static const _tabIndexKey = 'calendar_view_tab_index';
  static const _calendarFormatKey = 'calendar_view_format';
  static const _focusedYearKey = 'calendar_view_focused_year';
  static const _focusedMonthKey = 'calendar_view_focused_month';
  static const _focusedDayKey = 'calendar_view_focused_day';
  static const _todoCategoryKey = 'calendar_view_todo_category';

  Future<CalendarViewPersisted> load() async {
    final prefs = await SharedPreferences.getInstance();

    final tabIndex = prefs.getInt(_tabIndexKey) ?? 0;
    final formatIndex = prefs.getInt(_calendarFormatKey);
    final year = prefs.getInt(_focusedYearKey);
    final month = prefs.getInt(_focusedMonthKey);
    final day = prefs.getInt(_focusedDayKey);
    final todoCategory = prefs.getString(_todoCategoryKey) ?? '전체';

    CalendarFormat calendarFormat = CalendarFormat.month;
    if (formatIndex != null && formatIndex >= 0 && formatIndex < 3) {
      calendarFormat = CalendarFormat.values[formatIndex];
    }

    DateTime? focusedDay;
    if (year != null && month != null && day != null) {
      focusedDay = DateTime(year, month, day);
    }

    return CalendarViewPersisted(
      tabIndex: tabIndex,
      calendarFormat: calendarFormat,
      focusedDay: focusedDay,
      todoCategory: todoCategory,
    );
  }

  Future<void> saveTabIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tabIndexKey, index);
  }

  Future<void> saveCalendarFormat(CalendarFormat format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_calendarFormatKey, format.index);
  }

  Future<void> saveFocusedDay(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_focusedYearKey, day.year);
    await prefs.setInt(_focusedMonthKey, day.month);
    await prefs.setInt(_focusedDayKey, day.day);
  }

  Future<void> saveTodoCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_todoCategoryKey, category);
  }
}

class CalendarViewPersisted {
  final int tabIndex;
  final CalendarFormat calendarFormat;
  final DateTime? focusedDay;
  final String todoCategory;

  const CalendarViewPersisted({
    required this.tabIndex,
    required this.calendarFormat,
    required this.focusedDay,
    required this.todoCategory,
  });
}
