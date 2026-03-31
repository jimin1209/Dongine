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

/// Google Calendar 연결 상태 (세부 실패 사유 포함).
enum GoogleCalendarConnectionStatus {
  /// 아직 로그인 시도 전이거나 로그아웃된 상태.
  disconnected,

  /// 정상 연결됨.
  connected,

  /// 사용자가 로그인 팝업을 취소.
  cancelledByUser,

  /// OAuth 클라이언트 ID 등 플랫폼 설정 누락.
  missingConfig,

  /// 네트워크·서버 등 기타 오류.
  error,
}

/// Google Calendar 로그인 상태
final googleCalendarSignedInProvider = StateProvider<bool>((ref) {
  return false;
});

/// Google Calendar 연결 상세 상태 (UI 에서 실패 사유를 표시할 때 사용).
final googleCalendarConnectionStatusProvider =
    StateProvider<GoogleCalendarConnectionStatus>((ref) {
  return GoogleCalendarConnectionStatus.disconnected;
});

/// 연결 실패 시 원본 에러 메시지 (설정 누락·일반 오류 등).
final googleCalendarConnectionErrorProvider = StateProvider<String?>((ref) {
  return null;
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
  bool _didHydrateFromStorage = false;

  Future<void> loadFromStorage() async {
    if (_didHydrateFromStorage) return;

    final loaded = await _prefs.load();
    _didHydrateFromStorage = true;

    if (loaded == null) {
      // 늦게 끝난 초기 로드가 방금 기록한 동기화 결과를 지우지 않도록 보호한다.
      if (state == null) {
        state = null;
      }
      return;
    }

    final restoredState = GoogleCalendarSyncUiState(
      completedAt: loaded.completedAt,
      success: loaded.success,
      message: loaded.message,
    );

    final currentState = state;
    if (currentState == null ||
        currentState.completedAt.isBefore(restoredState.completedAt)) {
      state = restoredState;
    }
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
