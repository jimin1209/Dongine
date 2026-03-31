import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/iot/domain/iot_device_helpers.dart';

/// `iot_device_helpers.dart` 전용 회귀 스위트.
/// 문구·정규화 규칙이 바뀌면 의도적으로 스냅을 갱신해야 한다.
void main() {
  group('validateDeviceForm (회귀)', () {
    test('이름·토픽에 앞뒤 공백만 있어도 내용이 있으면 유효', () {
      expect(
        validateDeviceForm(name: '  조명  ', mqttTopic: '  home/t  '),
        isNull,
      );
    });
  });

  group('deviceStateLabel (회귀)', () {
    test('thermostat 키 누락 시 대시', () {
      expect(
        deviceStateLabel('thermostat', {}),
        '-C -> -C',
      );
    });

    test('light 켜짐이고 밝기 0이면 0% 표시', () {
      expect(
        deviceStateLabel('light', {'on': true, 'brightness': 0}),
        '켜짐 (0%)',
      );
    });

    test('switch/plug on이 true가 아니면 꺼짐', () {
      expect(deviceStateLabel('switch', {'on': null}), '꺼짐');
      expect(deviceStateLabel('plug', {}), '꺼짐');
    });

    test('lock locked가 true가 아니면 열림', () {
      expect(deviceStateLabel('lock', {'locked': null}), '열림');
    });

    test('camera recording이 true가 아니면 대기', () {
      expect(deviceStateLabel('camera', {}), '대기');
    });
  });

  group('deleteConfirmationMessage (회귀)', () {
    test('문구 전체가 고정되어야 한다', () {
      expect(
        deleteConfirmationMessage('거실 조명'),
        '"거실 조명"을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
      );
    });

    test('빈 이름도 동일한 틀을 유지한다', () {
      expect(
        deleteConfirmationMessage(''),
        '""을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
      );
    });
  });

  group('prepareDeviceUpdate (회귀)', () {
    test('mqttTopic도 trim 적용 (빈 문자열 유지)', () {
      final u = prepareDeviceUpdate(
        name: 'a',
        type: 'light',
        roomName: '',
        mqttTopic: '',
      );
      expect(u.mqttTopic, '');
      expect(u.roomName, isNull);
    });

    test('방 이름이 탭·개행만이면 null', () {
      final u = prepareDeviceUpdate(
        name: 'x',
        type: 'switch',
        roomName: '\t\n  \t',
        mqttTopic: 't',
      );
      expect(u.roomName, isNull);
    });

    test('이름 trim 후 type은 비트림 그대로', () {
      final u = prepareDeviceUpdate(
        name: '  n  ',
        type: '  light  ',
        roomName: 'r',
        mqttTopic: 'z',
      );
      expect(u.name, 'n');
      expect(u.type, '  light  ');
    });
  });
}
