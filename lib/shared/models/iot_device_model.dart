import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class IoTDeviceModel {
  final String id;
  final String name;
  final String type;
  final String status;
  final Map<String, dynamic> state;
  final String familyId;
  final String? roomName;
  final String mqttTopic;
  final DateTime lastSeen;
  final String addedBy;
  final DateTime createdAt;

  const IoTDeviceModel({
    required this.id,
    required this.name,
    required this.type,
    this.status = 'offline',
    this.state = const {},
    required this.familyId,
    this.roomName,
    required this.mqttTopic,
    required this.lastSeen,
    required this.addedBy,
    required this.createdAt,
  });

  factory IoTDeviceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IoTDeviceModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? 'sensor',
      status: data['status'] ?? 'offline',
      state: Map<String, dynamic>.from(data['state'] ?? {}),
      familyId: data['familyId'] ?? '',
      roomName: data['roomName'],
      mqttTopic: data['mqttTopic'] ?? '',
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      addedBy: data['addedBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'status': status,
      'state': state,
      'familyId': familyId,
      'roomName': roomName,
      'mqttTopic': mqttTopic,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'addedBy': addedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  IoTDeviceModel copyWith({
    String? id,
    String? name,
    String? type,
    String? status,
    Map<String, dynamic>? state,
    String? familyId,
    String? roomName,
    String? mqttTopic,
    DateTime? lastSeen,
    String? addedBy,
    DateTime? createdAt,
  }) {
    return IoTDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      state: state ?? this.state,
      familyId: familyId ?? this.familyId,
      roomName: roomName ?? this.roomName,
      mqttTopic: mqttTopic ?? this.mqttTopic,
      lastSeen: lastSeen ?? this.lastSeen,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static IconData typeIcon(String type) {
    return switch (type) {
      'light' => Icons.lightbulb,
      'sensor' => Icons.sensors,
      'switch' => Icons.toggle_on,
      'plug' => Icons.power,
      'lock' => Icons.lock,
      'thermostat' => Icons.thermostat,
      'camera' => Icons.videocam,
      _ => Icons.devices_other,
    };
  }

  static String typeName(String type) {
    return switch (type) {
      'light' => '조명',
      'sensor' => '센서',
      'switch' => '스위치',
      'plug' => '플러그',
      'lock' => '잠금장치',
      'thermostat' => '온도조절기',
      'camera' => '카메라',
      _ => '기타',
    };
  }
}
