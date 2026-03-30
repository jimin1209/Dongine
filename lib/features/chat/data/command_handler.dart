import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/features/chat/data/chat_repository.dart';
import 'package:dongine/features/chat/data/command_parser.dart';
import 'package:dongine/features/todo/data/todo_repository.dart';
import 'package:dongine/features/calendar/data/calendar_repository.dart';
import 'package:dongine/features/cart/data/cart_repository.dart';
import 'package:dongine/features/expense/data/expense_repository.dart';
import 'package:dongine/shared/models/todo_model.dart';
import 'package:dongine/shared/models/expense_model.dart';


class CommandHandler {
  final ChatRepository chatRepo;
  final TodoRepository todoRepo;
  final CalendarRepository calendarRepo;
  final CartRepository cartRepo;
  final ExpenseRepository expenseRepo;

  const CommandHandler({
    required this.chatRepo,
    required this.todoRepo,
    required this.calendarRepo,
    required this.cartRepo,
    required this.expenseRepo,
  });

  Future<void> handleCommand(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    switch (cmd.name) {
      case 'todo':
        await _handleTodo(cmd, familyId, userId, userName);
      case 'cart':
        await _handleCart(cmd, familyId, userId, userName);
      case 'expense':
        await _handleExpense(cmd, familyId, userId, userName);
      case 'poll':
        await _handlePoll(cmd, familyId, userId, userName);
      case 'location':
        await _handleLocation(cmd, familyId, userId, userName);
      case 'calendar':
        await _handleCalendar(cmd, familyId, userId, userName);
      case 'meal':
        await _handleMeal(cmd, familyId, userId, userName);
      case 'members':
        await _handleMembers(cmd, familyId, userId, userName);
      case 'remind':
        await _handleRemind(cmd, familyId, userId, userName);
      case 'date':
        await _handleDate(cmd, familyId, userId, userName);
    }
  }

  Future<void> _handleTodo(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    if (cmd.args.isEmpty) return;

    final todoId = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('todos')
        .doc()
        .id;

    final todo = TodoModel(
      id: todoId,
      title: cmd.args,
      createdBy: userId,
      assignedTo: [userId],
      createdAt: DateTime.now(),
    );

    await todoRepo.createTodo(familyId, todo);

    await chatRepo.sendMessage(
      familyId,
      userId,
      userName,
      cmd.rawInput,
      type: 'todo',
      metadata: {
        'todoId': todoId,
        'title': cmd.args,
        'assignedTo': userId,
      },
    );
  }

  Future<void> _handleCart(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    if (cmd.args.isEmpty) return;

    await cartRepo.addItem(familyId, cmd.args, userId);

    await chatRepo.sendMessage(
      familyId,
      userId,
      userName,
      '[장보기] ${cmd.args} 추가됨',
    );
  }

  Future<void> _handleExpense(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    if (cmd.args.isEmpty) return;

    final parts = cmd.args.split(' ');
    String title;
    String amount;

    if (parts.length >= 2) {
      amount = parts.last;
      title = parts.sublist(0, parts.length - 1).join(' ');
    } else {
      title = cmd.args;
      amount = '0';
    }

    final parsedAmount = int.tryParse(amount.replaceAll(',', '')) ?? 0;

    final expense = ExpenseModel(
      id: '',
      title: title,
      amount: parsedAmount,
      category: '기타',
      createdBy: userId,
      paidBy: userId,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await expenseRepo.addExpense(familyId, expense);

    await chatRepo.sendMessage(
      familyId,
      userId,
      userName,
      '[가계부] $title $parsedAmount원 기록됨',
    );
  }

  Future<void> _handlePoll(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    if (cmd.args.isEmpty) return;

    // Parse: first segment is question, rest are options separated by spaces
    // Emoji-based options: "저녁 메뉴 🍕 🍣 🍜"
    final parts = cmd.args.split(' ');
    if (parts.length < 2) return;

    // Find where options start (look for emoji or use last N items)
    // Simple heuristic: the question is everything before the first emoji-like token
    final List<String> questionParts = [];
    final List<String> options = [];
    bool foundOption = false;

    for (final part in parts) {
      if (!foundOption && _looksLikeOption(part)) {
        foundOption = true;
      }
      if (foundOption) {
        options.add(part);
      } else {
        questionParts.add(part);
      }
    }

    // If no emoji-like options found, treat last items as options
    if (options.isEmpty && parts.length >= 3) {
      final question = parts.first;
      final opts = parts.sublist(1);
      await _sendPollMessage(
          familyId, userId, userName, question, opts, cmd.rawInput);
      return;
    }

    final question =
        questionParts.isNotEmpty ? questionParts.join(' ') : cmd.args;
    if (options.isEmpty) {
      options.addAll(parts.sublist(1));
    }

    await _sendPollMessage(
        familyId, userId, userName, question, options, cmd.rawInput);
  }

  bool _looksLikeOption(String part) {
    if (part.isEmpty) return false;
    // Check if the string contains emoji characters
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
      unicode: true,
    );
    return emojiRegex.hasMatch(part);
  }

