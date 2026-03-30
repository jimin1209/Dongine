import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:dongine/shared/models/event_model.dart';
import 'package:dongine/features/calendar/data/calendar_repository.dart';

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
  }
}

class GoogleCalendarService {
  static const googleCalendarSource = 'google_calendar';
  static const _scopes = [gcal.CalendarApi.calendarScope];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  gcal.CalendarApi? _calendarApi;

  /// Google 로그인 및 Calendar API 클라이언트 생성
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;

      final authHeaders = await account.authHeaders;
      final client = _GoogleAuthClient(authHeaders);
      _calendarApi = gcal.CalendarApi(client);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _calendarApi = null;
  }

  /// 로그인 상태 확인
  bool get isSignedIn => _googleSignIn.currentUser != null;

  /// 기존 로그인 세션 복원
  Future<bool> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return false;

      final authHeaders = await account.authHeaders;
      final client = _GoogleAuthClient(authHeaders);
      _calendarApi = gcal.CalendarApi(client);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 현재 로그인된 이메일
  String? get currentEmail => _googleSignIn.currentUser?.email;

  /// Google Calendar에서 이벤트 가져오기
  Future<List<EventModel>> getEvents(DateTime start, DateTime end) async {
    if (_calendarApi == null) {
      throw Exception('Google Calendar에 로그인되어 있지 않습니다');
    }

    try {
      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      return (events.items ?? [])
          .where((e) => e.summary != null)
          .map(_googleEventToEventModel)
          .toList();
    } catch (e) {
      throw Exception('Google Calendar 이벤트를 가져오는데 실패했습니다: $e');
    }
  }

  /// Google Calendar에 이벤트 생성
  Future<String?> createEvent(EventModel event) async {
    if (_calendarApi == null) {
      throw Exception('Google Calendar에 로그인되어 있지 않습니다');
    }

    try {
      final googleEvent = _eventModelToGoogleEvent(event);
      final created = await _calendarApi!.events.insert(googleEvent, 'primary');
      return created.id;
    } catch (e) {
      throw Exception('Google Calendar 이벤트 생성에 실패했습니다: $e');
    }
  }

  /// Google Calendar 이벤트 수정
  Future<void> updateEvent(String googleEventId, EventModel event) async {
    if (_calendarApi == null) {
      throw Exception('Google Calendar에 로그인되어 있지 않습니다');
    }

    try {
      final googleEvent = _eventModelToGoogleEvent(event);
      await _calendarApi!.events.update(googleEvent, 'primary', googleEventId);
    } catch (e) {
      throw Exception('Google Calendar 이벤트 수정에 실패했습니다: $e');
    }
  }

  /// Google Calendar 이벤트 삭제
  Future<void> deleteEvent(String googleEventId) async {
    if (_calendarApi == null) {
      throw Exception('Google Calendar에 로그인되어 있지 않습니다');
    }

    try {
      await _calendarApi!.events.delete('primary', googleEventId);
    } catch (e) {
      throw Exception('Google Calendar 이벤트 삭제에 실패했습니다: $e');
    }
  }

  /// Google Calendar -> Firestore 단방향 동기화
  Future<int> syncToFirestore(
    String familyId,
    CalendarRepository calendarRepo,
    String userId,
  ) async {
    if (_calendarApi == null) {
      throw Exception('Google Calendar에 로그인되어 있지 않습니다');
    }

    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final end = now.add(const Duration(days: 90));

    final googleEvents = await getEvents(start, end);

    int syncCount = 0;
    for (final event in googleEvents) {
      final existingBySourceId = event.externalSourceId == null
          ? null
          : await calendarRepo.getEventByExternalSourceId(
              familyId,
              event.externalSourceId!,
            );
      final existingLegacyEvent = existingBySourceId ??
          await calendarRepo.getEvent(
            familyId,
            event.id,
          );

      final firestoreEvent = event.copyWith(
        id: existingLegacyEvent?.id ?? event.id,
        createdBy: existingLegacyEvent?.createdBy ?? userId,
        createdAt: existingLegacyEvent?.createdAt ?? event.createdAt,
      );
      await calendarRepo.upsertEvent(familyId, firestoreEvent);
      syncCount++;
    }

    return syncCount;
  }

  /// 앱 이벤트를 Google Calendar로 내보내기
  Future<String?> exportToGoogle(EventModel event) async {
    if (event.externalSource == googleCalendarSource &&
        event.externalSourceId != null) {
      await updateEvent(event.externalSourceId!, event);
      return event.externalSourceId;
    }

    return await createEvent(event);
  }

  // ---------------------------------------------------------------------------
  // 변환 헬퍼
  // ---------------------------------------------------------------------------

  /// Google Calendar Event -> EventModel
  EventModel _googleEventToEventModel(gcal.Event googleEvent) {
    final isAllDay = googleEvent.start?.date != null;
    final googleEventId = googleEvent.id ?? const Uuid().v4();

    DateTime startAt;
    DateTime endAt;

    if (isAllDay) {
      startAt = googleEvent.start!.date!;
      endAt = googleEvent.end?.date?.subtract(const Duration(days: 1)) ??
          startAt;
    } else {
      startAt = googleEvent.start?.dateTime?.toLocal() ?? DateTime.now();
      endAt = googleEvent.end?.dateTime?.toLocal() ?? startAt;
    }

    return EventModel(
      id: 'gcal_$googleEventId',
      title: googleEvent.summary ?? '(제목 없음)',
      description: googleEvent.description,
      type: 'general',
      startAt: startAt,
      endAt: endAt,
      isAllDay: isAllDay,
      color: '#4285F4', // Google Blue
      assignedTo: const [],
      reminders: const [],
      createdBy: '',
      createdAt: googleEvent.created?.toLocal() ?? DateTime.now(),
      externalSource: googleCalendarSource,
      externalSourceId: googleEventId,
      externalCalendarId: 'primary',
      externalUpdatedAt: googleEvent.updated?.toLocal(),
    );
  }

  /// EventModel -> Google Calendar Event
  gcal.Event _eventModelToGoogleEvent(EventModel event) {
    final googleEvent = gcal.Event();
    googleEvent.summary = event.title;
    googleEvent.description = event.description;

    if (event.isAllDay) {
      googleEvent.start = gcal.EventDateTime(
        date: DateTime(
            event.startAt.year, event.startAt.month, event.startAt.day),
      );
      googleEvent.end = gcal.EventDateTime(
        date: DateTime(event.endAt.year, event.endAt.month, event.endAt.day)
            .add(const Duration(days: 1)),
      );
    } else {
      googleEvent.start = gcal.EventDateTime(
        dateTime: event.startAt.toUtc(),
        timeZone: 'Asia/Seoul',
      );
      googleEvent.end = gcal.EventDateTime(
        dateTime: event.endAt.toUtc(),
        timeZone: 'Asia/Seoul',
      );
    }

    if (event.reminders.isNotEmpty) {
      googleEvent.reminders = gcal.EventReminders(
        useDefault: false,
        overrides: event.reminders
            .map((m) => gcal.EventReminder(method: 'popup', minutes: m))
            .toList(),
      );
    }

    return googleEvent;
  }
}
