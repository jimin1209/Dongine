import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/services/mqtt_service.dart';
import 'package:dongine/shared/models/automation_model.dart';
import 'package:dongine/shared/models/iot_device_model.dart';

class IoTRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Devices

  Stream<List<IoTDeviceModel>> getDevicesStream(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('devices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IoTDeviceModel.fromFirestore(doc))
            .toList());
  }

  Future<void> addDevice(String familyId, IoTDeviceModel device) async {
    final docRef = _firestore
        .collection('families')
        .doc(familyId)
        .collection('devices')
        .doc(device.id);
    await docRef.set(device.toFirestore());
  }

  Future<void> removeDevice(String familyId, String deviceId) async {
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('devices')
        .doc(deviceId)
        .delete();
  }

  Future<void> updateDeviceState(
    String familyId,
    String deviceId,
    Map<String, dynamic> state,
  ) async {
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('devices')
        .doc(deviceId)
        .update({
      'state': state,
      'lastSeen': Timestamp.fromDate(DateTime.now()),
    });
  }

  void controlDevice(
    MqttService mqtt,
    String topic,
    Map<String, dynamic> command,
  ) {
    mqtt.publish(topic, jsonEncode(command));
  }

  // Automations

  Stream<List<AutomationModel>> getAutomationsStream(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('automations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AutomationModel.fromFirestore(doc))
            .toList());
  }

  Future<void> createAutomation(
    String familyId,
    AutomationModel automation,
  ) async {
    final docRef = _firestore
        .collection('families')
        .doc(familyId)
        .collection('automations')
        .doc(automation.id);
    await docRef.set(automation.toFirestore());
  }

  Future<void> toggleAutomation(
    String familyId,
    String automationId,
    bool enabled,
  ) async {
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('automations')
        .doc(automationId)
        .update({'isEnabled': enabled});
  }

  Future<void> deleteAutomation(
    String familyId,
    String automationId,
  ) async {
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('automations')
        .doc(automationId)
        .delete();
  }
}
