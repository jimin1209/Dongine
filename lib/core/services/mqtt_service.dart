import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

enum MqttConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

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

  final StreamController<MqttConnectionStatus> _connectionStatusController =
      StreamController<MqttConnectionStatus>.broadcast();

  bool _autoReconnect = true;
  String? _broker;
  int? _port;
  String? _clientId;
  MqttConnectionStatus _status = MqttConnectionStatus.disconnected;

  Stream<MqttReceivedData> get messageStream => _messageController.stream;
  Stream<MqttConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;
  MqttConnectionStatus get connectionStatus => _status;

  bool get isConnected => _status == MqttConnectionStatus.connected;

  void _setStatus(MqttConnectionStatus status) {
    _status = status;
    _connectionStatusController.add(status);
  }

  Future<bool> connect(String broker, int port, String clientId) async {
    // Guard: 이미 연결 중이거나 재연결 중이면 중복 시도 방지
    if (_status == MqttConnectionStatus.connecting ||
        _status == MqttConnectionStatus.reconnecting) {
      return false;
    }

    // Guard: 이미 연결되어 있으면 무시
    if (_status == MqttConnectionStatus.connected) {
      return true;
    }

    _broker = broker;
    _port = port;
    _clientId = clientId;
    _autoReconnect = true;

    _setStatus(MqttConnectionStatus.connecting);

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
      _setStatus(MqttConnectionStatus.error);
      return false;
    }

    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      _client?.disconnect();
      _setStatus(MqttConnectionStatus.error);
      return false;
    }

    _client!.updates?.listen(_onMessage);
    return true;
  }

  void disconnect() {
    _autoReconnect = false;
    _client?.disconnect();
    _client = null;
    _setStatus(MqttConnectionStatus.disconnected);
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
    _setStatus(MqttConnectionStatus.connected);
  }

  void _onDisconnected() {
    if (_autoReconnect && _broker != null) {
      // autoReconnect가 켜져 있으므로 mqtt_client가 자동 재연결을 시도함
      // 여기서는 수동 _reconnect 대신 상태만 업데이트
      if (_status != MqttConnectionStatus.reconnecting) {
        _setStatus(MqttConnectionStatus.disconnected);
      }
    } else {
      _setStatus(MqttConnectionStatus.disconnected);
    }
  }

  void _onAutoReconnect() {
    _setStatus(MqttConnectionStatus.reconnecting);
  }

  void _onAutoReconnected() {
    _setStatus(MqttConnectionStatus.connected);
  }

  /// 수동 재연결 시도
  Future<bool> reconnect() async {
    if (_broker == null || _port == null || _clientId == null) return false;
    if (_status == MqttConnectionStatus.connecting ||
        _status == MqttConnectionStatus.reconnecting) {
      return false;
    }
    _setStatus(MqttConnectionStatus.reconnecting);
    _client?.disconnect();
    _client = null;
    _status = MqttConnectionStatus.disconnected; // connect() 가드 통과용
    return connect(_broker!, _port!, _clientId!);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStatusController.close();
  }
}
