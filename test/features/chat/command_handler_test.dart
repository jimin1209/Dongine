import 'package:dongine/features/chat/data/chat_repository.dart';
import 'package:dongine/features/chat/data/command_handler.dart';
import 'package:dongine/features/chat/data/command_parser.dart';
import 'package:dongine/features/todo/data/todo_repository.dart';
import 'package:dongine/features/calendar/data/calendar_repository.dart';
import 'package:dongine/features/cart/data/cart_repository.dart';
import 'package:dongine/features/expense/data/expense_repository.dart';
import 'package:dongine/shared/models/expense_model.dart';
import 'package:dongine/shared/models/message_model.dart';
import 'package:dongine/shared/models/todo_model.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _SentMessage {
  final String familyId;
  final String senderId;
  final String senderName;
  final String content;
  final String type;
  final Map<String, dynamic>? metadata;

  _SentMessage({
    required this.familyId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    this.metadata,
  });
}

class _FakeChatRepository extends ChatRepository {
  final List<_SentMessage> sent = [];

  @override
  Future<void> sendMessage(
    String familyId,
    String senderId,
    String senderName,
    String content, {
    String type = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    sent.add(_SentMessage(
      familyId: familyId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: type,
      metadata: metadata,
    ));
  }

  @override
  Stream<List<MessageModel>> getMessagesStream(String familyId,
          {int limit = 50}) =>
      const Stream.empty();

  @override
  Future<void> deleteMessage(String familyId, String messageId) async {}

  @override
  Future<void> markAsRead(
          String familyId, String messageId, String userId) async {}

  @override
  Future<void> castVote(String familyId, String messageId, String userId,
          String option) async {}

  @override
  Future<void> closeMealVote(String familyId, String messageId) async {}

  @override
  Future<void> closePoll(String familyId, String messageId) async {}
}

class _FakeTodoRepository extends TodoRepository {
  final List<TodoModel> created = [];

  @override
  Future<void> createTodo(String familyId, TodoModel todo) async {
    created.add(todo);
  }
}

class _FakeCartRepository extends CartRepository {
  final List<({String familyId, String name, String userId})> added = [];

  @override
  Future<void> addItem(
    String familyId,
    String name,
    String userId, {
    int quantity = 1,
    String? category,
  }) async {
    added.add((familyId: familyId, name: name, userId: userId));
  }
}

class _FakeExpenseRepository extends ExpenseRepository {
  final List<ExpenseModel> added = [];

