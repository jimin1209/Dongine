import 'dart:async';

sealed class FamilyEvent {
  final DateTime timestamp;
  FamilyEvent() : timestamp = DateTime.now();
}

class MessageEvent extends FamilyEvent {
  final String familyId;
  final String senderId;
  final String message;

  MessageEvent({
    required this.familyId,
    required this.senderId,
    required this.message,
  });
}

class LocationEvent extends FamilyEvent {
  final String familyId;
  final String userId;
  final double latitude;
  final double longitude;

  LocationEvent({
    required this.familyId,
    required this.userId,
    required this.latitude,
    required this.longitude,
  });
}

class DeviceStateEvent extends FamilyEvent {
  final String familyId;
  final String deviceId;
  final Map<String, dynamic> state;

  DeviceStateEvent({
    required this.familyId,
    required this.deviceId,
    required this.state,
  });
}

class AutomationTriggerEvent extends FamilyEvent {
  final String familyId;
  final String automationId;
  final String automationName;

  AutomationTriggerEvent({
    required this.familyId,
    required this.automationId,
    required this.automationName,
  });
}

class FamilyEventBus {
  FamilyEventBus._();
  static final FamilyEventBus _instance = FamilyEventBus._();
  static FamilyEventBus get instance => _instance;

  final StreamController<FamilyEvent> _controller =
      StreamController<FamilyEvent>.broadcast();

  Stream<FamilyEvent> get events => _controller.stream;

  void emit(FamilyEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}
