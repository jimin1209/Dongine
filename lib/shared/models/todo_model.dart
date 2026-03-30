import 'package:cloud_firestore/cloud_firestore.dart';

class TodoModel {
  final String id;
  final String title;
  final String? description;
  final List<String> assignedTo;
  final String createdBy;
  final String? category; // '장보기', '집안일', '학교', '기타'
  final DateTime? dueDate;
  final List<DateTime> reminders;
  final bool isCompleted;
  final String? completedBy;
  final DateTime? completedAt;
  final DateTime createdAt;

  const TodoModel({
    required this.id,
    required this.title,
    this.description,
    this.assignedTo = const [],
    required this.createdBy,
    this.category,
    this.dueDate,
    this.reminders = const [],
    this.isCompleted = false,
    this.completedBy,
    this.completedAt,
    required this.createdAt,
  });

  factory TodoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TodoModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      assignedTo: List<String>.from(data['assignedTo'] ?? []),
      createdBy: data['createdBy'] ?? '',
      category: data['category'],
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      reminders: (data['reminders'] as List?)
              ?.map((e) => (e as Timestamp).toDate())
              .toList() ??
          [],
      isCompleted: data['isCompleted'] ?? false,
      completedBy: data['completedBy'],
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'createdBy': createdBy,
      'category': category,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'reminders': reminders.map((e) => Timestamp.fromDate(e)).toList(),
      'isCompleted': isCompleted,
      'completedBy': completedBy,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TodoModel copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? assignedTo,
    String? createdBy,
    String? category,
    DateTime? dueDate,
    List<DateTime>? reminders,
    bool? isCompleted,
    String? completedBy,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return TodoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      reminders: reminders ?? this.reminders,
      isCompleted: isCompleted ?? this.isCompleted,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
