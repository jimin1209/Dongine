import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/chat/data/chat_repository.dart';
import 'package:dongine/shared/models/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final messagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, familyId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getMessagesStream(familyId);
});
