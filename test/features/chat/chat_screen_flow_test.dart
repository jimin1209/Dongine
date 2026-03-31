import 'dart:async';

import 'package:dongine/features/chat/data/chat_repository.dart';
import 'package:dongine/features/chat/domain/chat_provider.dart';
import 'package:dongine/features/chat/presentation/chat_screen.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/message_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _familyId = 'fam-chat-flow';

final _testFamily = FamilyModel(
  id: _familyId,
  name: '채팅 테스트 가족',
  createdBy: 'user-me',
  inviteCode: 'CHAT01',
  createdAt: DateTime(2026, 1, 1),
);

MessageModel _textMessage({
  required String id,
  required String senderId,
  required String senderName,
  required String content,
  Map<String, DateTime> readBy = const {},
  DateTime? createdAt,
}) {
  return MessageModel(
    id: id,
    senderId: senderId,
    senderName: senderName,
    type: 'text',
    content: content,
    readBy: readBy,
    createdAt: createdAt ?? DateTime(2026, 3, 1, 12, 0),
    isDeleted: false,
  );
}

/// Firebase에 연결하지 않는 채팅 저장소 스텁.
class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository(List<MessageModel> initial) : _list = List.from(initial);

  final _updates = StreamController<List<MessageModel>>.broadcast();
  List<MessageModel> _list;

  int sendCallCount = 0;
  final List<String> lastSentContents = [];
  final List<String> deletedMessageIds = [];
  final List<String> markAsReadIds = [];

  @override
  Future<void> sendMessage(
    String familyId,
    String senderId,
    String senderName,
    String content, {
    String type = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    sendCallCount++;
    lastSentContents.add(content);
    final msg = MessageModel(
      id: 'sent-$sendCallCount',
      senderId: senderId,
      senderName: senderName,
      type: type,
      content: content,
      metadata: metadata,
      readBy: {senderId: DateTime(2026)},
      createdAt: DateTime(2026, 3, 2, sendCallCount, 0),
      isDeleted: false,
    );
    _list = [msg, ..._list];
    _emit();
  }

  @override
  Stream<List<MessageModel>> getMessagesStream(
    String familyId, {
    int limit = 50,
  }) async* {
    List<MessageModel> clip(List<MessageModel> l) =>
        l.length <= limit ? List.unmodifiable(l) : l.sublist(0, limit);

    yield clip(_list);
    await for (final batch in _updates.stream) {
      yield clip(batch);
    }
  }

  void _emit() {
    if (_updates.isClosed) return;
    _updates.add(List.unmodifiable(_list));
  }

  @override
  Future<void> deleteMessage(String familyId, String messageId) async {
    deletedMessageIds.add(messageId);
  }

  @override
  Future<void> markAsRead(
    String familyId,
    String messageId,
    String userId,
  ) async {
    markAsReadIds.add(messageId);
  }

  @override
  Future<void> castVote(
    String familyId,
    String messageId,
    String userId,
    String option,
  ) async {}

  @override
  Future<void> closeMealVote(String familyId, String messageId) async {}

  @override
  Future<void> closePoll(String familyId, String messageId) async {}
}

