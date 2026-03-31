import 'package:dongine/features/calendar/data/calendar_repository.dart';
import 'package:dongine/features/calendar/data/google_calendar_service.dart';
import 'package:dongine/shared/models/event_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('googleSyncShouldOverwriteExternalEvent', () {
    test('기존 문서가 없으면 항상 덮어쓴다', () {
      final incoming = _incoming(updatedAt: DateTime(2026, 1, 2));
      expect(googleSyncShouldOverwriteExternalEvent(null, incoming), isTrue);
    });

    test('한쪽 externalUpdatedAt 이 null 이면 덮어쓴다', () {
      final existing = _existing(updatedAt: DateTime(2026, 1, 3));
      final incomingNoTs = _incoming(updatedAt: null);
      expect(
        googleSyncShouldOverwriteExternalEvent(existing, incomingNoTs),
        isTrue,
      );

      final existingNoTs = _existing(updatedAt: null);
      final incoming = _incoming(updatedAt: DateTime(2026, 1, 2));
      expect(
        googleSyncShouldOverwriteExternalEvent(existingNoTs, incoming),
        isTrue,
      );
    });

    test('수신 쪽이 더 최신이면 덮어쓴다', () {
      final existing = _existing(updatedAt: DateTime(2026, 1, 1, 12));
      final incoming = _incoming(updatedAt: DateTime(2026, 1, 2, 12));
      expect(
        googleSyncShouldOverwriteExternalEvent(existing, incoming),
        isTrue,
      );
    });

    test('수신 쪽이 더 오래되었으면 건너뛴다', () {
      final existing = _existing(updatedAt: DateTime(2026, 1, 3, 12));
      final incoming = _incoming(updatedAt: DateTime(2026, 1, 2, 12));
      expect(
        googleSyncShouldOverwriteExternalEvent(existing, incoming),
        isFalse,
      );
    });

    test('같은 시각이면 덮어쓴다 (!isBefore)', () {
      final t = DateTime(2026, 1, 2, 12);
      final existing = _existing(updatedAt: t);
      final incoming = _incoming(updatedAt: t);
      expect(googleSyncShouldOverwriteExternalEvent(existing, incoming), isTrue);
    });
  });

  group('googleSyncShouldDeleteLocalEventMissingFromRemote', () {
    test('externalSourceId 가 null 이면 삭제하지 않는다', () {
      expect(
        googleSyncShouldDeleteLocalEventMissingFromRemote(
          externalSourceId: null,
          remoteGoogleEventIds: {'a'},
        ),
        isFalse,
      );
    });

    test('원격 집합에 ID 가 있으면 삭제하지 않는다', () {
      expect(
        googleSyncShouldDeleteLocalEventMissingFromRemote(
          externalSourceId: 'gid-1',
          remoteGoogleEventIds: {'gid-1', 'gid-2'},
        ),
        isFalse,
      );
    });

    test('원격에 없는 google 연동 일정은 동기화 후 로컬에서 제거한다', () {
      expect(
        googleSyncShouldDeleteLocalEventMissingFromRemote(
          externalSourceId: 'stale-id',
          remoteGoogleEventIds: {'other'},
        ),
        isTrue,
      );
    });
  });

  group('GoogleCalendarService.exportShouldPatchExisting', () {
    test('google_calendar 출처이고 externalSourceId 가 있으면 update 경로', () {
      final event = _baseEvent().copyWith(
        externalSource: GoogleCalendarService.googleCalendarSource,
        externalSourceId: 'g-1',
      );
      expect(GoogleCalendarService.exportShouldPatchExisting(event), isTrue);
    });

    test('다른 externalSource 이면 create 경로', () {
      final event = _baseEvent().copyWith(
        externalSource: 'other',
        externalSourceId: 'x',
      );
      expect(GoogleCalendarService.exportShouldPatchExisting(event), isFalse);
    });

    test('google_calendar 이어도 ID 가 없으면 create 경로', () {
      final event = _baseEvent().copyWith(
        externalSource: GoogleCalendarService.googleCalendarSource,
        externalSourceId: null,
      );
      expect(GoogleCalendarService.exportShouldPatchExisting(event), isFalse);
    });
  });

  group('calendarDeleteShouldInvokeGoogle', () {
    test('exported 이고 externalSourceId 가 있으면 Google 삭제 호출 대상', () {
      final event = _baseEvent().copyWith(
        googleSyncDirection: 'exported',
        externalSourceId: 'g-del',
      );
      expect(calendarDeleteShouldInvokeGoogle(event), isTrue);
    });

    test('imported 일정은 Google 삭제를 호출하지 않는다', () {
      final event = _baseEvent().copyWith(
        googleSyncDirection: 'imported',
        externalSource: GoogleCalendarService.googleCalendarSource,
        externalSourceId: 'g-imp',
      );
      expect(calendarDeleteShouldInvokeGoogle(event), isFalse);
    });

    test('exported 여도 externalSourceId 가 없으면 Google 삭제 없음', () {
      final event = _baseEvent().copyWith(
        googleSyncDirection: 'exported',
        externalSourceId: null,
      );
      expect(calendarDeleteShouldInvokeGoogle(event), isFalse);
    });

    test('로컬 일정(연동 없음)은 Google 삭제 없음', () {
      final event = _baseEvent();
      expect(calendarDeleteShouldInvokeGoogle(event), isFalse);
    });
  });
}

EventModel _baseEvent() {
  return EventModel(
    id: 'e1',
    title: 't',
    startAt: DateTime(2026, 4, 1),
    endAt: DateTime(2026, 4, 1, 1),
    createdBy: 'u',
    createdAt: DateTime(2026, 3, 1),
  );
}

EventModel _existing({required DateTime? updatedAt}) {
  return _baseEvent().copyWith(
    id: 'existing',
    externalUpdatedAt: updatedAt,
    externalSourceId: 'same-gid',
  );
}

EventModel _incoming({required DateTime? updatedAt}) {
  return _baseEvent().copyWith(
    id: 'gcal_same-gid',
    externalUpdatedAt: updatedAt,
    externalSourceId: 'same-gid',
    externalSource: GoogleCalendarService.googleCalendarSource,
    googleSyncDirection: 'imported',
  );
}
