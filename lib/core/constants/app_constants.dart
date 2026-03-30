class AppConstants {
  static const String appName = '동이네';
  static const int inviteCodeLength = 6;
  static const int inviteExpirationDays = 7;
  static const int maxFamilyMembers = 20;
  static const int maxFileUploadSizeMB = 100;
  static const int locationUpdateIntervalSeconds = 30;

  /// Naver Map Client ID.
  /// 빌드 시 --dart-define=NAVER_MAP_CLIENT_ID=xxx 로 주입하거나,
  /// 기본값을 아래에서 직접 변경하세요.
  static const String naverMapClientId = String.fromEnvironment(
    'NAVER_MAP_CLIENT_ID',
    defaultValue: 'YOUR_NAVER_MAP_CLIENT_ID',
  );

  /// MQTT Broker URL (IoT 용).
  /// 빌드 시 --dart-define=MQTT_BROKER_URL=xxx 로 주입 가능.
  static const String mqttBrokerUrl = String.fromEnvironment(
    'MQTT_BROKER_URL',
    defaultValue: 'YOUR_MQTT_BROKER_URL',
  );

  /// MQTT Broker Port (IoT 용).
  /// 빌드 시 --dart-define=MQTT_BROKER_PORT=1883 로 주입 가능.
  static const int mqttBrokerPort = int.fromEnvironment(
    'MQTT_BROKER_PORT',
    defaultValue: 1883,
  );

  static const _mqttPlaceholder = 'YOUR_MQTT_BROKER_URL';

  /// MQTT 브로커 URL 이 유효하게 주입되었는지 확인.
  static bool get isMqttBrokerConfigured =>
      mqttBrokerUrl.isNotEmpty && mqttBrokerUrl != _mqttPlaceholder;
}
