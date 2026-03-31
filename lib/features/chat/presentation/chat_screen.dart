import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:dongine/features/expense/domain/expense_provider.dart';
import 'package:dongine/shared/models/message_model.dart';
import 'package:dongine/features/chat/presentation/widgets/command_suggestions.dart';
import 'package:dongine/features/chat/presentation/widgets/message_cards.dart';

/// Returns the message ID of the oldest unread message not sent by
/// [currentUserId]. Returns null when every message has been read.
String? findOldestUnreadMessageId(
  List<MessageModel> messages,
  String currentUserId,
) {
  // messages are newest-first; walk the entire list so the last match is the
  // oldest unread message.
  String? oldestUnreadId;
  for (final message in messages) {
    if (message.senderId != currentUserId &&
        !message.readBy.containsKey(currentUserId) &&
        !message.isDeleted) {
      oldestUnreadId = message.id;
    }
  }
  return oldestUnreadId;
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isCommandMode = false;
  final Set<String> _markedAsReadIds = {};

  /// Captured once on first message load — persists for the screen session.
  String? _unreadDividerMessageId;
  bool _unreadDividerComputed = false;

  /// Whether the user has scrolled far enough from the bottom to show the FAB.
  bool _showScrollToBottom = false;

  /// Count of new messages that arrived while the user was scrolled away.
  int _newMessagesWhileScrolled = 0;
  String? _latestKnownMessageId;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show =
        _scrollController.hasClients && _scrollController.offset > 200;
    if (show != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = show;
        if (!show) {
          _newMessagesWhileScrolled = 0;
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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

  ChatTestSession? _resolveChatSession() {
    final test = ref.read(chatTestSessionProvider);
    if (test != null) return test;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return null;
    return ChatTestSession(uid: user.uid, displayName: user.displayName);
  }

  void _sendMessage(String familyId) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final session = _resolveChatSession();
    if (session == null) return;

    final userName = session.displayName ?? '알 수 없음';

    // Check if it's a command
    final command = CommandParser.parse(content);
    if (command != null) {
      final handler = CommandHandler(
        chatRepo: ref.read(chatRepositoryProvider),
        todoRepo: ref.read(todoRepositoryProvider),
        calendarRepo: ref.read(calendarRepositoryProvider),
        cartRepo: ref.read(cartRepositoryProvider),
        expenseRepo: ref.read(expenseRepositoryProvider),
      );

      _messageController.clear();

      await handler.handleCommand(
        command,
        familyId,
        session.uid,
        userName,
      );
    } else {
      ref.read(chatRepositoryProvider).sendMessage(
            familyId,
            session.uid,
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
        final session = _resolveChatSession();

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

                    // Compute unread divider once on first load.
                    if (!_unreadDividerComputed && session != null) {
                      _unreadDividerMessageId = findOldestUnreadMessageId(
                        messages,
                        session.uid,
                      );
                      _unreadDividerComputed = true;
                    }

                    // Track new messages arriving while scrolled away.
                    if (messages.isNotEmpty) {
                      final newestId = messages.first.id;
                      if (_latestKnownMessageId != null &&
                          newestId != _latestKnownMessageId &&
                          _showScrollToBottom) {
                        _newMessagesWhileScrolled++;
                      }
                      if (!_showScrollToBottom) {
                        _latestKnownMessageId = newestId;
                      }
                    }

                    // Auto mark-as-read for incoming messages
                    if (session != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markUnreadMessages(
                          messages,
                          session.uid,
                          familyId,
                        );
                      });
                    }

                    return Stack(
                      children: [
                        ListView.builder(
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
                                message.senderId == session?.uid;

                            final messageWidget = _buildMessageItem(
                              message,
                              isOwn,
                              session?.uid,
                              familyId,
                            );

                            // In a reverse list, "above" visually means
                            // the widget rendered at the top of this item.
                            if (message.id == _unreadDividerMessageId) {
                              return Column(
                                children: [
                                  messageWidget,
                                  _buildUnreadDivider(),
                                ],
                              );
                            }

                            return messageWidget;
                          },
                        ),
                        if (_showScrollToBottom)
                          _buildScrollToBottomButton(),
                      ],
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

  void _markUnreadMessages(
    List<MessageModel> messages,
    String currentUserId,
    String familyId,
  ) {
    final chatRepo = ref.read(chatRepositoryProvider);
    for (final message in messages) {
      if (message.senderId != currentUserId &&
          !message.readBy.containsKey(currentUserId) &&
          !_markedAsReadIds.contains(message.id)) {
        _markedAsReadIds.add(message.id);
        chatRepo.markAsRead(familyId, message.id, currentUserId);
      }
    }
  }

  void _showMessageActions(
    BuildContext context,
    MessageModel message,
    bool isOwn,
    String familyId,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('복사'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('메시지가 복사되었습니다'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              if (isOwn)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('삭제', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(chatRepositoryProvider).deleteMessage(
                          familyId,
                          message.id,
                        );
                  },
                ),
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
        break;
      case 'poll':
        final isPollClosed =
            message.metadata?['closed'] == true;
        messageWidget = PollCard(
          message: message,
          isOwn: isOwn,
          currentUserId: currentUserId,
          onVote: !isPollClosed && currentUserId != null
              ? (option) => ref.read(chatRepositoryProvider).castVote(
                    familyId,
                    message.id,
                    currentUserId,
                    option,
                  )
              : null,
          onClose: message.senderId == currentUserId && !isPollClosed
              ? () => ref.read(chatRepositoryProvider).closePoll(
                    familyId,
                    message.id,
                  )
              : null,
        );
        break;
      case 'meal_vote':
        final isClosed =
            message.metadata?['closed'] == true;
        messageWidget = MealVoteCard(
          message: message,
          isOwn: isOwn,
          currentUserId: currentUserId,
          onVote: !isClosed && currentUserId != null
              ? (option) => ref.read(chatRepositoryProvider).castVote(
                    familyId,
                    message.id,
                    currentUserId,
                    option,
                  )
              : null,
          onClose: message.senderId == currentUserId && !isClosed
              ? () => ref.read(chatRepositoryProvider).closeMealVote(
                    familyId,
                    message.id,
                  )
              : null,
        );
        break;
      case 'reminder':
        messageWidget = ReminderCard(
          message: message,
          isOwn: isOwn,
        );
        break;
      case 'event':
        messageWidget = EventCard(
          message: message,
          isOwn: isOwn,
        );
        break;
      case 'location':
        messageWidget = LocationCard(
          message: message,
          isOwn: isOwn,
        );
        break;
      case 'members':
        messageWidget = MembersCard(
          message: message,
          isOwn: isOwn,
        );
        break;
      default:
        messageWidget = GestureDetector(
          onLongPress: () => _showMessageActions(
            context,
            message,
            isOwn,
            familyId,
          ),
          child: _MessageBubble(
            message: message,
            isOwn: isOwn,
          ),
        );
        break;
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
            child: _buildTimestampRow(message, isOwn, timeFormat),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampRow(
    MessageModel message,
    bool isOwn,
    DateFormat timeFormat,
  ) {
    final timeText = Text(
      timeFormat.format(message.createdAt),
      style: TextStyle(
        fontSize: 11,
        color: Colors.grey.shade500,
      ),
    );

    if (!isOwn || message.isDeleted) {
      return timeText;
    }

    // Read receipts for own messages: count readers excluding self
    final otherReaders =
        message.readBy.keys.where((uid) => uid != message.senderId).length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        timeText,
        const SizedBox(width: 4),
        if (otherReaders > 0)
          Text(
            '읽음 $otherReaders',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          )
        else
          Text(
            '\u2713',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
      ],
    );
  }

  Widget _buildUnreadDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.red.shade300, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '여기부터 새 메시지',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.red.shade300, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    return Positioned(
      right: 12,
      bottom: 12,
      child: GestureDetector(
        onTap: _scrollToBottom,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 28,
              ),
              if (_newMessagesWhileScrolled > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$_newMessagesWhileScrolled',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
