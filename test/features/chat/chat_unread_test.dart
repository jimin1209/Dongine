import 'package:dongine/features/chat/presentation/chat_screen.dart';
import 'package:dongine/shared/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to create a [MessageModel] with only the fields that matter for
/// [findOldestUnreadMessageId].
MessageModel _msg({
  required String id,
  required String senderId,
  Map<String, DateTime>? readBy,
  bool isDeleted = false,
}) {
  return MessageModel(
    id: id,
    senderId: senderId,
    senderName: 'User',
    content: '',
    readBy: readBy ?? {},
    createdAt: DateTime(2026),
    isDeleted: isDeleted,
  );
}

void main() {
  const me = 'userA';
  const other = 'userB';
  final readByMe = {me: DateTime(2026)};

  group('findOldestUnreadMessageId', () {
    test('returns null when message list is empty', () {
      expect(findOldestUnreadMessageId([], me), isNull);
    });

    test('returns null when all messages are sent by me', () {
      final messages = [
        _msg(id: 'm1', senderId: me),
        _msg(id: 'm2', senderId: me),
      ];
      expect(findOldestUnreadMessageId(messages, me), isNull);
    });

    test('returns null when all messages are already read', () {
      final messages = [
        _msg(id: 'm1', senderId: other, readBy: readByMe),
        _msg(id: 'm2', senderId: other, readBy: readByMe),
      ];
      expect(findOldestUnreadMessageId(messages, me), isNull);
    });

    test('returns the single unread message id', () {
      final messages = [
        _msg(id: 'new1', senderId: other), // unread
        _msg(id: 'old1', senderId: other, readBy: readByMe),
      ];
      expect(findOldestUnreadMessageId(messages, me), 'new1');
    });

    test('returns the oldest unread among multiple unreads', () {
      // messages are newest-first
      final messages = [
        _msg(id: 'new1', senderId: other), // unread (newest)
        _msg(id: 'new2', senderId: other), // unread (oldest unread)
        _msg(id: 'old1', senderId: other, readBy: readByMe),
      ];
      expect(findOldestUnreadMessageId(messages, me), 'new2');
    });

    test('ignores deleted messages', () {
      final messages = [
        _msg(id: 'del', senderId: other, isDeleted: true), // deleted
        _msg(id: 'unread', senderId: other), // unread
        _msg(id: 'read', senderId: other, readBy: readByMe),
      ];
      expect(findOldestUnreadMessageId(messages, me), 'unread');
    });

    test('ignores own unread messages', () {
      final messages = [
        _msg(id: 'mine', senderId: me), // own, no readBy for me
        _msg(id: 'read', senderId: other, readBy: readByMe),
      ];
      expect(findOldestUnreadMessageId(messages, me), isNull);
    });

    test('handles mix of own, read, unread, and deleted', () {
      final messages = [
        _msg(id: 'm1', senderId: me), // own
        _msg(id: 'm2', senderId: other), // unread
        _msg(id: 'm3', senderId: other, isDeleted: true), // deleted
        _msg(id: 'm4', senderId: other), // unread (oldest)
        _msg(id: 'm5', senderId: other, readBy: readByMe), // read
        _msg(id: 'm6', senderId: me), // own
      ];
      expect(findOldestUnreadMessageId(messages, me), 'm4');
    });

    test('all messages unread returns the oldest', () {
      final messages = [
        _msg(id: 'a', senderId: other),
        _msg(id: 'b', senderId: other),
        _msg(id: 'c', senderId: other),
      ];
      expect(findOldestUnreadMessageId(messages, me), 'c');
    });

    test('returns null when only deleted unread messages exist', () {
      final messages = [
        _msg(id: 'd1', senderId: other, isDeleted: true),
        _msg(id: 'd2', senderId: other, isDeleted: true),
      ];
      expect(findOldestUnreadMessageId(messages, me), isNull);
    });
  });
}
