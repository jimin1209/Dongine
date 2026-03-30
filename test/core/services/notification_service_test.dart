import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/core/services/notification_service.dart';

void main() {
  group('NotificationService.extractRoute', () {
    test(
      '규칙: data["route"]가 비어 있지 않은 String이고 /로 시작할 때만 그 문자열을 반환한다',
      () {
        expect(NotificationService.extractRoute({'route': '/ok'}), '/ok');
        expect(NotificationService.extractRoute({'route': ''}), isNull);
        expect(NotificationService.extractRoute({'route': 'relative'}), isNull);
        expect(NotificationService.extractRoute(const {}), isNull);
      },
    );

    test('유효: FCM에서 기대하는 주요 탭/기능 경로', () {
      expect(NotificationService.extractRoute({'route': '/chat'}), '/chat');
      expect(NotificationService.extractRoute({'route': '/calendar'}), '/calendar');
      expect(NotificationService.extractRoute({'route': '/todo'}), '/todo');
      expect(NotificationService.extractRoute({'route': '/cart'}), '/cart');
      expect(NotificationService.extractRoute({'route': '/expense'}), '/expense');
    });

    test('유효: 하위 경로 등 /로 시작하는 확장 경로도 그대로 통과한다', () {
      expect(
        NotificationService.extractRoute({'route': '/chat/room-1'}),
        '/chat/room-1',
      );
    });

    test('무효: 빈 문자열', () {
      expect(NotificationService.extractRoute({'route': ''}), isNull);
    });

    test('무효: 선행 슬래시 없음', () {
      expect(NotificationService.extractRoute({'route': 'chat'}), isNull);
      expect(NotificationService.extractRoute({'route': 'calendar'}), isNull);
      expect(NotificationService.extractRoute({'route': 'todo'}), isNull);
      expect(NotificationService.extractRoute({'route': ' /todo'}), isNull);
    });

    test('무효: route 키 없음', () {
      expect(NotificationService.extractRoute(const {}), isNull);
      expect(NotificationService.extractRoute({'type': 'todo'}), isNull);
    });

    test('무효: null', () {
      expect(NotificationService.extractRoute({'route': null}), isNull);
    });

    test('무효: 숫자·bool·List·Map 등 비문자열 타입', () {
      expect(NotificationService.extractRoute({'route': 0}), isNull);
      expect(NotificationService.extractRoute({'route': 42}), isNull);
      expect(NotificationService.extractRoute({'route': 3.14}), isNull);
      expect(NotificationService.extractRoute({'route': true}), isNull);
      expect(NotificationService.extractRoute({'route': <String, dynamic>{}}), isNull);
      expect(NotificationService.extractRoute({'route': <dynamic>[]}), isNull);
    });

    test('현재 동작: 루트만 "/" 인 경우도 통과한다', () {
      expect(NotificationService.extractRoute({'route': '/'}), '/');
    });

    test('현재 동작: 이중 슬래시로 시작해도 String이면 그대로 반환한다', () {
      expect(NotificationService.extractRoute({'route': '//chat'}), '//chat');
    });
  });
}
