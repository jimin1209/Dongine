import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/iot/domain/iot_device_helpers.dart';

void main() {
  // ---------------------------------------------------------------------------
  // validateDeviceForm
  // ---------------------------------------------------------------------------
  group('validateDeviceForm', () {
    test('유효한 입력이면 null 반환', () {
      expect(
        validateDeviceForm(name: '거실 조명', mqttTopic: 'home/light'),
        isNull,
      );
    });

    test('이름이 비어 있으면 name_empty', () {
      expect(
        validateDeviceForm(name: '', mqttTopic: 'home/light'),
        'name_empty',
      );
    });

    test('이름이 공백만 있으면 name_empty', () {
      expect(
        validateDeviceForm(name: '   ', mqttTopic: 'home/light'),
        'name_empty',
      );
    });

    test('토픽이 비어 있으면 topic_empty', () {
      expect(
        validateDeviceForm(name: '조명', mqttTopic: ''),
        'topic_empty',
      );
    });

    test('토픽이 공백만 있으면 topic_empty', () {
      expect(
        validateDeviceForm(name: '조명', mqttTopic: '  '),
        'topic_empty',
      );
    });

    test('이름과 토픽 모두 비면 name_empty가 먼저 반환', () {
      expect(
        validateDeviceForm(name: '', mqttTopic: ''),
        'name_empty',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // defaultDeviceState
  // ---------------------------------------------------------------------------
  group('defaultDeviceState', () {
    test('light 기본 상태', () {
      final s = defaultDeviceState('light');
      expect(s, {'on': false, 'brightness': 100});
    });

    test('switch 기본 상태', () {
      expect(defaultDeviceState('switch'), {'on': false});
    });

    test('plug 기본 상태', () {
      expect(defaultDeviceState('plug'), {'on': false});
    });

    test('sensor 기본 상태', () {
      expect(defaultDeviceState('sensor'), {
        'temperature': 0.0,
        'humidity': 0.0,
      });
    });

    test('lock 기본 상태', () {
      expect(defaultDeviceState('lock'), {'locked': true});
    });

    test('thermostat 기본 상태', () {
      expect(defaultDeviceState('thermostat'), {
        'targetTemp': 22.0,
        'currentTemp': 20.0,
      });
    });

    test('camera 기본 상태', () {
      expect(defaultDeviceState('camera'), {'recording': false});
    });

    test('알 수 없는 유형은 빈 맵', () {
      expect(defaultDeviceState('unknown'), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // deviceStateLabel
  // ---------------------------------------------------------------------------
  group('deviceStateLabel', () {
    test('light 켜짐 + 밝기', () {
      expect(
        deviceStateLabel('light', {'on': true, 'brightness': 75}),
        '켜짐 (75%)',
      );
    });

    test('light 꺼짐', () {
      expect(
        deviceStateLabel('light', {'on': false, 'brightness': 50}),
        '꺼짐',
      );
    });

    test('light 밝기 없으면 기본 100%', () {
      expect(
        deviceStateLabel('light', {'on': true}),
        '켜짐 (100%)',
      );
    });

    test('switch 켜짐', () {
      expect(deviceStateLabel('switch', {'on': true}), '켜짐');
    });

    test('plug 꺼짐', () {
      expect(deviceStateLabel('plug', {'on': false}), '꺼짐');
    });

    test('sensor 온도/습도 표시', () {
      expect(
        deviceStateLabel('sensor', {'temperature': 23.5, 'humidity': 60}),
        '23.5C / 60%',
      );
    });

    test('sensor 값 없으면 대시 표시', () {
      expect(deviceStateLabel('sensor', {}), '-C / -%');
    });

    test('lock 잠김', () {
      expect(deviceStateLabel('lock', {'locked': true}), '잠김');
    });

    test('lock 열림', () {
      expect(deviceStateLabel('lock', {'locked': false}), '열림');
    });

    test('thermostat 온도 표시', () {
      expect(
        deviceStateLabel(
            'thermostat', {'currentTemp': 21.0, 'targetTemp': 24.0}),
        '21.0C -> 24.0C',
      );
    });

    test('camera 녹화 중', () {
      expect(
        deviceStateLabel('camera', {'recording': true}),
        '녹화 중',
      );
    });

    test('camera 대기', () {
      expect(
        deviceStateLabel('camera', {'recording': false}),
        '대기',
      );
    });

    test('알 수 없는 유형은 빈 문자열', () {
      expect(deviceStateLabel('unknown', {}), '');
    });
  });

  // ---------------------------------------------------------------------------
  // deleteConfirmationMessage
  // ---------------------------------------------------------------------------
  group('deleteConfirmationMessage', () {
    test('기기 이름이 메시지에 포함됨', () {
      final msg = deleteConfirmationMessage('거실 조명');
      expect(msg, contains('거실 조명'));
      expect(msg, contains('삭제'));
      expect(msg, contains('되돌릴 수 없습니다'));
    });

    test('빈 이름도 정상 동작', () {
      final msg = deleteConfirmationMessage('');
      expect(msg, contains('""'));
    });
  });

  // ---------------------------------------------------------------------------
  // prepareDeviceUpdate
  // ---------------------------------------------------------------------------
  group('prepareDeviceUpdate', () {
    test('앞뒤 공백 제거', () {
      final u = prepareDeviceUpdate(
        name: '  거실 조명  ',
        type: 'light',
        roomName: '  거실  ',
        mqttTopic: '  home/light  ',
      );
      expect(u.name, '거실 조명');
      expect(u.roomName, '거실');
      expect(u.mqttTopic, 'home/light');
    });

    test('빈 방 이름은 null로 변환', () {
      final u = prepareDeviceUpdate(
        name: '센서',
        type: 'sensor',
        roomName: '',
        mqttTopic: 'home/sensor',
      );
      expect(u.roomName, isNull);
    });

    test('공백만 있는 방 이름은 null로 변환', () {
      final u = prepareDeviceUpdate(
        name: '센서',
        type: 'sensor',
        roomName: '   ',
        mqttTopic: 'home/sensor',
      );
      expect(u.roomName, isNull);
    });

    test('유형은 그대로 전달', () {
      final u = prepareDeviceUpdate(
        name: 'cam',
        type: 'camera',
        roomName: '',
        mqttTopic: 'home/cam',
      );
      expect(u.type, 'camera');
    });
  });
}
