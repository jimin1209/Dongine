import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/calendar/data/google_calendar_service.dart';
import 'package:dongine/shared/models/event_model.dart';

/// GoogleCalendarService 싱글톤 제공
final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  return GoogleCalendarService();
});

/// Google Calendar 로그인 상태
final googleCalendarSignedInProvider = StateProvider<bool>((ref) {
  return false;
});

/// 마지막 동기화 시간
final googleCalendarLastSyncProvider = StateProvider<DateTime?>((ref) {
  return null;
});

/// Google Calendar 이벤트 가져오기 (날짜 범위 기반)
final googleCalendarEventsProvider =
    FutureProvider.family<List<EventModel>, ({DateTime start, DateTime end})>(
  (ref, range) async {
    final service = ref.watch(googleCalendarServiceProvider);
    final isSignedIn = ref.watch(googleCalendarSignedInProvider);

    if (!isSignedIn) return [];

    try {
      return await service.getEvents(range.start, range.end);
    } catch (e) {
      return [];
    }
  },
);
