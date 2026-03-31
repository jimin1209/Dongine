import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/core/services/notification_service.dart';

void main() {
  group('NotificationService.extractRoute', () {
    test('유효한 route 를 그대로 반환한다', () {
      expect(NotificationService.extractRoute({'route': '/chat'}), '/chat');
      expect(
        NotificationService.extractRoute({'route': '/calendar'}),
        '/calendar',
      );
      expect(NotificationService.extractRoute({'route': '/todo'}), '/todo');
      expect(NotificationService.extractRoute({'route': '/cart'}), '/cart');
      expect(
        NotificationService.extractRoute({'route': '/expense'}),
        '/expense',
      );
      expect(NotificationService.extractRoute({'route': '/home'}), '/home');
    });

    test('허용 목록에 없는 route 는 null', () {
      expect(NotificationService.extractRoute({'route': '/unknown'}), isNull);
      expect(NotificationService.extractRoute({'route': '/settings'}), isNull);
      expect(NotificationService.extractRoute({'route': '/login'}), isNull);
      expect(NotificationService.extractRoute({'route': '/splash'}), isNull);
      expect(NotificationService.extractRoute({'route': '/album'}), isNull);
      expect(NotificationService.extractRoute({'route': '/iot'}), isNull);
      expect(NotificationService.extractRoute({'route': '/map'}), isNull);
      expect(NotificationService.extractRoute({'route': '/files'}), isNull);
    });

    test('빈 문자열은 null', () {
      expect(NotificationService.extractRoute({'route': ''}), isNull);
    });

    test('선행 슬래시 없으면 null', () {
      expect(NotificationService.extractRoute({'route': 'chat'}), isNull);
      expect(NotificationService.extractRoute({'route': 'calendar'}), isNull);
      expect(NotificationService.extractRoute({'route': ' /todo'}), isNull);
    });

    test('route 키가 없으면 null', () {
      expect(NotificationService.extractRoute(const {}), isNull);
      expect(NotificationService.extractRoute({'type': 'todo'}), isNull);
    });

    test('null 값은 null', () {
      expect(NotificationService.extractRoute({'route': null}), isNull);
    });

    test('비문자열 타입은 null', () {
      expect(NotificationService.extractRoute({'route': 0}), isNull);
      expect(NotificationService.extractRoute({'route': 42}), isNull);
      expect(NotificationService.extractRoute({'route': 3.14}), isNull);
      expect(NotificationService.extractRoute({'route': true}), isNull);
      expect(
        NotificationService.extractRoute({'route': <String, dynamic>{}}),
        isNull,
      );
      expect(
        NotificationService.extractRoute({'route': <dynamic>[]}),
        isNull,
      );
    });

    test('"/" 만 있으면 null (빈 route 취급)', () {
      expect(NotificationService.extractRoute({'route': '/'}), isNull);
    });

    test('이중 슬래시 "//chat" 은 "/chat" 으로 정규화한다', () {
      expect(
        NotificationService.extractRoute({'route': '//chat'}),
        '/chat',
      );
    });

    test('후행 슬래시 "/chat/" 은 "/chat" 으로 정규화한다', () {
      expect(
        NotificationService.extractRoute({'route': '/chat/'}),
        '/chat',
      );
    });

    test('하위 경로 "/chat/room-1" 는 허용 목록에 없으므로 null', () {
      expect(
        NotificationService.extractRoute({'route': '/chat/room-1'}),
        isNull,
      );
    });
  });

  group('NotificationService.buildForegroundMessageBody', () {
    test('알려진 type 은 친화적 메시지를 반환한다', () {
      expect(
        NotificationService.buildForegroundMessageBody(
          {'type': 'chat_message'},
        ),
        '새 메시지가 도착했어요.',
      );
      expect(
        NotificationService.buildForegroundMessageBody(
          {'type': 'calendar_event'},
        ),
        '새 일정이 등록되었어요.',
      );
      expect(
        NotificationService.buildForegroundMessageBody(
          {'type': 'todo_created'},
        ),
        '새 할 일이 추가되었어요.',
      );
      expect(
        NotificationService.buildForegroundMessageBody(
          {'type': 'cart_item_created'},
        ),
        '장보기 목록이 업데이트되었어요.',
      );
      expect(
        NotificationService.buildForegroundMessageBody(
          {'type': 'expense_created'},
        ),
        '새 지출이 기록되었어요.',
      );
    });

    test('알 수 없는 type 은 일반 메시지를 반환한다', () {
      expect(
        NotificationService.buildForegroundMessageBody(
          {'type': 'unknown_type'},
        ),
        '새 알림이 도착했어요.',
      );
    });

    test('type 이 없으면 일반 메시지를 반환한다', () {
      expect(
        NotificationService.buildForegroundMessageBody(const {}),
        '새 알림이 도착했어요.',
      );
    });
  });

  group('kDeeplinkAllowedRoutes', () {
    test('알림 빌더가 사용하는 모든 route 가 허용 목록에 있다', () {
      const expectedRoutes = [
        '/chat',
        '/calendar',
        '/todo',
        '/cart',
        '/expense',
        '/home',
      ];
      for (final route in expectedRoutes) {
        expect(
          kDeeplinkAllowedRoutes.contains(route),
          isTrue,
          reason: '$route 가 kDeeplinkAllowedRoutes 에 포함되어야 합니다',
        );
      }
    });
  });
}
