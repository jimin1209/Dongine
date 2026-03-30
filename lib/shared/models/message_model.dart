import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String type;
  final String content;
  final Map<String, dynamic>? metadata;
  final Map<String, DateTime> readBy;
  final DateTime createdAt;
  final bool isDeleted;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.type = 'text',
    required this.content,
    this.metadata,
    this.readBy = const {},
    required this.createdAt,
    this.isDeleted = false,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final readByRaw = data['readBy'] as Map<String, dynamic>? ?? {};
    final readBy = readByRaw.map(
      (key, value) => MapEntry(key, (value as Timestamp).toDate()),
    );

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      type: data['type'] ?? 'text',
      content: data['content'] ?? '',
      metadata: data['metadata'] as Map<String, dynamic>?,
      readBy: readBy,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'type': type,
      'content': content,
      'metadata': metadata,
      'readBy': readBy.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
    };
  }
}
