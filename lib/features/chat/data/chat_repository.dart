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

  /// Cast or change a vote on a poll or meal_vote message.
  /// Rejects the vote if the message is already closed.
  Future<void> castVote(
    String familyId,
    String messageId,
    String userId,
    String option,
  ) async {
    final doc = await _messagesRef(familyId).doc(messageId).get();
    final data = doc.data();
    if (data == null) return;

    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    if (metadata['closed'] == true) return;

    await _messagesRef(familyId).doc(messageId).update({
      'metadata.votes.$userId': option,
    });
  }

  /// Close a meal vote by recording the decided option in metadata.
  Future<void> closeMealVote(
    String familyId,
    String messageId,
  ) async {
    // Read current votes to determine the winner
    final doc = await _messagesRef(familyId).doc(messageId).get();
    final data = doc.data();
    if (data == null) return;

    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    final votes = Map<String, dynamic>.from(metadata['votes'] ?? {});

    // Tally votes per option
    final tally = <String, int>{};
    for (final v in votes.values) {
      final option = v.toString();
      tally[option] = (tally[option] ?? 0) + 1;
    }

    // Pick the option with the most votes (first if tie)
    String? decided;
    if (tally.isNotEmpty) {
      decided = tally.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    final updates = <String, dynamic>{
      'metadata.closed': true,
    };
    if (decided != null) {
      updates['metadata.decided'] = decided;
    }

    await _messagesRef(familyId).doc(messageId).update(updates);
  }

  /// Close a poll — marks it as closed without picking a winner.
  Future<void> closePoll(
    String familyId,
    String messageId,
  ) async {
    await _messagesRef(familyId).doc(messageId).update({
      'metadata.closed': true,
    });
  }
}
