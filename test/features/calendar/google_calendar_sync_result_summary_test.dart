import 'package:dongine/features/calendar/data/google_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoogleCalendarSyncResult.syncSummaryMessage', () {
    test('변경이 없으면 고정 문구를 반환한다', () {
      const r = GoogleCalendarSyncResult(
        createdCount: 0,
        updatedCount: 0,
        removedCount: 0,
        skippedCount: 0,
      );
      expect(r.syncSummaryMessage, '변경된 Google Calendar 이벤트가 없습니다');
    });

    test('카운트 조합을 쉼표로 이어 붙인다', () {
      const r = GoogleCalendarSyncResult(
        createdCount: 2,
        updatedCount: 1,
        removedCount: 3,
        skippedCount: 4,
      );
      expect(
        r.syncSummaryMessage,
        '2개 추가, 1개 갱신, 3개 삭제 반영, 4개 유지',
      );
    });

    test('0인 항목은 문구에서 생략한다', () {
      const onlyCreated = GoogleCalendarSyncResult(
        createdCount: 5,
        updatedCount: 0,
        removedCount: 0,
        skippedCount: 0,
      );
      expect(onlyCreated.syncSummaryMessage, '5개 추가');

      const onlySkipped = GoogleCalendarSyncResult(
        createdCount: 0,
        updatedCount: 0,
        removedCount: 0,
        skippedCount: 1,
      );
      expect(onlySkipped.syncSummaryMessage, '1개 유지');
    });
  });
}
