import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String? description;
  final String type; // 'general', 'meal', 'date', 'anniversary', 'hospital'
  final DateTime startAt;
  final DateTime endAt;
  final bool isAllDay;
  final Map<String, dynamic>? recurrence;
  final String color;
  final List<String> assignedTo;
  final List<int> reminders; // in minutes
  final String createdBy;
  final DateTime createdAt;
  final String? externalSource;
  final String? externalSourceId;
  final String? externalCalendarId;
  final DateTime? externalUpdatedAt;

  /// Google Calendar 연동 방향.
  /// 'imported': Google에서 가져온 일정 (읽기 전용, 삭제 시 로컬만 삭제)
  /// 'exported': 앱에서 만들어 Google로 내보낸 일정 (삭제 시 Google도 삭제)
  /// null: Google과 무관한 로컬 일정
  final String? googleSyncDirection;

  /// Google에서 가져온 일정인지
  bool get isGoogleImported => googleSyncDirection == 'imported';

  /// 앱에서 Google로 내보낸 일정인지
  bool get isGoogleExported => googleSyncDirection == 'exported';

  /// Google Calendar와 연동된 일정인지 (imported 또는 exported)
  bool get isGoogleLinked => googleSyncDirection != null;

  // Meal type fields
  final Map<String, dynamic>? mealVote; // {options: List<String>, votes: Map<String, String>, decided: String?}

  // Date type fields
  final List<Map<String, dynamic>>? places; // [{name, address, geopoint, order}]
  final int? budget;

  // Anniversary type fields
  final bool? dday;

  const EventModel({
    required this.id,
    required this.title,
    this.description,
    this.type = 'general',
    required this.startAt,
    required this.endAt,
    this.isAllDay = false,
    this.recurrence,
    this.color = '#4285F4',
    this.assignedTo = const [],
    this.reminders = const [],
    required this.createdBy,
    required this.createdAt,
    this.externalSource,
    this.externalSourceId,
    this.externalCalendarId,
    this.externalUpdatedAt,
    this.googleSyncDirection,
    this.mealVote,
    this.places,
    this.budget,
    this.dday,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      type: data['type'] ?? 'general',
      startAt: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (data['endAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAllDay: data['isAllDay'] ?? false,
      recurrence: data['recurrence'] != null
          ? Map<String, dynamic>.from(data['recurrence'])
          : null,
      color: data['color'] ?? '#4285F4',
      assignedTo: List<String>.from(data['assignedTo'] ?? []),
      reminders: List<int>.from(data['reminders'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      externalSource: data['externalSource'],
      externalSourceId: data['externalSourceId'],
      externalCalendarId: data['externalCalendarId'],
      externalUpdatedAt:
          (data['externalUpdatedAt'] as Timestamp?)?.toDate(),
      googleSyncDirection: data['googleSyncDirection'],
      mealVote: data['mealVote'] != null
          ? Map<String, dynamic>.from(data['mealVote'])
          : null,
      places: data['places'] != null
          ? List<Map<String, dynamic>>.from(
              (data['places'] as List).map((e) => Map<String, dynamic>.from(e)),
            )
          : null,
      budget: data['budget'],
      dday: data['dday'],
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'type': type,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'isAllDay': isAllDay,
      'recurrence': recurrence,
      'color': color,
      'assignedTo': assignedTo,
      'reminders': reminders,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };

    if (externalSource != null) {
      map['externalSource'] = externalSource;
    }
    if (externalSourceId != null) {
      map['externalSourceId'] = externalSourceId;
    }
    if (externalCalendarId != null) {
      map['externalCalendarId'] = externalCalendarId;
    }
    if (externalUpdatedAt != null) {
      map['externalUpdatedAt'] = Timestamp.fromDate(externalUpdatedAt!);
    }
    if (googleSyncDirection != null) {
      map['googleSyncDirection'] = googleSyncDirection;
    }

    if (type == 'meal') {
      map['mealVote'] = mealVote;
    }
    if (type == 'date') {
      map['places'] = places;
      map['budget'] = budget;
    }
    if (type == 'anniversary') {
      map['dday'] = dday;
    }
    if (type == 'hospital') {
      map['places'] = places;
    }

    return map;
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    DateTime? startAt,
    DateTime? endAt,
    bool? isAllDay,
    Map<String, dynamic>? recurrence,
    String? color,
    List<String>? assignedTo,
    List<int>? reminders,
    String? createdBy,
    DateTime? createdAt,
    String? externalSource,
    String? externalSourceId,
    String? externalCalendarId,
    DateTime? externalUpdatedAt,
    String? googleSyncDirection,
    Map<String, dynamic>? mealVote,
    List<Map<String, dynamic>>? places,
    int? budget,
    bool? dday,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isAllDay: isAllDay ?? this.isAllDay,
      recurrence: recurrence ?? this.recurrence,
      color: color ?? this.color,
      assignedTo: assignedTo ?? this.assignedTo,
      reminders: reminders ?? this.reminders,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      externalSource: externalSource ?? this.externalSource,
      externalSourceId: externalSourceId ?? this.externalSourceId,
      externalCalendarId: externalCalendarId ?? this.externalCalendarId,
      externalUpdatedAt: externalUpdatedAt ?? this.externalUpdatedAt,
      googleSyncDirection: googleSyncDirection ?? this.googleSyncDirection,
      mealVote: mealVote ?? this.mealVote,
      places: places ?? this.places,
      budget: budget ?? this.budget,
      dday: dday ?? this.dday,
    );
  }
}
