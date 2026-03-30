import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpenseModel {
  final String id;
  final String title;
  final int amount;
  final String category;
  final String? memo;
  final String createdBy;
  final String paidBy;
  final DateTime date;
  final String? eventId;
  final DateTime createdAt;

  static const List<String> categories = [
    '식비',
    '교통',
    '생활',
    '의료',
    '교육',
    '여가',
    '기타',
  ];

  static IconData categoryIcon(String category) {
    return switch (category) {
      '식비' => Icons.restaurant,
      '교통' => Icons.directions_bus,
      '생활' => Icons.home,
      '의료' => Icons.local_hospital,
      '교육' => Icons.school,
      '여가' => Icons.sports_esports,
      '기타' => Icons.more_horiz,
      _ => Icons.more_horiz,
    };
  }

  static Color categoryColor(String category) {
    return switch (category) {
      '식비' => Colors.orange,
      '교통' => Colors.blue,
      '생활' => Colors.teal,
      '의료' => Colors.red,
      '교육' => Colors.indigo,
      '여가' => Colors.purple,
      '기타' => Colors.grey,
      _ => Colors.grey,
    };
  }

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.memo,
    required this.createdBy,
    required this.paidBy,
    required this.date,
    this.eventId,
    required this.createdAt,
  });

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel.fromFirestoreData(doc.id, data);
  }

  /// [fromFirestore]와 동일한 필드 규칙으로 맵에서 복원합니다. (테스트·도구용)
  factory ExpenseModel.fromFirestoreData(String id, Map<String, dynamic> data) {
    return ExpenseModel(
      id: id,
      title: data['title'] ?? '',
      amount: data['amount'] ?? 0,
      category: data['category'] ?? '기타',
      memo: data['memo'] as String?,
      createdBy: data['createdBy'] ?? '',
      paidBy: data['paidBy'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventId: data['eventId'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'memo': memo,
      'createdBy': createdBy,
      'paidBy': paidBy,
      'date': Timestamp.fromDate(date),
      'eventId': eventId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? title,
    int? amount,
    String? category,
    String? memo,
    String? createdBy,
    String? paidBy,
    DateTime? date,
    String? eventId,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      memo: memo ?? this.memo,
      createdBy: createdBy ?? this.createdBy,
      paidBy: paidBy ?? this.paidBy,
      date: date ?? this.date,
      eventId: eventId ?? this.eventId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