List<Override> _chatOverrides({
  required _FakeChatRepository repo,
  ChatTestSession? session,
}) {
  return [
    currentFamilyProvider.overrideWithValue(AsyncValue.data(_testFamily)),
    chatRepositoryProvider.overrideWithValue(repo),
    chatTestSessionProvider.overrideWithValue(session),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatScreen 흐름', () {
    testWidgets('메시지가 없으면 안내 문구가 보인다', (tester) async {
      final repo = _FakeChatRepository([]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _chatOverrides(
            repo: repo,
            session: const ChatTestSession(uid: 'user-me', displayName: '나'),
          ),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('첫 메시지'), findsOneWidget);
      expect(find.textContaining('내보세요'), findsOneWidget);
    });

    testWidgets('메시지 목록과 입력창·전송이 렌더링된다', (tester) async {
      final messages = [
        _textMessage(
          id: 'm1',
          senderId: 'user-me',
          senderName: '나',
          content: '안녕하세요',
        ),
      ];
      final repo = _FakeChatRepository(messages);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _chatOverrides(
            repo: repo,
            session: const ChatTestSession(uid: 'user-me', displayName: '나'),
          ),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('안녕하세요'), findsOneWidget);
      expect(find.text('메시지를 입력하세요'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('텍스트 입력 후 전송하면 저장소로 전달되고 필드가 비워진다',
        (tester) async {
      final repo = _FakeChatRepository([
        _textMessage(
          id: 'm0',
          senderId: 'other',
          senderName: '상대',
          content: '기존',
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _chatOverrides(
            repo: repo,
            session: const ChatTestSession(uid: 'user-me', displayName: '나'),
          ),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '새 메시지');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(repo.sendCallCount, 1);
      expect(repo.lastSentContents, ['새 메시지']);
      expect(find.text('새 메시지'), findsOneWidget);
    });

    testWidgets('슬래시로 시작하면 커맨드 힌트와 제안 바가 나타난다', (tester) async {
      final repo = _FakeChatRepository([
        _textMessage(
          id: 'm1',
          senderId: 'user-me',
          senderName: '나',
          content: 'x',
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _chatOverrides(
            repo: repo,
            session: const ChatTestSession(uid: 'user-me', displayName: '나'),
          ),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '/');
      await tester.pump();

      expect(find.text('커맨드를 입력하세요'), findsOneWidget);
    });

    testWidgets('안 읽은 상대 메시지가 있으면 구분선 문구가 보인다', (tester) async {
      const me = 'user-me';
      final messages = [
        _textMessage(
          id: 'newest',
          senderId: 'other',
          senderName: '상대',
          content: '최신',
        ),
        _textMessage(
          id: 'oldest_unread',
          senderId: 'other',
          senderName: '상대',
          content: '가장 오래된 미읽음',
        ),
        _textMessage(
          id: 'read_old',
          senderId: 'other',
          senderName: '상대',
          content: '읽음',
          readBy: {me: DateTime(2026)},
        ),
      ];
      final repo = _FakeChatRepository(messages);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _chatOverrides(
            repo: repo,
            session: const ChatTestSession(uid: me, displayName: '나'),
          ),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('여기부터 새 메시지'), findsOneWidget);
    });

    testWidgets('맨 아래에서 멀리 스크롤하면 하단 이동 버튼이 나타난다', (tester) async {
      final messages = List.generate(
        45,
        (i) => _textMessage(
          id: 'm$i',
          senderId: 'other',
          senderName: '상대',
          content: '메시지 번호 $i',
          createdAt: DateTime(2026, 1, 1, 10, i),
        ),
      );
      final repo = _FakeChatRepository(messages);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _chatOverrides(
            repo: repo,
            session: const ChatTestSession(uid: 'user-me', displayName: '나'),
          ),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

      await tester.drag(
        find.byType(ListView),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('내 텍스트 메시지에 읽음 표시(체크)가 붙는다', (tester) async {
      final messages = [
        _textMessage(
          id: 'mine',
          senderId: 'user-me',
          senderName: '나',
          content: '보냄',
          readBy: const {},
        ),
      ];
      final repo = _FakeChatRepository(messages);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _chatOverrides(
            repo: repo,
            session: const ChatTestSession(uid: 'user-me', displayName: '나'),
          ),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\u2713'), findsOneWidget);
    });

    testWidgets('내 메시지에 다른 읽은 사람이 있으면 읽음 숫자가 붙는다', (tester) async {
      final messages = [
        _textMessage(
          id: 'mine',
          senderId: 'user-me',
          senderName: '나',
          content: '확인해줘',
          readBy: {
            'user-me': DateTime(2026),
            'other-a': DateTime(2026),
            'other-b': DateTime(2026),
          },
        ),
      ];
      final repo = _FakeChatRepository(messages);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _chatOverrides(
            repo: repo,
            session: const ChatTestSession(uid: 'user-me', displayName: '나'),
          ),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('읽음 2'), findsOneWidget);
    });
  });

  group('길게 누르기 메시지 액션', () {
    testWidgets('내 메시지: 복사와 삭제가 모두 제공된다', (tester) async {
      final messages = [
        _textMessage(
          id: 'own-msg',
          senderId: 'user-me',
          senderName: '나',
          content: '삭제 가능',
        ),
      ];
      final repo = _FakeChatRepository(messages);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _chatOverrides(
            repo: repo,
            session: const ChatTestSession(uid: 'user-me', displayName: '나'),
          ),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('삭제 가능'));
      await tester.pumpAndSettle();

      expect(find.text('복사'), findsOneWidget);
      expect(find.text('삭제'), findsOneWidget);

      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(repo.deletedMessageIds, ['own-msg']);
    });

    testWidgets('상대 메시지: 복사만 있고 삭제는 없다', (tester) async {
      final messages = [
        _textMessage(
          id: 'their-msg',
          senderId: 'stranger',
          senderName: '낯선 사람',
          content: '읽기만',
        ),
      ];
      final repo = _FakeChatRepository(messages);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _chatOverrides(
            repo: repo,
            session: const ChatTestSession(uid: 'user-me', displayName: '나'),
          ),
          child: const MaterialApp(
            locale: Locale('ko'),
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('읽기만'));
      await tester.pumpAndSettle();

      expect(find.text('복사'), findsOneWidget);
      expect(find.text('삭제'), findsNothing);
    });
  });
}
