import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/calendar/data/calendar_view_preferences.dart';
import 'package:dongine/features/calendar/data/google_calendar_service.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/features/calendar/presentation/calendar_screen.dart';
import 'package:dongine/features/calendar/presentation/google_calendar_settings.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/shared/models/event_model.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/todo_model.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeCalendarViewPreferences extends CalendarViewPreferences {
  _FakeCalendarViewPreferences();

  @override
  Future<CalendarViewPersisted> load() async => const CalendarViewPersisted(
        tabIndex: 0,
        calendarFormat: CalendarFormat.month,
        focusedDay: null,
        todoCategory: '전체',
      );

  @override
  Future<void> saveTabIndex(int index) async {}
  @override
  Future<void> saveCalendarFormat(CalendarFormat format) async {}
  @override
  Future<void> saveFocusedDay(DateTime day) async {}
  @override
  Future<void> saveTodoCategory(String category) async {}
}

class _FakeGoogleCalendarService extends GoogleCalendarService {
  @override
  Future<bool> signInSilently() async => false;

  @override
  Future<bool> signIn() async => false;

  @override
  Future<void> signOut() async {}

  @override
  String? get currentEmail => null;
}

// ---------------------------------------------------------------------------
// Test data & helpers
// ---------------------------------------------------------------------------

final _testFamily = FamilyModel(
  id: 'fam-1',
  name: '테스트 가족',
  createdBy: 'uid-1',
  inviteCode: 'ABCDEF',
  createdAt: DateTime(2026, 1, 1),
);

List<Override> _baseOverrides({
  required AsyncValue<FamilyModel?> familyValue,
}) =>
    [
      currentFamilyProvider.overrideWithValue(familyValue),
      calendarViewPreferencesProvider
          .overrideWithValue(_FakeCalendarViewPreferences()),
      eventsProvider(_testFamily.id)
          .overrideWith((ref) => Stream<List<EventModel>>.value([])),
      todosProvider(_testFamily.id)
          .overrideWith((ref) => Stream<List<TodoModel>>.value([])),
      familyMembersProvider(_testFamily.id)
          .overrideWith((ref) => Stream<List<FamilyMember>>.value([])),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      googleCalendarSignedInProvider.overrideWith((ref) => false),
      googleCalendarServiceProvider
          .overrideWithValue(_FakeGoogleCalendarService()),
    ];

Widget _buildApp({AsyncValue<FamilyModel?>? familyValue}) {
  return ProviderScope(
    overrides: _baseOverrides(
      familyValue: familyValue ?? AsyncValue.data(_testFamily),
    ),
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

  // ----- 1. 가족 유무에 따른 렌더링 -------------------------------------------

  group('가족 상태에 따른 화면 분기', () {
    testWidgets('가족이 없으면 안내 문구가 표시된다', (tester) async {
      await tester.pumpWidget(
        _buildApp(familyValue: const AsyncValue.data(null)),
      );
      await tester.pumpAndSettle();

      expect(find.text('가족을 먼저 생성해주세요'), findsOneWidget);
      // 탭이 렌더링되지 않는다
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('가족이 있으면 탭 3개가 렌더링된다', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
      // 캘린더 탭 텍스트 2개 (AppBar title + Tab)
      expect(find.text('캘린더'), findsNWidgets(2));
      expect(find.text('TODO'), findsOneWidget);
      expect(find.text('플래너'), findsOneWidget);
    });
  });

  // ----- 2. 탭 전환 시 FAB 동작 진입점 회귀 -----------------------------------

  group('탭 전환 FAB 회귀', () {
    testWidgets('각 탭에서 FAB가 존재하고 탭 가능하다', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // 탭 0 (캘린더) – FAB 존재
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      // 바텀시트가 열린다 (이벤트 생성 시트)
      expect(find.byType(BottomSheet), findsOneWidget);
      // 시트 닫기
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // 탭 1 (TODO) 전환
      await tester.tap(find.text('TODO'));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // 탭 2 (플래너) 전환
      await tester.tap(find.text('플래너'));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });

  // ----- 3. 설정 버튼 → Google Calendar 설정 바텀시트 -------------------------

  group('Google Calendar 설정 진입', () {
    testWidgets('설정 아이콘 탭 시 바텀시트가 열린다', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // AppBar 설정 아이콘 탭
      final settingsButton = find.byIcon(Icons.settings);
      expect(settingsButton, findsOneWidget);

      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // GoogleCalendarSettings 위젯이 렌더링된다
      expect(find.byType(GoogleCalendarSettings), findsOneWidget);
      expect(find.text('Google Calendar 설정'), findsOneWidget);
    });

    testWidgets('설정 바텀시트에 연결 안 됨 상태가 기본 표시된다', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // 미로그인 상태 UI
      expect(find.text('연결 안 됨'), findsOneWidget);
      expect(find.text('Google Calendar 연결'), findsOneWidget);
    });
  });
}
