import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/chat/data/chat_repository.dart';
import 'package:dongine/shared/models/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return FirestoreChatRepository();
});

/// `ProviderScope`로 override 하면 Firebase 인증 없이 채팅 화면을 검증할 수 있다.
/// null이면 [authRepositoryProvider]의 `currentUser`를 사용한다.
final chatTestSessionProvider = Provider<ChatTestSession?>((ref) => null);

class ChatTestSession {
  const ChatTestSession({
    required this.uid,
    this.displayName,
  });

  final String uid;
  final String? displayName;
}

final messagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, familyId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getMessagesStream(familyId);
});
