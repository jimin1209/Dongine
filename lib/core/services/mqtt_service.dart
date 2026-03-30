import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttReceivedData {
  final String topic;
  final String payload;

  const MqttReceivedData({required this.topic, required this.payload});
}

class MqttService {
  MqttService._();
  static final MqttService _instance = MqttService._();
  static MqttService get instance => _instance;

  MqttServerClient? _client;
  final StreamController<MqttReceivedData> _messageController =
      StreamController<MqttReceivedData>.broadcast();

  bool _autoReconnect = true;
  String? _broker;
  int? _port;
  String? _clientId;

  Stream<MqttReceivedData> get messageStream => _messageController.stream;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<bool> connect(String broker, int port, String clientId) async {
    _broker = broker;
    _port = port;
    _clientId = clientId;

    _client = MqttServerClient(broker, clientId)
      ..port = port
      ..logging(on: false)
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..onAutoReconnect = _onAutoReconnect
      ..onAutoReconnected = _onAutoReconnected
      ..onDisconnected = _onDisconnected
      ..onConnected = _onConnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      _client?.disconnect();
      return false;
    }

    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      _client?.disconnect();
      return false;
    }

    _client!.updates?.listen(_onMessage);
    return true;
  }

  void disconnect() {
    _autoReconnect = false;
    _client?.disconnect();
    _client = null;
  }

  void subscribe(String topic) {
    if (!isConnected) return;
    _client!.subscribe(topic, MqttQos.atMostOnce);
  }

  void publish(String topic, String message) {
    if (!isConnected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addUTF8String(message);
    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final pubMsg = msg.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        pubMsg.payload.message,
      );
      _messageController.add(
        MqttReceivedData(topic: msg.topic, payload: payload),
      );
    }
  }

  void _onConnected() {
    // 연결 성공
  }

  void _onDisconnected() {
    if (_autoReconnect && _broker != null) {
      _reconnect();
    }
  }

  void _onAutoReconnect() {
    // 자동 재연결 시작
  }

  void _onAutoReconnected() {
    // 자동 재연결 완료
  }

  Future<void> _reconnect() async {
    if (_broker == null || _port == null || _clientId == null) return;
    await Future.delayed(const Duration(seconds: 5));
    if (!isConnected && _autoReconnect) {
      await connect(_broker!, _port!, _clientId!);
    }
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
