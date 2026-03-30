import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/calendar/data/calendar_view_preferences.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/features/calendar/presentation/calendar_screen.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/shared/models/event_model.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/todo_model.dart';

// ---------------------------------------------------------------------------
// Fake CalendarViewPreferences
// ---------------------------------------------------------------------------

class FakeCalendarViewPreferences extends CalendarViewPreferences {
  final CalendarViewPersisted _persisted;

  int saveTabIndexCallCount = 0;
  int? lastSavedTabIndex;

  int saveCalendarFormatCallCount = 0;
  CalendarFormat? lastSavedFormat;

  int saveFocusedDayCallCount = 0;
  DateTime? lastSavedFocusedDay;

  int saveTodoCategoryCallCount = 0;
  String? lastSavedCategory;

  FakeCalendarViewPreferences(this._persisted);

  factory FakeCalendarViewPreferences.defaults() =>
      FakeCalendarViewPreferences(const CalendarViewPersisted(
        tabIndex: 0,
        calendarFormat: CalendarFormat.month,
        focusedDay: null,
        todoCategory: '전체',
      ));

  @override
  Future<CalendarViewPersisted> load() async => _persisted;

  @override
  Future<void> saveTabIndex(int index) async {
    saveTabIndexCallCount++;
    lastSavedTabIndex = index;
  }

  @override
  Future<void> saveCalendarFormat(CalendarFormat format) async {
    saveCalendarFormatCallCount++;
    lastSavedFormat = format;
  }

  @override
  Future<void> saveFocusedDay(DateTime day) async {
    saveFocusedDayCallCount++;
    lastSavedFocusedDay = day;
  }

