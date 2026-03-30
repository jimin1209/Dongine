import 'package:dongine/core/services/mqtt_service.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/features/location/domain/location_provider.dart';

/// 개별 상태 항목.
class StatusItem {
  const StatusItem({required this.label, required this.ok, this.hint});

  final String label;
  final bool ok;
  final String? hint;
}

// ---------------------------------------------------------------------------
// 위치 공유 상태
// ---------------------------------------------------------------------------

/// 위치 공유 상태 라벨을 반환하는 순수 함수.
///
/// [sharing] – 사용자가 위치 공유를 켰는지 여부
/// [snapshot] – 위치 권한/서비스 스냅샷 (아직 로딩 중이면 null)
String locationStatusLabel(bool sharing, LocationPermissionSnapshot? snapshot) {
  if (!sharing) return '위치 공유 꺼짐';
  if (snapshot == null) return '위치 권한 확인 중…';
  if (!snapshot.serviceEnabled) return '위치 서비스 꺼짐';
  if (!snapshot.hasUsablePermission) return '위치 권한 없음';
  return '위치 공유 중';
}

/// 위치 공유 상태 힌트를 반환하는 순수 함수.
String? locationStatusHint(bool sharing, LocationPermissionSnapshot? snapshot) {
  if (!sharing) return '설정에서 위치 공유를 켜 주세요.';
  if (snapshot == null) return null;
  if (!snapshot.serviceEnabled) return '기기 설정에서 위치(GPS)를 켜 주세요.';
  if (!snapshot.hasUsablePermission) return '앱 설정에서 위치 권한을 허용해 주세요.';
  return null;
}

/// 위치 공유 OK 여부를 반환하는 순수 함수.
bool locationStatusOk(bool sharing, LocationPermissionSnapshot? snapshot) {
  return sharing && (snapshot?.hasUsablePermission ?? false);
}

/// 위치 상태를 하나의 [StatusItem]으로 조합.
StatusItem buildLocationStatus(
    bool sharing, LocationPermissionSnapshot? snapshot) {
  return StatusItem(
    label: locationStatusLabel(sharing, snapshot),
    ok: locationStatusOk(sharing, snapshot),
    hint: locationStatusHint(sharing, snapshot),
  );
}

// ---------------------------------------------------------------------------
// Google Calendar 동기화 상태
// ---------------------------------------------------------------------------

/// 캘린더 동기화 라벨을 반환하는 순수 함수.
String calendarStatusLabel(GoogleCalendarSyncUiState? sync) {
  if (sync == null) return '캘린더 동기화 기록 없음';
  final t = sync.completedAt;
  final ts =
      '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  if (sync.success) return '캘린더 동기화 완료 ($ts)';
  return '캘린더 동기화 실패 ($ts)';
}

/// 캘린더 동기화 힌트를 반환하는 순수 함수.
String? calendarStatusHint(GoogleCalendarSyncUiState? sync) {
  if (sync == null) return 'Google 캘린더를 연동하면 일정을 자동으로 가져옵니다.';
  if (!sync.success) return sync.message;
  return null;
}

/// 캘린더 동기화 OK 여부.
bool calendarStatusOk(GoogleCalendarSyncUiState? sync) {
  return sync?.success ?? false;
}

/// 캘린더 상태를 하나의 [StatusItem]으로 조합.
StatusItem buildCalendarStatus(GoogleCalendarSyncUiState? sync) {
  return StatusItem(
    label: calendarStatusLabel(sync),
    ok: calendarStatusOk(sync),
    hint: calendarStatusHint(sync),
  );
}

// ---------------------------------------------------------------------------
// MQTT / IoT 연결 상태
// ---------------------------------------------------------------------------

/// MQTT 연결 라벨을 반환하는 순수 함수.
String mqttStatusLabel(MqttConnectionStatus? status, bool configured) {
  if (!configured) return 'IoT 브로커 미설정';
  return switch (status) {
    MqttConnectionStatus.connected => 'IoT 연결됨',
    MqttConnectionStatus.connecting => 'IoT 연결 중…',
    MqttConnectionStatus.reconnecting => 'IoT 재연결 중…',
    MqttConnectionStatus.error => 'IoT 연결 오류',
    MqttConnectionStatus.disconnected || null => 'IoT 연결 끊김',
  };
}

/// MQTT 연결 힌트를 반환하는 순수 함수.
String? mqttStatusHint(MqttConnectionStatus? status, bool configured) {
  if (!configured) return 'MQTT 브로커 주소를 설정해 주세요.';
  return switch (status) {
    MqttConnectionStatus.connected => null,
    MqttConnectionStatus.error => '브로커 설정을 확인하거나 잠시 후 다시 시도해 주세요.',
    MqttConnectionStatus.disconnected => '네트워크 연결을 확인해 주세요.',
    _ => null,
  };
}

/// MQTT 연결 OK 여부.
bool mqttStatusOk(MqttConnectionStatus? status, bool configured) {
  return status == MqttConnectionStatus.connected;
}

/// MQTT 상태를 하나의 [StatusItem]으로 조합.
StatusItem buildMqttStatus(MqttConnectionStatus? status, bool configured) {
  return StatusItem(
    label: mqttStatusLabel(status, configured),
    ok: mqttStatusOk(status, configured),
    hint: mqttStatusHint(status, configured),
  );
}