  Future<void> _sendPollMessage(
    String familyId,
    String userId,
    String userName,
    String question,
    List<String> options,
    String rawInput,
  ) async {
    await chatRepo.sendMessage(
      familyId,
      userId,
      userName,
      rawInput,
      type: 'poll',
      metadata: {
        'question': question,
        'options': options,
        'votes': <String, dynamic>{},
      },
    );
  }

  Future<void> _handleLocation(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    await chatRepo.sendMessage(
      familyId,
      userId,
      userName,
      cmd.rawInput,
      type: 'location',
      metadata: {
        'latitude': 0.0,
        'longitude': 0.0,
        'address': '위치 정보를 가져오는 중...',
      },
    );
  }

  Future<void> _handleCalendar(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    if (cmd.args.isEmpty) return;

    // Parse "4/5 가족 외식" → date part + title
    final parts = cmd.args.split(' ');
    final String dateStr;
    final String title;

    if (parts.length >= 2 && _isDateString(parts.first)) {
      dateStr = parts.first;
      title = parts.sublist(1).join(' ');
    } else {
      dateStr = '';
      title = cmd.args;
    }

    await chatRepo.sendMessage(
      familyId,
      userId,
      userName,
      cmd.rawInput,
      type: 'event',
      metadata: {
        'title': title,
        'date': dateStr,
      },
    );
  }

  bool _isDateString(String s) {
    return RegExp(r'^\d{1,2}/\d{1,2}$').hasMatch(s) ||
        RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(s);
  }

  Future<void> _handleMeal(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    String mealType;
    switch (cmd.args.trim()) {
      case '아침':
        mealType = 'breakfast';
      case '점심':
        mealType = 'lunch';
      case '저녁':
        mealType = 'dinner';
      default:
        mealType = 'dinner';
    }

    await chatRepo.sendMessage(
      familyId,
      userId,
      userName,
      cmd.rawInput,
      type: 'meal_vote',
      metadata: {
        'mealType': mealType,
        'options': <String>[],
        'votes': <String, dynamic>{},
      },
    );
  }

  Future<void> _handleMembers(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    await chatRepo.sendMessage(
      familyId,
      userId,
      userName,
      cmd.rawInput,
      type: 'members',
    );
  }

  Future<void> _handleRemind(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    if (cmd.args.isEmpty) return;

    // Parse "6시 약 먹기" → time + content
    final parts = cmd.args.split(' ');
    final String time;
    final String content;

    if (parts.length >= 2) {
      time = parts.first;
      content = parts.sublist(1).join(' ');
    } else {
      time = cmd.args;
      content = '';
    }

    await chatRepo.sendMessage(
      familyId,
      userId,
      userName,
      cmd.rawInput,
      type: 'reminder',
      metadata: {
        'time': time,
        'content': content,
      },
    );
  }

  Future<void> _handleDate(
    ChatCommand cmd,
    String familyId,
    String userId,
    String userName,
  ) async {
    if (cmd.args.isEmpty) return;

    await chatRepo.sendMessage(
      familyId,
      userId,
      userName,
      cmd.rawInput,
      type: 'event',
      metadata: {
        'title': cmd.args,
        'type': 'date',
      },
    );
  }
}
