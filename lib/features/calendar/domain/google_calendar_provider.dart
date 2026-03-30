import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/calendar/data/google_calendar_service.dart';
import 'package:dongine/features/calendar/data/google_calendar_sync_preferences.dart';
import 'package:dongine/shared/models/event_model.dart';

/// GoogleCalendarService 싱글톤 제공
final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  return GoogleCalendarService();
});

/// Google Calendar 동기화 결과 로컬 저장
final googleCalendarSyncPreferencesProvider =
    Provider<GoogleCalendarSyncPreferences>((ref) {
  return GoogleCalendarSyncPreferences();
});

/// Google Calendar 로그인 상태
final googleCalendarSignedInProvider = StateProvider<bool>((ref) {
  return false;
});

/// 마지막 동기화 시각·성공 여부·요약 (앱 재시작 후 `loadFromStorage`로 복원)
class GoogleCalendarSyncUiState {
  final DateTime completedAt;
  final bool success;
  final String message;

  const GoogleCalendarSyncUiState({
    required this.completedAt,
    required this.success,
    required this.message,
  });
}

class GoogleCalendarSyncUiNotifier
    extends StateNotifier<GoogleCalendarSyncUiState?> {
  GoogleCalendarSyncUiNotifier(this._prefs) : super(null);

  final GoogleCalendarSyncPreferences _prefs;

  Future<void> loadFromStorage() async {
    final loaded = await _prefs.load();
    if (loaded == null) {
      state = null;
      return;
    }
    state = GoogleCalendarSyncUiState(
      completedAt: loaded.completedAt,
      success: loaded.success,
      message: loaded.message,
    );
  }

  Future<void> recordSuccess(DateTime completedAt, String message) async {
    await _prefs.save(
      completedAt: completedAt,
      success: true,
      message: message,
    );
    state = GoogleCalendarSyncUiState(
      completedAt: completedAt,
      success: true,
      message: message,
    );
  }

  Future<void> recordFailure(DateTime completedAt, String message) async {
    await _prefs.save(
      completedAt: completedAt,
      success: false,
      message: message,
    );
    state = GoogleCalendarSyncUiState(
      completedAt: completedAt,
      success: false,
      message: message,
    );
  }

  Future<void> clear() async {
    await _prefs.clear();
    state = null;
  }
}

final googleCalendarSyncUiProvider =
    StateNotifierProvider<GoogleCalendarSyncUiNotifier, GoogleCalendarSyncUiState?>(
  (ref) => GoogleCalendarSyncUiNotifier(
    ref.watch(googleCalendarSyncPreferencesProvider),
  ),
);

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