  @override
  Future<void> saveTodoCategory(String category) async {
    saveTodoCategoryCallCount++;
    lastSavedCategory = category;
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _testFamily = FamilyModel(
  id: 'fam-1',
  name: '테스트 가족',
  createdBy: 'uid-1',
  inviteCode: 'ABCDEF',
  createdAt: DateTime(2026, 1, 1),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<Override> _buildOverrides(FakeCalendarViewPreferences fakePrefs) => [
      currentFamilyProvider
          .overrideWithValue(AsyncValue.data(_testFamily)),
      calendarViewPreferencesProvider.overrideWithValue(fakePrefs),
      eventsProvider(_testFamily.id)
          .overrideWith((ref) => Stream<List<EventModel>>.value([])),
      todosProvider(_testFamily.id)
          .overrideWith((ref) => Stream<List<TodoModel>>.value([])),
      familyMembersProvider(_testFamily.id)
          .overrideWith((ref) => Stream<List<FamilyMember>>.value([])),
      authStateProvider.overrideWith(
        (ref) => Stream<User?>.value(null),
      ),
      googleCalendarSignedInProvider.overrideWith((ref) => false),
    ];

Widget _buildApp(FakeCalendarViewPreferences fakePrefs) {
  return ProviderScope(
    overrides: _buildOverrides(fakePrefs),
    child: const MaterialApp(home: CalendarScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('캘린더 보기 상태 복원', () {
    testWidgets('기본 상태: 탭 0(캘린더) 선택, 전체 카테고리', (tester) async {
      final fakePrefs = FakeCalendarViewPreferences.defaults();
      await tester.pumpWidget(_buildApp(fakePrefs));
      await tester.pumpAndSettle();

      // TabBar 탭 3개 + AppBar 타이틀 '캘린더'
      expect(find.text('캘린더'), findsNWidgets(2));
      expect(find.text('TODO'), findsOneWidget);
      expect(find.text('플래너'), findsOneWidget);

      // 탭 0 이 활성이면 '일정이 없습니다' 가 보인다 (빈 이벤트)
      expect(find.text('일정이 없습니다'), findsOneWidget);
    });

    testWidgets('저장된 탭 1(TODO) 이 복원된다', (tester) async {
      final fakePrefs = FakeCalendarViewPreferences(
        const CalendarViewPersisted(
          tabIndex: 1,
          calendarFormat: CalendarFormat.month,
          focusedDay: null,
          todoCategory: '전체',
        ),
      );
      await tester.pumpWidget(_buildApp(fakePrefs));
      await tester.pumpAndSettle();

      // TODO 탭이 보이면 카테고리 필터 칩이 존재한다
      expect(find.byType(FilterChip), findsNWidgets(5));
      expect(find.textContaining('할 일이 없습니다'), findsOneWidget);
    });

    testWidgets('저장된 탭 2(플래너) 가 복원된다', (tester) async {
      final fakePrefs = FakeCalendarViewPreferences(
        const CalendarViewPersisted(
          tabIndex: 2,
          calendarFormat: CalendarFormat.month,
          focusedDay: null,
          todoCategory: '전체',
        ),
      );
      await tester.pumpWidget(_buildApp(fakePrefs));
      await tester.pumpAndSettle();

      // 플래너 탭의 빈 상태 메시지
      expect(find.textContaining('플래너 일정이 없습니다'), findsOneWidget);
    });

    testWidgets('저장된 TODO 카테고리가 복원되고 필터 칩에 반영된다',
        (tester) async {
      final fakePrefs = FakeCalendarViewPreferences(
        const CalendarViewPersisted(
          tabIndex: 1,
          calendarFormat: CalendarFormat.month,
          focusedDay: null,
          todoCategory: '장보기',
        ),
      );
      await tester.pumpWidget(_buildApp(fakePrefs));
      await tester.pumpAndSettle();

      // '장보기' 칩이 selected 상태여야 한다
      final chipFinder = find.ancestor(
        of: find.text('장보기'),
        matching: find.byType(FilterChip),
      );
      expect(chipFinder, findsOneWidget);
      final chip = tester.widget<FilterChip>(chipFinder);
      expect(chip.selected, isTrue);

      // '전체' 칩은 selected 가 아니어야 한다
      final allChipFinder = find.ancestor(
        of: find.text('전체'),
        matching: find.byType(FilterChip),
      );
      final allChip = tester.widget<FilterChip>(allChipFinder);
      expect(allChip.selected, isFalse);

      // 빈 필터 결과 메시지
      expect(find.textContaining("'장보기' 항목이 없습니다"), findsOneWidget);
    });

    testWidgets('저장된 캘린더 포맷(week)이 복원된다', (tester) async {
      final fakePrefs = FakeCalendarViewPreferences(
        const CalendarViewPersisted(
          tabIndex: 0,
          calendarFormat: CalendarFormat.week,
          focusedDay: null,
          todoCategory: '전체',
        ),
      );
      await tester.pumpWidget(_buildApp(fakePrefs));
      await tester.pumpAndSettle();

      // TableCalendar 위젯이 week 포맷으로 렌더링 된다
      final calendarFinder = find.byType(TableCalendar<EventModel>);
      expect(calendarFinder, findsOneWidget);
      final calendar =
          tester.widget<TableCalendar<EventModel>>(calendarFinder);
      expect(calendar.calendarFormat, CalendarFormat.week);
    });

    testWidgets('저장된 집중 날짜가 복원된다', (tester) async {
      final targetDay = DateTime(2026, 6, 15);
      final fakePrefs = FakeCalendarViewPreferences(
        CalendarViewPersisted(
          tabIndex: 0,
          calendarFormat: CalendarFormat.month,
          focusedDay: targetDay,
          todoCategory: '전체',
        ),
      );
      await tester.pumpWidget(_buildApp(fakePrefs));
      await tester.pumpAndSettle();

      final calendarFinder = find.byType(TableCalendar<EventModel>);
      final calendar =
          tester.widget<TableCalendar<EventModel>>(calendarFinder);
      // TableCalendar 이 내부적으로 UTC 로 정규화할 수 있으므로 날짜 성분만 비교
      expect(calendar.focusedDay.year, targetDay.year);
      expect(calendar.focusedDay.month, targetDay.month);
      expect(calendar.focusedDay.day, targetDay.day);
    });

    testWidgets('모든 값이 동시에 복원된다', (tester) async {
      final targetDay = DateTime(2026, 8, 20);
      final fakePrefs = FakeCalendarViewPreferences(
        CalendarViewPersisted(
          tabIndex: 1,
          calendarFormat: CalendarFormat.twoWeeks,
          focusedDay: targetDay,
          todoCategory: '집안일',
        ),
      );
      await tester.pumpWidget(_buildApp(fakePrefs));
      await tester.pumpAndSettle();

      // TODO 탭이 활성 → 필터 칩 존재
      expect(find.byType(FilterChip), findsNWidgets(5));

      // '집안일' 칩이 selected
      final chipFinder = find.ancestor(
        of: find.text('집안일'),
        matching: find.byType(FilterChip),
      );
      final chip = tester.widget<FilterChip>(chipFinder);
      expect(chip.selected, isTrue);
    });
  });

  group('캘린더 보기 상태 저장', () {
    testWidgets('탭 전환 시 saveTabIndex 가 호출된다', (tester) async {
      final fakePrefs = FakeCalendarViewPreferences.defaults();
      await tester.pumpWidget(_buildApp(fakePrefs));
      await tester.pumpAndSettle();

      // TODO 탭으로 전환
      await tester.tap(find.text('TODO'));
      await tester.pumpAndSettle();

      expect(fakePrefs.saveTabIndexCallCount, greaterThanOrEqualTo(1));
      expect(fakePrefs.lastSavedTabIndex, 1);
    });

    testWidgets('카테고리 변경 시 saveTodoCategory 가 호출된다',
        (tester) async {
      final fakePrefs = FakeCalendarViewPreferences(
        const CalendarViewPersisted(
          tabIndex: 1,
          calendarFormat: CalendarFormat.month,
          focusedDay: null,
          todoCategory: '전체',
        ),
      );
      await tester.pumpWidget(_buildApp(fakePrefs));
      await tester.pumpAndSettle();

      // '장보기' 카테고리 칩 탭
      await tester.tap(find.text('장보기'));
      await tester.pumpAndSettle();

      expect(fakePrefs.saveTodoCategoryCallCount, 1);
      expect(fakePrefs.lastSavedCategory, '장보기');
    });
  });
}
