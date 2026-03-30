import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/chat/domain/chat_provider.dart';
import 'package:dongine/features/chat/data/command_parser.dart';
import 'package:dongine/features/chat/data/command_handler.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/cart/domain/cart_provider.dart';
import 'package:dongine/shared/models/message_model.dart';
import 'package:dongine/features/chat/presentation/widgets/command_suggestions.dart';
import 'package:dongine/features/chat/presentation/widgets/message_cards.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isCommandMode = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final commandMode = text.startsWith('/');
    if (commandMode != _isCommandMode) {
      setState(() {
        _isCommandMode = commandMode;
      });
    }
  }

  void _sendMessage(String familyId) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final currentUser = ref.read(authRepositoryProvider).currentUser;
    if (currentUser == null) return;

    final userName = currentUser.displayName ?? '알 수 없음';

    // Check if it's a command
    final command = CommandParser.parse(content);
    if (command != null) {
      final handler = CommandHandler(
        chatRepo: ref.read(chatRepositoryProvider),
        todoRepo: ref.read(todoRepositoryProvider),
        calendarRepo: ref.read(calendarRepositoryProvider),
        cartRepo: ref.read(cartRepositoryProvider),
      );

      _messageController.clear();

      await handler.handleCommand(
        command,
        familyId,
        currentUser.uid,
        userName,
      );
    } else {
      ref.read(chatRepositoryProvider).sendMessage(
            familyId,
            currentUser.uid,
            userName,
            content,
          );

      _messageController.clear();
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onCommandSelected(String command) {
    _messageController.text = command;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: command.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return familyAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('오류가 발생했습니다: $error')),
      ),
      data: (family) {
        if (family == null) {
          return const Scaffold(
            body: Center(child: Text('가족 그룹에 참여해주세요')),
          );
        }
        final familyId = family.id;
        final messagesAsync = ref.watch(messagesProvider(familyId));
        final currentUser = ref.read(authRepositoryProvider).currentUser;

        return Scaffold(
          appBar: AppBar(title: Text(family.name)),
          body: Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Center(child: Text('메시지 로딩 실패: $error')),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          '첫 메시지를 보내보세요!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isOwn =
                            message.senderId == currentUser?.uid;

                        return _buildMessageItem(
                          message,
                          isOwn,
                          currentUser?.uid,
                          familyId,
                        );
                      },
                    );
                  },
                ),
              ),
              if (_isCommandMode)
                CommandSuggestions(
                  currentInput: _messageController.text,
                  onCommandSelected: _onCommandSelected,
                ),
              _buildInputBar(familyId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageItem(
    MessageModel message,
    bool isOwn,
    String? currentUserId,
    String familyId,
  ) {
    final timeFormat = DateFormat('HH:mm');

    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '삭제된 메시지입니다',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    Widget messageWidget;

    switch (message.type) {
      case 'todo':
        messageWidget = TodoCard(
          message: message,
          isOwn: isOwn,
          onToggle: () {
            final metadata = message.metadata;
            if (metadata != null && metadata['todoId'] != null) {
              final todoId = metadata['todoId'] as String;
              final isCompleted = metadata['isCompleted'] as bool? ?? false;
              ref.read(todoRepositoryProvider).toggleTodo(
                    familyId,
                    todoId,
                    !isCompleted,
                    currentUserId ?? '',
                  );
            }
          },
        );
      case 'poll':
        messageWidget = PollCard(
          message: message,
          isOwn: isOwn,
          currentUserId: currentUserId,
        );
      case 'meal_vote':
        messageWidget = MealVoteCard(
          message: message,
          isOwn: isOwn,
          currentUserId: currentUserId,
        );
      case 'reminder':
        messageWidget = ReminderCard(
          message: message,
          isOwn: isOwn,
        );
      case 'event':
        messageWidget = EventCard(
          message: message,
          isOwn: isOwn,
        );
      case 'location':
        messageWidget = LocationCard(
          message: message,
          isOwn: isOwn,
        );
      case 'members':
        messageWidget = MembersCard(
          message: message,
          isOwn: isOwn,
        );
      default:
        messageWidget = _MessageBubble(
          message: message,
          isOwn: isOwn,
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isOwn && message.type == 'text')
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (!isOwn && message.type != 'text')
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          messageWidget,
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
            child: Text(
              timeFormat.format(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(String familyId) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 4,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(familyId),
              decoration: InputDecoration(
                hintText: _isCommandMode
                    ? '커맨드를 입력하세요'
                    : '메시지를 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _sendMessage(familyId),
            icon: Icon(
              Icons.send_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isOwn;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isOwn
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isOwn ? const Radius.circular(16) : Radius.zero,
            bottomRight: isOwn ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            fontSize: 15,
            color: isOwn
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