  @override
  Future<void> addExpense(String familyId, ExpenseModel expense) async {
    added.add(expense);
  }
}

class _FakeCalendarRepository extends CalendarRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _familyId = 'fam-1';
const _userId = 'user-1';
const _userName = '홍길동';
const _fakeId = 'fake-todo-id';

CommandHandler _buildHandler({
  _FakeChatRepository? chatRepo,
  _FakeTodoRepository? todoRepo,
  _FakeCartRepository? cartRepo,
  _FakeExpenseRepository? expenseRepo,
  _FakeCalendarRepository? calendarRepo,
}) {
  return CommandHandler(
    chatRepo: chatRepo ?? _FakeChatRepository(),
    todoRepo: todoRepo ?? _FakeTodoRepository(),
    calendarRepo: calendarRepo ?? _FakeCalendarRepository(),
    cartRepo: cartRepo ?? _FakeCartRepository(),
    expenseRepo: expenseRepo ?? _FakeExpenseRepository(),
    todoIdGenerator: (_) => _fakeId,
  );
}

ChatCommand _cmd(String input) => CommandParser.parse(input)!;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // /todo
  // -----------------------------------------------------------------------
  group('/todo command', () {
    test('creates todo and sends todo-type message', () async {
      final chat = _FakeChatRepository();
      final todo = _FakeTodoRepository();
      final handler = _buildHandler(chatRepo: chat, todoRepo: todo);

      await handler.handleCommand(
          _cmd('/todo 우유 사오기'), _familyId, _userId, _userName);

      expect(todo.created, hasLength(1));
      expect(todo.created.first.title, '우유 사오기');
      expect(todo.created.first.id, _fakeId);
      expect(todo.created.first.createdBy, _userId);
      expect(todo.created.first.assignedTo, [_userId]);

      expect(chat.sent, hasLength(1));
      final msg = chat.sent.first;
      expect(msg.type, 'todo');
      expect(msg.metadata!['todoId'], _fakeId);
      expect(msg.metadata!['title'], '우유 사오기');
      expect(msg.metadata!['assignedTo'], _userId);
    });

    test('empty args → no side-effects', () async {
      final chat = _FakeChatRepository();
      final todo = _FakeTodoRepository();
      final handler = _buildHandler(chatRepo: chat, todoRepo: todo);

      await handler.handleCommand(
          _cmd('/todo'), _familyId, _userId, _userName);

      expect(todo.created, isEmpty);
      expect(chat.sent, isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // /cart
  // -----------------------------------------------------------------------
  group('/cart command', () {
    test('adds item and sends text message', () async {
      final chat = _FakeChatRepository();
      final cart = _FakeCartRepository();
      final handler = _buildHandler(chatRepo: chat, cartRepo: cart);

      await handler.handleCommand(
          _cmd('/cart 계란'), _familyId, _userId, _userName);

      expect(cart.added, hasLength(1));
      expect(cart.added.first.name, '계란');
      expect(cart.added.first.userId, _userId);

      expect(chat.sent, hasLength(1));
      expect(chat.sent.first.content, '[장보기] 계란 추가됨');
      expect(chat.sent.first.type, 'text');
    });

    test('multi-word item name preserved', () async {
      final cart = _FakeCartRepository();
      final handler = _buildHandler(cartRepo: cart);

      await handler.handleCommand(
          _cmd('/cart 유기농 달걀 30구'), _familyId, _userId, _userName);

      expect(cart.added.first.name, '유기농 달걀 30구');
    });

    test('empty args → no side-effects', () async {
      final chat = _FakeChatRepository();
      final cart = _FakeCartRepository();
      final handler = _buildHandler(chatRepo: chat, cartRepo: cart);

      await handler.handleCommand(
          _cmd('/cart'), _familyId, _userId, _userName);

      expect(cart.added, isEmpty);
      expect(chat.sent, isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // /expense
  // -----------------------------------------------------------------------
  group('/expense command', () {
    test('title + amount parsed correctly', () async {
      final chat = _FakeChatRepository();
      final expense = _FakeExpenseRepository();
      final handler = _buildHandler(chatRepo: chat, expenseRepo: expense);

      await handler.handleCommand(
          _cmd('/expense 점심 식사 12000'), _familyId, _userId, _userName);

      expect(expense.added, hasLength(1));
      final e = expense.added.first;
      expect(e.title, '점심 식사');
      expect(e.amount, 12000);
      expect(e.category, '기타');
      expect(e.createdBy, _userId);
      expect(e.paidBy, _userId);

      expect(chat.sent, hasLength(1));
      expect(chat.sent.first.content, '[가계부] 점심 식사 12000원 기록됨');
    });

    test('comma-separated amount parsed', () async {
      final expense = _FakeExpenseRepository();
      final handler = _buildHandler(expenseRepo: expense);

      await handler.handleCommand(
          _cmd('/expense 마트 장보기 150,000'), _familyId, _userId, _userName);

      expect(expense.added.first.amount, 150000);
      expect(expense.added.first.title, '마트 장보기');
    });

    test('title only → amount defaults to 0', () async {
      final expense = _FakeExpenseRepository();
      final handler = _buildHandler(expenseRepo: expense);

      await handler.handleCommand(
          _cmd('/expense 커피'), _familyId, _userId, _userName);

      expect(expense.added.first.title, '커피');
      expect(expense.added.first.amount, 0);
    });

    test('non-numeric last word → amount 0, full args as title', () async {
      final expense = _FakeExpenseRepository();
      final handler = _buildHandler(expenseRepo: expense);

      await handler.handleCommand(
          _cmd('/expense 생일 선물 고급'), _familyId, _userId, _userName);

      expect(expense.added.first.title, '생일 선물');
      expect(expense.added.first.amount, 0);
    });

    test('empty args → no side-effects', () async {
      final chat = _FakeChatRepository();
      final expense = _FakeExpenseRepository();
      final handler = _buildHandler(chatRepo: chat, expenseRepo: expense);

      await handler.handleCommand(
          _cmd('/expense'), _familyId, _userId, _userName);

      expect(expense.added, isEmpty);
      expect(chat.sent, isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // /calendar
  // -----------------------------------------------------------------------
  group('/calendar command', () {
    test('date + title parsed (M/D format)', () async {
      final chat = _FakeChatRepository();
      final handler = _buildHandler(chatRepo: chat);

      await handler.handleCommand(
          _cmd('/calendar 4/5 가족 외식'), _familyId, _userId, _userName);

      expect(chat.sent, hasLength(1));
      final msg = chat.sent.first;
      expect(msg.type, 'event');
      expect(msg.metadata!['date'], '4/5');
      expect(msg.metadata!['title'], '가족 외식');
    });

    test('date + title parsed (YYYY-M-D format)', () async {
      final chat = _FakeChatRepository();
      final handler = _buildHandler(chatRepo: chat);

      await handler.handleCommand(
          _cmd('/calendar 2026-4-5 봄 소풍'), _familyId, _userId, _userName);

      final msg = chat.sent.first;
      expect(msg.metadata!['date'], '2026-4-5');
      expect(msg.metadata!['title'], '봄 소풍');
    });

    test('no date prefix → empty date, full args as title', () async {
      final chat = _FakeChatRepository();
      final handler = _buildHandler(chatRepo: chat);

      await handler.handleCommand(
          _cmd('/calendar 가족 여행 계획'), _familyId, _userId, _userName);

      final msg = chat.sent.first;
      expect(msg.metadata!['date'], '');
      expect(msg.metadata!['title'], '가족 여행 계획');
    });

    test('empty args → no side-effects', () async {
      final chat = _FakeChatRepository();
      final handler = _buildHandler(chatRepo: chat);

      await handler.handleCommand(
          _cmd('/calendar'), _familyId, _userId, _userName);

      expect(chat.sent, isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // Cross-cutting: user-friendly failure on missing / bad args
  // -----------------------------------------------------------------------
  group('graceful failure on empty or missing args', () {
    late _FakeChatRepository chat;
    late _FakeTodoRepository todo;
    late _FakeCartRepository cart;
    late _FakeExpenseRepository expense;
    late CommandHandler handler;

    setUp(() {
      chat = _FakeChatRepository();
      todo = _FakeTodoRepository();
      cart = _FakeCartRepository();
      expense = _FakeExpenseRepository();
      handler = _buildHandler(
        chatRepo: chat,
        todoRepo: todo,
        cartRepo: cart,
        expenseRepo: expense,
      );
    });

    for (final commandName in ['todo', 'cart', 'expense', 'calendar']) {
      test('/$commandName with no args produces no messages or repo calls',
          () async {
        final cmd = ChatCommand(
          name: commandName,
          args: '',
          rawInput: '/$commandName',
        );

        await handler.handleCommand(cmd, _familyId, _userId, _userName);

        expect(chat.sent, isEmpty,
            reason: '/$commandName with empty args should not send a message');
        expect(todo.created, isEmpty);
        expect(cart.added, isEmpty);
        expect(expense.added, isEmpty);
      });
    }

    test('/remind with no args produces no message', () async {
      final cmd = ChatCommand(name: 'remind', args: '', rawInput: '/remind');
      await handler.handleCommand(cmd, _familyId, _userId, _userName);
      expect(chat.sent, isEmpty);
    });

    test('/date with no args produces no message', () async {
      final cmd = ChatCommand(name: 'date', args: '', rawInput: '/date');
      await handler.handleCommand(cmd, _familyId, _userId, _userName);
      expect(chat.sent, isEmpty);
    });

    test('/poll with no args produces no message', () async {
      final cmd = ChatCommand(name: 'poll', args: '', rawInput: '/poll');
      await handler.handleCommand(cmd, _familyId, _userId, _userName);
      expect(chat.sent, isEmpty);
    });

    test('/poll with single word (no options) produces no message', () async {
      final cmd =
          ChatCommand(name: 'poll', args: '저녁메뉴', rawInput: '/poll 저녁메뉴');
      await handler.handleCommand(cmd, _familyId, _userId, _userName);
      expect(chat.sent, isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // Parser → Handler integration sanity
  // -----------------------------------------------------------------------
  group('parser + handler integration', () {
    test('unsupported command returns null from parser', () {
      expect(CommandParser.parse('/unknown 뭔가'), isNull);
    });

    test('plain text returns null from parser', () {
      expect(CommandParser.parse('그냥 대화'), isNull);
    });

    test('case-insensitive command is handled', () async {
      final chat = _FakeChatRepository();
      final cart = _FakeCartRepository();
      final handler = _buildHandler(chatRepo: chat, cartRepo: cart);
      final cmd = CommandParser.parse('/CART 두부');

      expect(cmd, isNotNull);
      await handler.handleCommand(cmd!, _familyId, _userId, _userName);

      expect(cart.added, hasLength(1));
      expect(cart.added.first.name, '두부');
    });
  });

  // -----------------------------------------------------------------------
  // Additional downstream behaviour for non-core commands
  // -----------------------------------------------------------------------
  group('supplementary command handlers', () {
    test('/location sends location type with placeholder metadata', () async {
      final chat = _FakeChatRepository();
      final handler = _buildHandler(chatRepo: chat);

      await handler.handleCommand(
          _cmd('/location'), _familyId, _userId, _userName);

      expect(chat.sent, hasLength(1));
      expect(chat.sent.first.type, 'location');
      expect(chat.sent.first.metadata!['latitude'], 0.0);
      expect(chat.sent.first.metadata!['address'], contains('위치'));
    });

    test('/meal defaults to dinner for unknown arg', () async {
      final chat = _FakeChatRepository();
      final handler = _buildHandler(chatRepo: chat);

      await handler.handleCommand(
          _cmd('/meal 야식'), _familyId, _userId, _userName);

      expect(chat.sent.first.type, 'meal_vote');
      expect(chat.sent.first.metadata!['mealType'], 'dinner');
    });

    test('/meal 아침 maps to breakfast', () async {
      final chat = _FakeChatRepository();
      final handler = _buildHandler(chatRepo: chat);

      await handler.handleCommand(
          _cmd('/meal 아침'), _familyId, _userId, _userName);

      expect(chat.sent.first.metadata!['mealType'], 'breakfast');
    });

    test('/members sends members type message', () async {
      final chat = _FakeChatRepository();
      final handler = _buildHandler(chatRepo: chat);

      await handler.handleCommand(
          _cmd('/members'), _familyId, _userId, _userName);

      expect(chat.sent.first.type, 'members');
    });

    test('/remind parses time and content', () async {
      final chat = _FakeChatRepository();
      final handler = _buildHandler(chatRepo: chat);

      await handler.handleCommand(
          _cmd('/remind 6시 약 먹기'), _familyId, _userId, _userName);

      expect(chat.sent.first.type, 'reminder');
      expect(chat.sent.first.metadata!['time'], '6시');
      expect(chat.sent.first.metadata!['content'], '약 먹기');
    });

    test('/date sends event type with date metadata', () async {
      final chat = _FakeChatRepository();
      final handler = _buildHandler(chatRepo: chat);

      await handler.handleCommand(
          _cmd('/date 결혼기념일'), _familyId, _userId, _userName);

      expect(chat.sent.first.type, 'event');
      expect(chat.sent.first.metadata!['title'], '결혼기념일');
      expect(chat.sent.first.metadata!['type'], 'date');
    });
  });
}
