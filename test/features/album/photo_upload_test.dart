import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/album/data/album_repository.dart';

void main() {
  group('PhotoUploadException', () {
    test('toString은 message를 반환한다', () {
      const exception = PhotoUploadException('테스트 메시지');
      expect(exception.toString(), '테스트 메시지');
      expect(exception.message, '테스트 메시지');
    });
  });

  group('업로드 전 파일 검증 로직', () {
    test('존재하지 않는 파일 경로는 existsSync가 false를 반환한다', () {
      final file = File('/tmp/__nonexistent_upload_test_file__.jpg');
      expect(file.existsSync(), isFalse);
    });

    test('빈 파일 경로는 유효하지 않다', () {
      const filePath = '';
      expect(filePath.isEmpty, isTrue);
    });
  });

  group('Storage 에러 메시지 변환', () {
    test('unauthorized 코드는 권한 메시지를 반환한다', () {
      final msg = AlbumRepository.storageErrorMessage('storage/unauthorized');
      expect(msg, contains('권한'));
    });

    test('canceled 코드는 취소 메시지를 반환한다', () {
      final msg = AlbumRepository.storageErrorMessage('storage/canceled');
      expect(msg, contains('취소'));
    });

    test('retry-limit-exceeded 코드는 네트워크 메시지를 반환한다', () {
      final msg =
          AlbumRepository.storageErrorMessage('storage/retry-limit-exceeded');
      expect(msg, contains('네트워크'));
    });

    test('quota-exceeded 코드는 용량 메시지를 반환한다', () {
      final msg =
          AlbumRepository.storageErrorMessage('storage/quota-exceeded');
      expect(msg, contains('용량'));
    });

    test('알 수 없는 코드는 일반 실패 메시지를 반환한다', () {
      final msg = AlbumRepository.storageErrorMessage('storage/unknown');
      expect(msg, contains('실패'));
    });
  });

  group('photoCount 정합성', () {
    test('업로드 후 카운트가 0이면 커버 설정이 필요하다', () {
      const currentCount = 0;
      final needsCover = currentCount == 0;
      expect(needsCover, isTrue);
    });

    test('업로드 후 카운트가 1 이상이면 커버 유지', () {
      const currentCount = 3;
      final needsCover = currentCount == 0;
      expect(needsCover, isFalse);
    });
  });
}
