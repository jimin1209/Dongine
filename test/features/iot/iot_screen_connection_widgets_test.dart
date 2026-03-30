import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/core/services/mqtt_service.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/iot/data/iot_repository.dart';
import 'package:dongine/features/iot/domain/iot_provider.dart';
import 'package:dongine/features/iot/presentation/iot_screen.dart';
import 'package:dongine/shared/models/automation_model.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/iot_device_model.dart';

const _familyId = 'fam-iot-test';

final _testFamily = FamilyModel(
  id: _familyId,
  name: 'IoT 테스트 가족',
  createdBy: 'uid-1',
  inviteCode: 'ABCDEF',
  createdAt: DateTime(2026, 1, 1),
);

final _testSwitchDevice = IoTDeviceModel(
  id: 'dev-switch-1',
  name: '거실 스위치',
  type: 'switch',
  status: 'online',
  state: const {'on': false},
  familyId: _familyId,
  mqttTopic: 'home/living/switch',
  lastSeen: DateTime(2026, 3, 1),
  addedBy: 'uid-1',
  createdAt: DateTime(2026, 3, 1),
);

/// Firebase를 쓰지 않고 [IoTRepository] 계약만 만족시키는 테스트 더블.
class _FakeIoTRepository implements IoTRepository {
  int updateDeviceStateCallCount = 0;
  int controlDeviceCallCount = 0;

  @override
  Future<void> addDevice(String familyId, IoTDeviceModel device) async {}

  @override
  Future<void> createAutomation(
    String familyId,
    AutomationModel automation,
  ) async {}

  @override
  void controlDevice(
    MqttService mqtt,
    String topic,
    Map<String, dynamic> command,
  ) {
    controlDeviceCallCount++;
  }

  @override
  Future<void> deleteAutomation(String familyId, String automationId) async {}

  @override
  Stream<List<IoTDeviceModel>> getDevicesStream(String familyId) {
    return Stream.value(const <IoTDeviceModel>[]);
  }

  @override
  Stream<List<AutomationModel>> getAutomationsStream(String familyId) {
    return Stream.value(const <AutomationModel>[]);
  }

  @override
  Future<void> removeDevice(String familyId, String deviceId) async {}

  @override
  Future<void> toggleAutomation(
    String familyId,
    String automationId,
    bool enabled,
  ) async {}

  @override
  Future<void> updateDevice(
    String familyId,
    String deviceId, {
    required String name,
    required String type,
    String? roomName,
    required String mqttTopic,
  }) async {}

  @override
  Future<void> updateDeviceState(
    String familyId,
    String deviceId,
    Map<String, dynamic> state,
  ) async {
    updateDeviceStateCallCount++;
  }
}

