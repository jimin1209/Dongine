import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
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
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/user_model.dart';

import 'fake_calendar_repository.dart';
import '../todo/fake_todo_repository.dart';

// ---------------------------------------------------------------------------
// Fakes (calendar_screen_widget_test와 동일 패턴)
// ---------------------------------------------------------------------------

class _FakeGoogleCalendarService extends GoogleCalendarService {
  @override
  Future<GoogleSignInResult> signInSilently() async =>
      const GoogleSignInResult.cancelled();

  @override
  Future<GoogleSignInResult> signIn() async =>
      const GoogleSignInResult.cancelled();

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
  Future<UserCredential> signInWithEmail(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async => null;

  @override
  Future<void> updateUserProfile(UserModel user) async {}

  @override
  Future<void> updateDisplayName(String newDisplayName) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<UserCredential> signInWithGoogle() async => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

const _testUserId = 'uid-sheet-test';

final _testFamily = FamilyModel(
  id: 'fam-sheet-1',
  name: '시트 테스트 가족',
  createdBy: _testUserId,
  inviteCode: 'SHEET1',
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
    familyMembersProvider(_testFamily.id).overrideWith(
      (ref) => Stream<List<FamilyMember>>.value(const []),
    ),
    authRepositoryProvider.overrideWithValue(authRepo),
    authStateProvider.overrideWith((ref) => authRepo.authStateChanges),
    calendarRepositoryProvider.overrideWithValue(calendarRepo),
    todoRepositoryProvider.overrideWithValue(todoRepo),
    googleCalendarSignedInProvider.overrideWith((ref) => false),
    googleCalendarServiceProvider
        .overrideWithValue(_FakeGoogleCalendarService()),
  ];
}

/// 탭 인덱스를 지정해 초기 탭을 맞춘다.
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

Widget _buildCalendarApp({
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

Finder _bottomSheetSave() {
  return find.descendant(
    of: find.byType(BottomSheet),
    matching: find.widgetWithText(FilledButton, '저장'),
  );
}

Future<void> _openCreateSheet(WidgetTester tester) async {
  final fab = find.byType(FloatingActionButton);
  await tester.ensureVisible(fab);
  await tester.tap(fab, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _tapSheetSave(WidgetTester tester) async {
  final saveButton = _bottomSheetSave();
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton, warnIfMissed: false);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('일정 생성 시트', () {
    testWidgets('기본 UI: 제목·유형(일반)·종일·시작일·시작/종료 시각이 보인다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(_buildCalendarApp(calendarRepo: cal, todoRepo: todo));
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);

      expect(find.text('새 일정'), findsOneWidget);
      expect(find.text('제목'), findsOneWidget);
      expect(find.text('유형'), findsOneWidget);
      expect(find.text('일반'), findsWidgets);
      expect(find.text('종일'), findsOneWidget);

      final todayStr = DateFormat('M/d (E)', 'ko_KR').format(
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      );
      expect(find.text(todayStr), findsWidgets);

      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining(RegExp(r'\d{2}:\d{2}')),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('제목이 비어 있으면 저장해도 시트가 유지되고 이벤트가 생성되지 않는다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(_buildCalendarApp(calendarRepo: cal, todoRepo: todo));
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);

      await _tapSheetSave(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(cal.lastCreatedEvent, isNull);
    });

    testWidgets('제목 입력 후 저장하면 시트가 닫히고 createEvent가 호출된다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(_buildCalendarApp(calendarRepo: cal, todoRepo: todo));
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);

      await tester.enterText(find.byType(TextField).first, '회의');
      await _tapSheetSave(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(cal.lastCreateFamilyId, _testFamily.id);
      expect(cal.lastCreatedEvent, isNotNull);
      expect(cal.lastCreatedEvent!.title, '회의');
      expect(cal.lastCreatedEvent!.type, 'general');
      expect(cal.lastCreatedEvent!.createdBy, _testUserId);
      expect(cal.lastCreatedEvent!.isAllDay, isFalse);
    });

    testWidgets('유형을 식사로 바꾼 뒤 저장하면 type이 meal이다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(_buildCalendarApp(calendarRepo: cal, todoRepo: todo));
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('식사').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '저녁');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent?.type, 'meal');
    });

    testWidgets('종일을 켜면 시각 버튼이 사라진다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(_buildCalendarApp(calendarRepo: cal, todoRepo: todo));
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);

      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining(RegExp(r'\d{2}:\d{2}')),
        ),
        findsNWidgets(2),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(SwitchListTile),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining(RegExp(r'\d{2}:\d{2}')),
        ),
        findsNothing,
      );
    });
  });

  group('할 일 생성 시트', () {
    testWidgets('기본 UI: 제목·카테고리·마감일 선택 플레이스홀더가 보인다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 1),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);

      expect(find.text('새 할 일'), findsOneWidget);
      expect(find.text('제목'), findsOneWidget);
      expect(find.text('카테고리'), findsOneWidget);
      expect(find.text('마감일 선택'), findsOneWidget);
    });

    testWidgets('제목이 비어 있으면 저장해도 할 일이 생성되지 않는다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 1),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);

      await _tapSheetSave(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(todo.lastCreated, isNull);
    });

    testWidgets('제목·카테고리 입력 후 저장하면 createTodo가 호출되고 시트가 닫힌다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 1),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);

      await tester.enterText(find.byType(TextField).first, '우유 사기');

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('장보기').last);
      await tester.pumpAndSettle();

      await _tapSheetSave(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(todo.lastCreated?.title, '우유 사기');
      expect(todo.lastCreated?.category, '장보기');
      expect(todo.lastCreated?.createdBy, _testUserId);
      expect(todo.lastCreated?.dueDate, isNull);
    });
  });

  group('플래너 생성 시트', () {
    testWidgets('유형 선택 화면이 열리고 식사 플래너로 진입할 수 있다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);

      expect(find.text('플래너 유형 선택'), findsOneWidget);
      expect(find.text('식사'), findsWidgets);

      await _tapBottomSheetText(tester, '메뉴 투표, 장소 선택');

      expect(find.text('식사 플래너'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining(RegExp(r'\d{2}:\d{2}')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('식사 플래너: 제목 없이 저장하면 이벤트가 생성되지 않는다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, '메뉴 투표, 장소 선택');

      await tester.tap(_bottomSheetSave());
      await tester.pumpAndSettle();

      expect(cal.lastCreatedEvent, isNull);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('데이트 플래너도 제목 없이 저장하면 생성되지 않는다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, '코스, 장소, 예산');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent, isNull);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('기념일 플래너도 제목 없이 저장하면 생성되지 않는다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, 'D-day 카운트');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent, isNull);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('병원 플래너도 제목 없이 저장하면 생성되지 않는다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, '장소, 시간');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent, isNull);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('식사 플래너: 저장 시 meal 타입과 mealVote가 설정된다', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, '메뉴 투표, 장소 선택');

      await tester.enterText(find.byType(TextField).first, '주말 점심');
      final menuFields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(menuFields.at(1), '파스타');
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byIcon(Icons.add),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent?.type, 'meal');
      expect(cal.lastCreatedEvent?.title, '주말 점심');
      final vote = cal.lastCreatedEvent?.mealVote;
      expect(vote, isNotNull);
      expect(List<String>.from(vote!['options'] as List), ['파스타']);
    });

    testWidgets('데이트 플래너: 제목·날짜·코스 장소·예산 UI가 보이고 저장 시 type date', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, '코스, 장소, 예산');

      expect(find.text('데이트 플래너'), findsOneWidget);
      expect(find.text('코스 장소'), findsOneWidget);
      expect(find.text('예산 (원)'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '드라이브');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent?.type, 'date');
      expect(cal.lastCreatedEvent?.title, '드라이브');
      expect(cal.lastCreatedEvent?.isAllDay, isTrue);
    });

    testWidgets('기념일 플래너: D-day 표시 스위치와 저장 시 dday 플래그', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, 'D-day 카운트');

      expect(find.text('기념일 플래너'), findsOneWidget);
      expect(find.text('D-day 표시'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '결혼기념일');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent?.type, 'anniversary');
      expect(cal.lastCreatedEvent?.dday, isTrue);
    });

    testWidgets('병원 플래너: 병원 이름 필드와 저장 시 type hospital', (tester) async {
      final cal = FakeCalendarRepository();
      final todo = FakeTodoRepository(const []);
      await tester.pumpWidget(
        _buildCalendarApp(calendarRepo: cal, todoRepo: todo, initialTabIndex: 2),
      );
      await tester.pumpAndSettle();

      await _openCreateSheet(tester);
      await _tapBottomSheetText(tester, '장소, 시간');

      expect(find.text('병원 플래너'), findsOneWidget);
      expect(find.text('병원 이름'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '건강검진');
      await _tapSheetSave(tester);

      expect(cal.lastCreatedEvent?.type, 'hospital');
      expect(cal.lastCreatedEvent?.title, '건강검진');
    });
  });
}
