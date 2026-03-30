import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dongine/core/services/mqtt_service.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/features/location/domain/location_provider.dart';
import 'package:dongine/shared/widgets/home_status_model.dart';

void main() {
  // =========================================================================
  // 위치 공유 상태
  // =========================================================================
  group('locationStatus', () {
    test('공유 꺼짐 → 라벨 "위치 공유 꺼짐", ok=false, 힌트 표시', () {
      final item = buildLocationStatus(false, null);
      expect(item.label, '위치 공유 꺼짐');
      expect(item.ok, isFalse);
      expect(item.hint, contains('위치 공유를 켜'));
    });

    test('공유 켜짐 + 스냅샷 없음(로딩 중) → 라벨 "확인 중", ok=false', () {
      final item = buildLocationStatus(true, null);
      expect(item.label, contains('확인 중'));
      expect(item.ok, isFalse);
      expect(item.hint, isNull);
    });

    test('공유 켜짐 + 서비스 꺼짐 → 라벨 "위치 서비스 꺼짐"', () {
      const snap = LocationPermissionSnapshot(
        serviceEnabled: false,
        permission: LocationPermission.always,
      );
      final item = buildLocationStatus(true, snap);
      expect(item.label, '위치 서비스 꺼짐');
      // ok는 권한 기준이므로 always면 true (서비스 꺼짐과 무관)
      expect(item.ok, isTrue);
      expect(item.hint, contains('GPS'));
    });

    test('공유 켜짐 + 서비스 켜짐 + 권한 없음 → 라벨 "위치 권한 없음"', () {
      const snap = LocationPermissionSnapshot(
        serviceEnabled: true,
        permission: LocationPermission.denied,
      );
      final item = buildLocationStatus(true, snap);
      expect(item.label, '위치 권한 없음');
      expect(item.ok, isFalse);
      expect(item.hint, contains('위치 권한을 허용'));
    });

    test('공유 켜짐 + 서비스 켜짐 + whileInUse → ok=true, 힌트 없음', () {
      const snap = LocationPermissionSnapshot(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
      );
      final item = buildLocationStatus(true, snap);
      expect(item.label, '위치 공유 중');
      expect(item.ok, isTrue);
      expect(item.hint, isNull);
    });

    test('공유 켜짐 + 서비스 켜짐 + always → ok=true, 힌트 없음', () {
      const snap = LocationPermissionSnapshot(
        serviceEnabled: true,
        permission: LocationPermission.always,
      );
      final item = buildLocationStatus(true, snap);
      expect(item.label, '위치 공유 중');
      expect(item.ok, isTrue);
      expect(item.hint, isNull);
    });

    test('공유 꺼짐이면 스냅샷 값과 무관하게 동일 결과', () {
      const snap = LocationPermissionSnapshot(
        serviceEnabled: true,
        permission: LocationPermission.always,
      );
      final withSnap = buildLocationStatus(false, snap);
      final withoutSnap = buildLocationStatus(false, null);
      expect(withSnap.label, withoutSnap.label);
      expect(withSnap.ok, withoutSnap.ok);
    });

    test('deniedForever 권한도 ok=false 처리', () {
      const snap = LocationPermissionSnapshot(
        serviceEnabled: true,
        permission: LocationPermission.deniedForever,
      );
      expect(locationStatusOk(true, snap), isFalse);
      expect(locationStatusLabel(true, snap), '위치 권한 없음');
    });
  });

  // =========================================================================
  // Google Calendar 동기화 상태
  // =========================================================================
  group('calendarStatus', () {
    test('sync null → 기록 없음 라벨 + 연동 안내 힌트', () {
      final item = buildCalendarStatus(null);
      expect(item.label, '캘린더 동기화 기록 없음');
      expect(item.ok, isFalse);
      expect(item.hint, contains('Google 캘린더'));
    });

    test('성공 동기화 → 라벨에 타임스탬프 포함, ok=true, 힌트 없음', () {
      final sync = GoogleCalendarSyncUiState(
        completedAt: DateTime(2026, 3, 31, 14, 5),
        success: true,
        message: '10건 동기화',
      );
      final item = buildCalendarStatus(sync);
      expect(item.label, contains('동기화 완료'));
      expect(item.label, contains('3/31'));
      expect(item.label, contains('14:05'));
      expect(item.ok, isTrue);
      expect(item.hint, isNull);
    });

    test('실패 동기화 → 라벨에 "실패" + 타임스탬프, ok=false, 힌트=메시지', () {
      final sync = GoogleCalendarSyncUiState(
        completedAt: DateTime(2026, 1, 2, 9, 0),
        success: false,
        message: '인증 만료',
      );
      final item = buildCalendarStatus(sync);
      expect(item.label, contains('동기화 실패'));
      expect(item.label, contains('1/2'));
      expect(item.label, contains('9:00'));
      expect(item.ok, isFalse);
      expect(item.hint, '인증 만료');
    });

    test('분 한 자리일 때 2자리 패딩', () {
      final sync = GoogleCalendarSyncUiState(
        completedAt: DateTime(2026, 12, 25, 8, 3),
        success: true,
        message: '',
      );
      expect(calendarStatusLabel(sync), contains('8:03'));
    });
  });

  // =========================================================================
  // MQTT / IoT 연결 상태
  // =========================================================================
  group('mqttStatus', () {
    test('브로커 미설정 → 라벨 "IoT 브로커 미설정", ok=false, 힌트 표시', () {
      final item = buildMqttStatus(null, false);
      expect(item.label, 'IoT 브로커 미설정');
      expect(item.ok, isFalse);
      expect(item.hint, contains('MQTT 브로커'));
    });

    test('브로커 미설정이면 status 값과 무관하게 라벨 동일', () {
      for (final s in MqttConnectionStatus.values) {
        final item = buildMqttStatus(s, false);
        expect(item.label, 'IoT 브로커 미설정');
        // ok는 status == connected 여부만 판정 (configured 무관)
        if (s == MqttConnectionStatus.connected) {
          expect(item.ok, isTrue);
        } else {
          expect(item.ok, isFalse);
        }
      }
    });

    test('connected → ok=true, 힌트 없음', () {
      final item = buildMqttStatus(MqttConnectionStatus.connected, true);
      expect(item.label, 'IoT 연결됨');
      expect(item.ok, isTrue);
      expect(item.hint, isNull);
    });

    test('connecting → ok=false, 힌트 없음', () {
      final item = buildMqttStatus(MqttConnectionStatus.connecting, true);
      expect(item.label, contains('연결 중'));
      expect(item.ok, isFalse);
      expect(item.hint, isNull);
    });

    test('reconnecting → ok=false, 힌트 없음', () {
      final item = buildMqttStatus(MqttConnectionStatus.reconnecting, true);
      expect(item.label, contains('재연결'));
      expect(item.ok, isFalse);
      expect(item.hint, isNull);
    });

    test('error → ok=false, 힌트에 설정 확인 안내', () {
      final item = buildMqttStatus(MqttConnectionStatus.error, true);
      expect(item.label, contains('오류'));
      expect(item.ok, isFalse);
      expect(item.hint, contains('브로커 설정'));
    });

    test('disconnected → ok=false, 힌트에 네트워크 확인 안내', () {
      final item = buildMqttStatus(MqttConnectionStatus.disconnected, true);
      expect(item.label, 'IoT 연결 끊김');
      expect(item.ok, isFalse);
      expect(item.hint, contains('네트워크'));
    });

    test('status null + configured → disconnected 처리', () {
      final item = buildMqttStatus(null, true);
      expect(item.label, 'IoT 연결 끊김');
      expect(item.ok, isFalse);
    });
  });

  // =========================================================================
  // StatusItem 통합 검증
  // =========================================================================
  group('StatusItem', () {
    test('모든 상태가 정상일 때 ok=true인 항목 3개', () {
      const snap = LocationPermissionSnapshot(
        serviceEnabled: true,
        permission: LocationPermission.always,
      );
      final loc = buildLocationStatus(true, snap);
      final cal = buildCalendarStatus(GoogleCalendarSyncUiState(
        completedAt: DateTime(2026, 3, 31),
        success: true,
        message: 'ok',
      ));
      final mqtt = buildMqttStatus(MqttConnectionStatus.connected, true);

      expect([loc.ok, cal.ok, mqtt.ok], everyElement(isTrue));
    });

    test('모든 상태가 비정상일 때 ok=false인 항목 3개', () {
      final loc = buildLocationStatus(false, null);
      final cal = buildCalendarStatus(null);
      final mqtt = buildMqttStatus(null, false);

      expect([loc.ok, cal.ok, mqtt.ok], everyElement(isFalse));
    });
  });
}