List<Override> _baseOverrides({
  required Stream<MqttConnectionStatus> mqttStatusStream,
  required bool brokerConfigured,
  required IoTRepository iotRepo,
  MqttService? mqttService,
}) {
  return [
    currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
    mqttBrokerConfiguredProvider.overrideWith((ref) => brokerConfigured),
    mqttConnectionStatusProvider.overrideWith((ref) => mqttStatusStream),
    devicesProvider(_familyId)
        .overrideWith((ref) => Stream.value([_testSwitchDevice])),
    automationsProvider(_familyId)
        .overrideWith((ref) => Stream.value(const <AutomationModel>[])),
    iotRepositoryProvider.overrideWithValue(iotRepo),
    if (mqttService != null)
      mqttServiceProvider.overrideWithValue(mqttService),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IoT MQTT 배지·배너 (브로커 미설정)', () {
    testWidgets('미설정 시 배지 툴팁과 안내 배너가 보인다', (tester) async {
      final fakeRepo = _FakeIoTRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            mqttStatusStream: Stream.value(MqttConnectionStatus.disconnected),
            brokerConfigured: false,
            iotRepo: fakeRepo,
          ),
          child: const MaterialApp(home: IoTScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('MQTT: 미설정'), findsOneWidget);
      expect(
        find.textContaining('MQTT 브로커가 설정되지 않았습니다'),
        findsOneWidget,
      );
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.text('재연결'), findsNothing);
    });
  });

  group('IoT MQTT 배지·배너 (브로커 설정됨)', () {
    testWidgets('연결됨: 상단 배너 없음, 배지는 연결됨 툴팁', (tester) async {
      final fakeRepo = _FakeIoTRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            mqttStatusStream: Stream.value(MqttConnectionStatus.connected),
            brokerConfigured: true,
            iotRepo: fakeRepo,
          ),
          child: const MaterialApp(home: IoTScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('MQTT: 연결됨'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.textContaining('MQTT 서버에 연결되지 않았습니다'), findsNothing);
      expect(find.textContaining('MQTT 연결 오류'), findsNothing);
      expect(find.text('재연결'), findsNothing);
    });

    testWidgets('연결 끊김: 경고 배너와 재연결 버튼', (tester) async {
      final fakeRepo = _FakeIoTRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            mqttStatusStream: Stream.value(MqttConnectionStatus.disconnected),
            brokerConfigured: true,
            iotRepo: fakeRepo,
          ),
          child: const MaterialApp(home: IoTScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('MQTT: 연결 끊김'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.textContaining('MQTT 서버에 연결되지 않았습니다'), findsOneWidget);
      expect(find.text('재연결'), findsOneWidget);
    });

    testWidgets('연결 오류: 재연결 버튼 표시', (tester) async {
      final fakeRepo = _FakeIoTRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            mqttStatusStream: Stream.value(MqttConnectionStatus.error),
            brokerConfigured: true,
            iotRepo: fakeRepo,
          ),
          child: const MaterialApp(home: IoTScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('MQTT: 연결 오류'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.textContaining('MQTT 연결 오류가 발생했습니다'), findsOneWidget);
      expect(find.text('재연결'), findsOneWidget);
    });

    testWidgets('연결 중: 재연결 버튼 숨김, 안내 문구', (tester) async {
      final fakeRepo = _FakeIoTRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            mqttStatusStream: Stream.value(MqttConnectionStatus.connecting),
            brokerConfigured: true,
            iotRepo: fakeRepo,
          ),
          child: const MaterialApp(home: IoTScreen()),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('MQTT: 연결 중...'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.textContaining('MQTT 서버에 연결하는 중'), findsOneWidget);
      expect(find.text('재연결'), findsNothing);
    });

    testWidgets('재연결 중: 재연결 버튼 숨김', (tester) async {
      final fakeRepo = _FakeIoTRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            mqttStatusStream: Stream.value(MqttConnectionStatus.reconnecting),
            brokerConfigured: true,
            iotRepo: fakeRepo,
          ),
          child: const MaterialApp(home: IoTScreen()),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('MQTT: 재연결 중...'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.textContaining('MQTT 서버에 재연결하는 중'), findsOneWidget);
      expect(find.text('재연결'), findsNothing);
    });

    testWidgets('재연결 버튼 탭 시 mqtt.reconnect 호출', (tester) async {
      final fakeRepo = _FakeIoTRepository();
      final mqttDouble = MqttServiceTestDouble();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            mqttStatusStream: Stream.value(MqttConnectionStatus.disconnected),
            brokerConfigured: true,
            iotRepo: fakeRepo,
            mqttService: mqttDouble,
          ),
          child: const MaterialApp(home: IoTScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('재연결'));
      await tester.pump();

      expect(mqttDouble.reconnectCallCount, 1);
    });
  });

  group('IoT 미연결 시 제어 보호', () {
    testWidgets(
      '연결됨: 토글 시 저장소 갱신과 MQTT 제어 경로(controlDevice)가 호출된다',
      (tester) async {
        final fakeRepo = _FakeIoTRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: _baseOverrides(
              mqttStatusStream:
                  Stream.value(MqttConnectionStatus.connected),
              brokerConfigured: true,
              iotRepo: fakeRepo,
            ),
            child: const MaterialApp(home: IoTScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('거실 스위치'));
        await tester.pumpAndSettle();

        expect(find.textContaining('MQTT 미연결'), findsNothing);

        final switchTile = find.byType(SwitchListTile);
        expect(switchTile, findsOneWidget);
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        expect(fakeRepo.updateDeviceStateCallCount, greaterThan(0));
        expect(fakeRepo.controlDeviceCallCount, greaterThan(0));
        expect(
          find.textContaining('MQTT 연결이 끊겨 기기에 명령을 보내지 못했습니다'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'MQTT 미연결 상태에서 토글 시 Firestore 갱신은 하되 MQTT 제어는 하지 않고 '
      '스낵바를 띄운다',
      (tester) async {
        final fakeRepo = _FakeIoTRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: _baseOverrides(
              mqttStatusStream:
                  Stream.value(MqttConnectionStatus.disconnected),
              brokerConfigured: true,
              iotRepo: fakeRepo,
            ),
            child: const MaterialApp(home: IoTScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('거실 스위치'));
        await tester.pumpAndSettle();

        expect(find.textContaining('MQTT 미연결'), findsOneWidget);

        final switchTile = find.byType(SwitchListTile);
        expect(switchTile, findsOneWidget);
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        expect(fakeRepo.updateDeviceStateCallCount, greaterThan(0));
        expect(fakeRepo.controlDeviceCallCount, 0);
        expect(
          find.textContaining('MQTT 연결이 끊겨 기기에 명령을 보내지 못했습니다'),
          findsOneWidget,
        );
      },
    );
  });
}
