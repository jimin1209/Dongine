import 'package:dongine/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthRepository.friendlyMessage', () {
    test('returns message for invalid-email', () {
      expect(
        AuthRepository.friendlyMessage('invalid-email'),
        '올바른 이메일 형식이 아닙니다.',
      );
    });

    test('returns message for user-not-found', () {
      expect(
        AuthRepository.friendlyMessage('user-not-found'),
        '등록되지 않은 이메일입니다.',
      );
    });

    test('returns message for wrong-password', () {
      expect(
        AuthRepository.friendlyMessage('wrong-password'),
        '비밀번호가 올바르지 않습니다.',
      );
    });

    test('returns message for invalid-credential', () {
      expect(
        AuthRepository.friendlyMessage('invalid-credential'),
        '이메일 또는 비밀번호가 올바르지 않습니다.',
      );
    });

    test('returns message for email-already-in-use', () {
      expect(
        AuthRepository.friendlyMessage('email-already-in-use'),
        '이미 사용 중인 이메일입니다.',
      );
    });

    test('returns message for weak-password', () {
      expect(
        AuthRepository.friendlyMessage('weak-password'),
        '비밀번호가 너무 약합니다. 6자 이상 입력해주세요.',
      );
    });

    test('returns message for too-many-requests', () {
      expect(
        AuthRepository.friendlyMessage('too-many-requests'),
        '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.',
      );
    });

    test('returns message for network-request-failed', () {
      expect(
        AuthRepository.friendlyMessage('network-request-failed'),
        '네트워크 연결을 확인해주세요.',
      );
    });

    test('returns generic message for unknown code', () {
      expect(
        AuthRepository.friendlyMessage('some-unknown-code'),
        '오류가 발생했습니다. 다시 시도해주세요.',
      );
    });
  });

  group('AuthException', () {
    test('toString returns message', () {
      const exception = AuthException('테스트 메시지');
      expect(exception.toString(), '테스트 메시지');
      expect(exception.message, '테스트 메시지');
    });
  });

  group('AuthRepository.validateDisplayName', () {
    test('returns trimmed name', () {
      expect(AuthRepository.validateDisplayName('  홍길동  '), '홍길동');
    });

    test('throws when empty after trim', () {
      expect(
        () => AuthRepository.validateDisplayName('   '),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', '표시 이름을 입력해주세요.')),
      );
    });

    test('throws when longer than 80 characters', () {
      final long = List.filled(81, 'a').join();
      expect(
        () => AuthRepository.validateDisplayName(long),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', '표시 이름은 80자 이내로 입력해주세요.')),
      );
    });

    test('allows exactly 80 characters', () {
      final s = List.filled(80, 'a').join();
      expect(AuthRepository.validateDisplayName(s), s);
    });
  });
}
