import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/shared/models/message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('messages');
  }

  Future<void> sendMessage(
    String familyId,
    String senderId,
    String senderName,
    String content, {
    String type = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    await _messagesRef(familyId).add({
      'senderId': senderId,
      'senderName': senderName,
      'type': type,
      'content': content,
      'metadata': metadata,
      'readBy': {senderId: FieldValue.serverTimestamp()},
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });
  }

  Stream<List<MessageModel>> getMessagesStream(
    String familyId, {
    int limit = 50,
  }) {
    return _messagesRef(familyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> deleteMessage(String familyId, String messageId) async {
    await _messagesRef(familyId).doc(messageId).update({
      'isDeleted': true,
    });
  }

  Future<void> markAsRead(
    String familyId,
    String messageId,
    String userId,
  ) async {
    await _messagesRef(familyId).doc(messageId).update({
      'readBy.$userId': FieldValue.serverTimestamp(),
    });
  }
}
