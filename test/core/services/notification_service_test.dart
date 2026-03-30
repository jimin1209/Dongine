import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/core/services/notification_service.dart';

void main() {
  test('알림 데이터에서 유효한 라우트만 추출한다', () {
    expect(NotificationService.extractRoute({'route': '/chat'}), '/chat');
    expect(NotificationService.extractRoute({'route': 'chat'}), isNull);
    expect(NotificationService.extractRoute({'route': ''}), isNull);
    expect(NotificationService.extractRoute(const {}), isNull);
  });
}
