// Pure helper functions extracted from IoT screen for testability.
// Covers device-form validation, default-state generation,
// state-label formatting, and delete-confirmation message building.

/// Validates the device edit/add form fields.
/// Returns `null` when valid, or an error key when invalid.
String? validateDeviceForm({
  required String name,
  required String mqttTopic,
}) {
  if (name.trim().isEmpty) return 'name_empty';
  if (mqttTopic.trim().isEmpty) return 'topic_empty';
  return null;
}

/// Returns the default state map for a newly-created device of [type].
Map<String, dynamic> defaultDeviceState(String type) {
  return switch (type) {
    'light' => {'on': false, 'brightness': 100},
    'switch' || 'plug' => {'on': false},
    'sensor' => {'temperature': 0.0, 'humidity': 0.0},
    'lock' => {'locked': true},
    'thermostat' => {'targetTemp': 22.0, 'currentTemp': 20.0},
    'camera' => {'recording': false},
    _ => {},
  };
}

/// Returns a human-readable label describing the current device state.
String deviceStateLabel(String type, Map<String, dynamic> state) {
  return switch (type) {
    'light' => state['on'] == true
        ? '켜짐 (${state['brightness'] ?? 100}%)'
        : '꺼짐',
    'switch' || 'plug' => state['on'] == true ? '켜짐' : '꺼짐',
    'sensor' =>
      '${state['temperature'] ?? '-'}C / ${state['humidity'] ?? '-'}%',
    'lock' => state['locked'] == true ? '잠김' : '열림',
    'thermostat' =>
      '${state['currentTemp'] ?? '-'}C -> ${state['targetTemp'] ?? '-'}C',
    'camera' => state['recording'] == true ? '녹화 중' : '대기',
    _ => '',
  };
}

/// Builds the delete-confirmation message shown to the user.
String deleteConfirmationMessage(String deviceName) {
  return '"$deviceName"을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.';
}

/// Prepares the update payload for [updateDevice] — trims strings and
/// normalises an empty room name to `null`.
({String name, String type, String? roomName, String mqttTopic})
    prepareDeviceUpdate({
  required String name,
  required String type,
  required String roomName,
  required String mqttTopic,
}) {
  final trimmedRoom = roomName.trim();
  return (
    name: name.trim(),
    type: type,
    roomName: trimmedRoom.isEmpty ? null : trimmedRoom,
    mqttTopic: mqttTopic.trim(),
  );
}
