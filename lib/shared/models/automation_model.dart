import 'package:cloud_firestore/cloud_firestore.dart';

class AutomationModel {
  final String id;
  final String name;
  final Map<String, dynamic> trigger;
  final List<Map<String, dynamic>> actions;
  final bool isEnabled;
  final String familyId;
  final String createdBy;
  final DateTime createdAt;

  const AutomationModel({
    required this.id,
    required this.name,
    required this.trigger,
    required this.actions,
    this.isEnabled = true,
    required this.familyId,
    required this.createdBy,
    required this.createdAt,
  });

  factory AutomationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AutomationModel(
      id: doc.id,
      name: data['name'] ?? '',
      trigger: Map<String, dynamic>.from(data['trigger'] ?? {}),
      actions: (data['actions'] as List<dynamic>?)
              ?.map((a) => Map<String, dynamic>.from(a as Map))
              .toList() ??
          [],
      isEnabled: data['isEnabled'] ?? true,
      familyId: data['familyId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'trigger': trigger,
      'actions': actions,
      'isEnabled': isEnabled,
      'familyId': familyId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
