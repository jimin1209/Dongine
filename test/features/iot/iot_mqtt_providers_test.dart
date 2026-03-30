import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dongine/core/services/mqtt_service.dart';
import 'package:dongine/features/iot/domain/iot_provider.dart';

void main() {
  group('mqttConnectedProvider', () {
    test('connected 스트림이면 true', () async {
      final container = ProviderContainer(
        overrides: [
          mqttConnectionStatusProvider.overrideWith(
            (ref) => Stream.value(MqttConnectionStatus.connected),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mqttConnectionStatusProvider.future);
      expect(container.read(mqttConnectedProvider), isTrue);
    });

    test('disconnected 스트림이면 false', () async {
      final container = ProviderContainer(
        overrides: [
          mqttConnectionStatusProvider.overrideWith(
            (ref) => Stream.value(MqttConnectionStatus.disconnected),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mqttConnectionStatusProvider.future);
      expect(container.read(mqttConnectedProvider), isFalse);
    });

    test('connecting 스트림이면 false', () async {
      final container = ProviderContainer(
        overrides: [
          mqttConnectionStatusProvider.overrideWith(
            (ref) => Stream.value(MqttConnectionStatus.connecting),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mqttConnectionStatusProvider.future);
      expect(container.read(mqttConnectedProvider), isFalse);
    });

    test('reconnecting 스트림이면 false', () async {
      final container = ProviderContainer(
        overrides: [
          mqttConnectionStatusProvider.overrideWith(
            (ref) => Stream.value(MqttConnectionStatus.reconnecting),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mqttConnectionStatusProvider.future);
      expect(container.read(mqttConnectedProvider), isFalse);
    });

    test('error 스트림이면 false', () async {
      final container = ProviderContainer(
        overrides: [
          mqttConnectionStatusProvider.overrideWith(
            (ref) => Stream.value(MqttConnectionStatus.error),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mqttConnectionStatusProvider.future);
      expect(container.read(mqttConnectedProvider), isFalse);
    });
  });
}
