import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/calendar/data/calendar_repository.dart';
import 'package:dongine/features/calendar/data/google_calendar_service.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/features/calendar/presentation/google_calendar_settings.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/event_model.dart';
import 'package:dongine/shared/models/family_model.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'user-gcal-test';
}

class _FakeCalendarRepository extends CalendarRepository {
  _FakeCalendarRepository() : super.forTest();

  @override
  Future<List<EventModel>> getEventsByExternalSource(
    String familyId,
    String externalSource,
  ) async =>
      const [];

  @override
  Future<EventModel?> getEvent(String familyId, String eventId) async => null;

  @override
  Future<void> upsertEvent(String familyId, EventModel event) async {}

  @override
  Future<void> deleteEvent(String familyId, String eventId) async {}
}

class _TestGoogleCalendarService extends GoogleCalendarService {
  _TestGoogleCalendarService({
    this.syncResult,
    this.throwOnSync = false,
  });

  final GoogleCalendarSyncResult? syncResult;
  final bool throwOnSync;

  @override
  Future<bool> signInSilently() async => false;

  @override
  Future<bool> signIn() async => false;

  @override
  Future<void> signOut() async {}

  @override
  String? get currentEmail => 'sync@test.com';

  @override
  Future<GoogleCalendarSyncResult> syncToFirestore(
    String familyId,
    CalendarRepository calendarRepo,
    String userId,
  ) async {
    if (throwOnSync) {
      throw Exception('sync-boom');
    }
    return syncResult ??
        const GoogleCalendarSyncResult(
          createdCount: 0,
          updatedCount: 0,
          removedCount: 0,
          skippedCount: 0,
        );
  }
}

// ---------------------------------------------------------------------------

final _testFamily = FamilyModel(
  id: 'fam-gcal',
  name: 'GCal 테스트 가족',
  createdBy: 'user-gcal-test',
  inviteCode: 'GCAL01',
  createdAt: DateTime(2026, 3, 1),
);

List<Override> _baseOverrides({
  required bool signedIn,
  required GoogleCalendarService calendarService,
  AsyncValue<FamilyModel?>? family,
  AsyncValue<User?>? authUser,
}) {
  final User? resolvedAuth = authUser == null
      ? _FakeUser()
      : authUser.valueOrNull;

  return [
    authStateProvider.overrideWith(
      (ref) => Stream<User?>.value(resolvedAuth),
    ),
    currentFamilyProvider.overrideWithValue(
      family ?? AsyncValue.data(_testFamily),
    ),
    calendarRepositoryProvider.overrideWithValue(_FakeCalendarRepository()),
    googleCalendarServiceProvider.overrideWithValue(calendarService),
    googleCalendarSignedInProvider.overrideWith((ref) => signedIn),
  ];
}

Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GoogleCalendarSettings(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('연결·동기화 버튼 노출', () {
    testWidgets('미연결 시 연결 버튼만 보이고 동기화·해제는 없다', (tester) async {
      final service = _TestGoogleCalendarService();
      await tester.pumpWidget(
        _wrap(_baseOverrides(signedIn: false, calendarService: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Google Calendar 연결'), findsOneWidget);
      expect(find.text('동기화'), findsNothing);
      expect(find.text('연결 해제'), findsNothing);
    });

    testWidgets('연결됨이면 동기화·연결 해제가 보이고 연결 버튼은 없다', (tester) async {
      final service = _TestGoogleCalendarService();
      await tester.pumpWidget(
        _wrap(_baseOverrides(signedIn: true, calendarService: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Google Calendar 연결'), findsNothing);
      expect(find.text('동기화'), findsOneWidget);
      expect(find.text('연결 해제'), findsOneWidget);
      expect(find.text('연결됨'), findsOneWidget);
      expect(find.text('sync@test.com'), findsOneWidget);
    });
  });

  group('마지막 동기화 카드', () {
    testWidgets('저장된 성공 기록이 있으면 성공 카드와 메시지를 표시한다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'google_calendar_last_sync_at_ms':
            DateTime(2026, 3, 15, 10, 30).millisecondsSinceEpoch,
        'google_calendar_last_sync_success': true,
        'google_calendar_last_sync_message': '3개 추가, 1개 갱신',
      });

      final service = _TestGoogleCalendarService();
      await tester.pumpWidget(
        _wrap(_baseOverrides(signedIn: false, calendarService: service)),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('마지막 동기화 성공'), findsOneWidget);
      expect(find.text('3개 추가, 1개 갱신'), findsOneWidget);
      expect(find.text('마지막 동기화 실패'), findsNothing);
    });

    testWidgets('저장된 실패 기록이 있으면 실패 카드와 메시지를 표시한다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'google_calendar_last_sync_at_ms':
            DateTime(2026, 3, 16, 9, 0).millisecondsSinceEpoch,
        'google_calendar_last_sync_success': false,
        'google_calendar_last_sync_message': '동기화 실패: 테스트',
      });

      final service = _TestGoogleCalendarService();
      await tester.pumpWidget(
        _wrap(_baseOverrides(signedIn: false, calendarService: service)),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('마지막 동기화 실패'), findsOneWidget);
      expect(find.text('동기화 실패: 테스트'), findsOneWidget);
      expect(find.text('마지막 동기화 성공'), findsNothing);
    });

    testWidgets('동기화 성공 후 카드에 syncSummaryMessage 가 반영된다', (tester) async {
      final service = _TestGoogleCalendarService(
        syncResult: const GoogleCalendarSyncResult(
          createdCount: 1,
          updatedCount: 2,
          removedCount: 0,
          skippedCount: 0,
        ),
      );
      await tester.pumpWidget(
        _wrap(_baseOverrides(signedIn: true, calendarService: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('동기화'));
      await tester.pumpAndSettle();

      expect(find.text('1개 추가, 2개 갱신'), findsOneWidget);
      expect(find.text('마지막 동기화 성공'), findsOneWidget);
    });

    testWidgets('동기화 예외 시 실패 카드에 오류 메시지가 남는다', (tester) async {
      final service = _TestGoogleCalendarService(throwOnSync: true);
      await tester.pumpWidget(
        _wrap(_baseOverrides(signedIn: true, calendarService: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('동기화'));
      await tester.pumpAndSettle();

      expect(find.text('마지막 동기화 실패'), findsOneWidget);
      expect(find.textContaining('동기화 실패'), findsWidgets);
    });
  });

  group('동기화 전제 조건 메시지', () {
    testWidgets('가족이 없으면 동기화 시 안내 문구를 표시한다', (tester) async {
      final service = _TestGoogleCalendarService();
      await tester.pumpWidget(
        _wrap(
          _baseOverrides(
            signedIn: true,
            calendarService: service,
            family: const AsyncValue<FamilyModel?>.data(null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('동기화'));
      await tester.pumpAndSettle();

      expect(
        find.text('가족 또는 사용자 정보를 찾을 수 없습니다'),
        findsOneWidget,
      );
    });

    testWidgets('사용자가 없으면 동기화 시 안내 문구를 표시한다', (tester) async {
      final service = _TestGoogleCalendarService();
      await tester.pumpWidget(
        _wrap(
          _baseOverrides(
            signedIn: true,
            calendarService: service,
            authUser: const AsyncValue<User?>.data(null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('동기화'));
      await tester.pumpAndSettle();

      expect(
        find.text('가족 또는 사용자 정보를 찾을 수 없습니다'),
        findsOneWidget,
      );
    });
  });
}
