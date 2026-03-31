import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:dongine/features/auth/data/auth_repository.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/calendar/data/calendar_view_preferences.dart';
import 'package:dongine/features/calendar/data/google_calendar_service.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/features/calendar/presentation/calendar_screen.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/shared/models/event_model.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/user_model.dart';

import 'fake_calendar_repository.dart';
import '../todo/fake_todo_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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

class _FakeAuthUser extends Fake implements User {
  _FakeAuthUser(this._uid);
  final String _uid;

  @override
  String get uid => _uid;
}

class _FakeAuthRepository implements AuthRepositoryBase {
  _FakeAuthRepository(this._user);
  final User _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(_user);

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<UserCredential> signUpWithEmail(
          String email, String password, String displayName) async =>
      throw UnimplementedError();

  @override
  Future<UserModel?> getUserProfile(String uid) async => null;

  @override
  Future<void> updateUserProfile(UserModel user) async {}

  @override
  Future<void> updateDisplayName(String newDisplayName) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeCalendarViewPreferencesWithTab extends CalendarViewPreferences {
  _FakeCalendarViewPreferencesWithTab(this.tabIndex);
  final int tabIndex;

  @override
  Future<CalendarViewPersisted> load() async => CalendarViewPersisted(
        tabIndex: tabIndex,
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

const _testUserId = 'uid-edit-test';

final _testFamily = FamilyModel(
  id: 'fam-edit-1',
  name: '수정 테스트 가족',
  createdBy: _testUserId,
  inviteCode: 'EDIT01',
  createdAt: DateTime(2026, 1, 1),
);

List<Override> _overrides({
  required FakeCalendarRepository calendarRepo,
  required FakeTodoRepository todoRepo,
  int tabIndex = 0,
}) {
  final authRepo = _FakeAuthRepository(_FakeAuthUser(_testUserId));
  return [
    currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
    calendarViewPreferencesProvider
        .overrideWithValue(_FakeCalendarViewPreferencesWithTab(tabIndex)),
    familyMembersProvider(_testFamily.id)
        .overrideWith((ref) => Stream.value(const <FamilyMember>[])),
    authRepositoryProvider.overrideWithValue(authRepo),
    authStateProvider.overrideWith((ref) => authRepo.authStateChanges),
    calendarRepositoryProvider.overrideWithValue(calendarRepo),
    todoRepositoryProvider.overrideWithValue(todoRepo),
    googleCalendarSignedInProvider.overrideWith((ref) => false),
    googleCalendarServiceProvider
        .overrideWithValue(_FakeGoogleCalendarService()),
  ];
}

Widget _buildApp({
  required FakeCalendarRepository calendarRepo,
  required FakeTodoRepository todoRepo,
  int initialTabIndex = 0,
}) {
  return ProviderScope(
    overrides: _overrides(
      calendarRepo: calendarRepo,
      todoRepo: todoRepo,
      tabIndex: initialTabIndex,
    ),
    child: MaterialApp(
      locale: const Locale('ko', 'KR'),
      home: const CalendarScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

EventModel _makeEvent({
  String id = 'evt-1',
  String title = '기존 일정',
  String type = 'general',
  bool isGoogleImported = false,
  Map<String, dynamic>? mealVote,
  List<Map<String, dynamic>>? places,
  int? budget,
  bool? dday,
}) {
  final now = DateTime.now();
  final startAt = DateTime(now.year, now.month, now.day, 14, 0);
  return EventModel(
    id: id,
    title: title,
    type: type,
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 1)),
    color: '#4285F4',
    createdBy: _testUserId,
    createdAt: now,
    googleSyncDirection: isGoogleImported ? 'imported' : null,
    mealVote: mealVote,
    places: places,
    budget: budget,
    dday: dday,
  );
}

Finder _bottomSheetSave() => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.widgetWithText(FilledButton, '저장'),
    );

Future<void> _tapSheetSave(WidgetTester tester) async {
  final btn = _bottomSheetSave();
  await tester.ensureVisible(btn);
  await tester.tap(btn, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _tapBottomSheetText(WidgetTester tester, String text) async {
  var target = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.text(text),
  );
  if (target.evaluate().isEmpty) {
    target = find.text(text);
  }
  await tester.ensureVisible(target.first);
  await tester.tap(target.first, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _openCreateSheet(WidgetTester tester) async {
  final fab = find.byType(FloatingActionButton);
  await tester.ensureVisible(fab);
  await tester.tap(fab, warnIfMissed: false);
  await tester.pumpAndSettle();
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

  // =========================================================================
  // 1) 로컬 일정 수정 흐름
  // =========================================================================
  group('로컬 일정 수정 (캘린더 탭)', () {
    testWidgets('일반 이벤트 탭 → 수정 시트 → 제목 변경 → updateEvent 호출',
        (tester) async {
      final existingEvent = _makeEvent(title: '원래 제목');
      final cal = FakeCalendarRepository(seedEvents: [existingEvent]);
      final todo = FakeTodoRepository(const []);

      await tester.pumpWidget(_buildApp(calendarRepo: cal, todoRepo: todo));
      await tester.pumpAndSettle();

      // 이벤트 카드가 보여야 한다
      expect(find.text('원래 제목'), findsOneWidget);

      // 탭하여 수정 시트를 연다
      await tester.tap(find.text('원래 제목'));
      await tester.pumpAndSettle();

      // 수정 시트가 열리고 '일정 수정' 타이틀이 보여야 한다
      expect(find.text('일정 수정'), findsOneWidget);

      // 제목 변경
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, '수정된 제목');
      await _tapSheetSave(tester);

      // updateEvent 호출 확인
      expect(cal.lastUpdatedEvent, isNotNull);
      expect(cal.lastUpdatedEvent!.title, '수정된 제목');
      expect(cal.lastUpdatedEvent!.id, existingEvent.id);
      expect(cal.lastUpdateFamilyId, _testFamily.id);
      // createEvent은 호출되지 않아야 한다
      expect(cal.lastCreatedEvent, isNull);
    });

    testWidgets('Google imported 이벤트는 탭해도 수정 시트가 열리지 않는다',
        (tester) async {
      final imported =
          _makeEvent(title: 'Google 일정', isGoogleImported: true);
      final cal = FakeCalendarRepository(seedEvents: [imported]);
      final todo = FakeTodoRepository(const []);

      await tester.pumpWidget(_buildApp(calendarRepo: cal, todoRepo: todo));
      await tester.pumpAndSettle();

      expect(find.text('Google 일정'), findsOneWidget);

      await tester.tap(find.text('Google 일정'));
      await tester.pumpAndSettle();

      // 수정 시트가 열리지 않아야 한다
      expect(find.text('일정 수정'), findsNothing);
    });
  });

  // =========================================================================
  // 2) 플래너 수정 흐름 (캘린더 탭에서)
  // =========================================================================
  group('플래너 수정 (캘린더 탭)', () {
    testWidgets('meal 이벤트 탭 → 플래너 수정 시트 → updateEvent 호출',
        (tester) async {
      final mealEvent = _makeEvent(
        title: '점심 약속',
        type: 'meal',
        mealVote: {
          'options': ['파스타', '초밥'],
          'votes': <String, String>{},
          'decided': null,
        },
      );
      final cal = FakeCalendarRepository(seedEvents: [mealEvent]);
      final todo = FakeTodoRepository(const []);

      await tester.pumpWidget(_buildApp(calendarRepo: cal, todoRepo: todo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('점심 약속'));
      await tester.pumpAndSettle();

      expect(find.text('식사 플래너 수정'), findsOneWidget);

      // 제목 변경 후 저장
      await tester.enterText(find.byType(TextField).first, '저녁 약속');
      await _tapSheetSave(tester);

      expect(cal.lastUpdatedEvent, isNotNull);
      expect(cal.lastUpdatedEvent!.title, '저녁 약속');
      expect(cal.lastUpdatedEvent!.type, 'meal');
    });
  });

  // =========================================================================
  // 3) 플래너 생성이 실제로 저장되는지 확인
  // =========================================================================
  group('플래너 생성 저장 확인', () {
    testWidgets('식사 플래너 생성 → createEvent 호출 + type meal',
        (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);

      await tester.pumpWidget(
        _buildApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, '메뉴 투표, 장소 선택');

      await tester.enterText(find.byType(TextField).first, '주말 브런치');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent, isNotNull);
      expect(cal.lastCreatedEvent!.title, '주말 브런치');
      expect(cal.lastCreatedEvent!.type, 'meal');
      expect(cal.lastCreatedEvent!.createdBy, _testUserId);
      expect(cal.lastCreatedEvent!.mealVote, isNotNull);
    });

    testWidgets('데이트 플래너 생성 → createEvent 호출 + type date',
        (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);

      await tester.pumpWidget(
        _buildApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, '코스, 장소, 예산');

      await tester.enterText(find.byType(TextField).first, '한강 데이트');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent, isNotNull);
      expect(cal.lastCreatedEvent!.title, '한강 데이트');
      expect(cal.lastCreatedEvent!.type, 'date');
      expect(cal.lastCreatedEvent!.isAllDay, isTrue);
    });

    testWidgets('기념일 플래너 생성 → createEvent 호출 + type anniversary',
        (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);

      await tester.pumpWidget(
        _buildApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, 'D-day 카운트');

      await tester.enterText(find.byType(TextField).first, '100일');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent, isNotNull);
      expect(cal.lastCreatedEvent!.title, '100일');
      expect(cal.lastCreatedEvent!.type, 'anniversary');
      expect(cal.lastCreatedEvent!.dday, isTrue);
    });

    testWidgets('병원 플래너 생성 → createEvent 호출 + type hospital',
        (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);

      await tester.pumpWidget(
        _buildApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, '장소, 시간');

      await tester.enterText(find.byType(TextField).first, '치과');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent, isNotNull);
      expect(cal.lastCreatedEvent!.title, '치과');
      expect(cal.lastCreatedEvent!.type, 'hospital');
    });
  });

  // =========================================================================
  // 4) 기존 생성·삭제 흐름이 깨지지 않는지 회귀 확인
  // =========================================================================
  group('기존 생성 흐름 회귀', () {
    testWidgets('일반 이벤트 생성은 여전히 createEvent를 호출한다',
        (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);

      await tester.pumpWidget(_buildApp(calendarRepo: cal, todoRepo: todo));
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);

      await tester.enterText(find.byType(TextField).first, '팀 미팅');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent, isNotNull);
      expect(cal.lastCreatedEvent!.title, '팀 미팅');
      expect(cal.lastCreatedEvent!.type, 'general');
      expect(cal.lastUpdatedEvent, isNull);
    });
  });
}
