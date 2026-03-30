import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/shared/models/event_model.dart';

void main() {
  test('외부 동기화 메타데이터가 Firestore 맵에 포함된다', () {
    final event = EventModel(
      id: 'event-1',
      title: '가족 외식',
      startAt: DateTime(2026, 4, 1, 18),
      endAt: DateTime(2026, 4, 1, 20),
      createdBy: 'user-1',
      createdAt: DateTime(2026, 3, 30),
      externalSource: 'google_calendar',
      externalSourceId: 'google-event-1',
      externalCalendarId: 'primary',
      externalUpdatedAt: DateTime(2026, 3, 30, 12),
    );

    final map = event.toFirestore();

    expect(map['externalSource'], 'google_calendar');
    expect(map['externalSourceId'], 'google-event-1');
    expect(map['externalCalendarId'], 'primary');
    expect(map['externalUpdatedAt'], isNotNull);
  });

  test('copyWith로 외부 메타데이터를 갱신할 수 있다', () {
    final event = EventModel(
      id: 'event-1',
      title: '회의',
      startAt: DateTime(2026, 4, 2, 10),
      endAt: DateTime(2026, 4, 2, 11),
      createdBy: 'user-1',
      createdAt: DateTime(2026, 3, 30),
    );

    final synced = event.copyWith(
      externalSource: 'google_calendar',
      externalSourceId: 'google-event-2',
    );

    expect(synced.externalSource, 'google_calendar');
    expect(synced.externalSourceId, 'google-event-2');
    expect(synced.id, event.id);
  });
}
