import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/core/services/mqtt_service.dart';
import 'package:dongine/features/iot/data/iot_repository.dart';
import 'package:dongine/shared/models/automation_model.dart';
import 'package:dongine/shared/models/iot_device_model.dart';

final mqttServiceProvider = Provider<MqttService>((ref) {
  return MqttService.instance;
});

final iotRepositoryProvider = Provider<IoTRepository>((ref) {
  return IoTRepository();
});

final devicesProvider =
    StreamProvider.family<List<IoTDeviceModel>, String>((ref, familyId) {
  final repo = ref.watch(iotRepositoryProvider);
  return repo.getDevicesStream(familyId);
});

final automationsProvider =
    StreamProvider.family<List<AutomationModel>, String>((ref, familyId) {
  final repo = ref.watch(iotRepositoryProvider);
  return repo.getAutomationsStream(familyId);
});

final mqttConnectionStatusProvider =
    StreamProvider<MqttConnectionStatus>((ref) {
  final mqtt = ref.watch(mqttServiceProvider);
  return mqtt.connectionStatusStream;
});

/// 현재 MQTT 연결 상태의 동기 접근용 (초기값: disconnected)
final mqttConnectedProvider = Provider<bool>((ref) {
  final status = ref.watch(mqttConnectionStatusProvider);
  return status.valueOrNull == MqttConnectionStatus.connected;
});
