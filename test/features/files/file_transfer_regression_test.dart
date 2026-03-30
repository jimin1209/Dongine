import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/files/domain/files_provider.dart';

void main() {
  // ─── FileTransferState 모델 회귀 ───

  group('FileTransferState 모델 회귀', () {
    test('기본 생성 시 progress 0.0, error null', () {
      const state = FileTransferState(
        fileName: 'a.txt',
        type: FileTransferType.upload,
        status: FileTransferStatus.inProgress,
      );
      expect(state.progress, 0.0);
      expect(state.error, isNull);
    });

    test('copyWith으로 status만 변경 시 나머지 필드 유지', () {
      const state = FileTransferState(
        fileName: 'b.pdf',
        type: FileTransferType.download,
        status: FileTransferStatus.inProgress,
        progress: 0.6,
      );
      final failed = state.copyWith(status: FileTransferStatus.failed);
      expect(failed.fileName, 'b.pdf');
      expect(failed.type, FileTransferType.download);
      expect(failed.progress, 0.6);
      expect(failed.status, FileTransferStatus.failed);
    });

    test('copyWith으로 error만 설정', () {
      const state = FileTransferState(
        fileName: 'c.zip',
        type: FileTransferType.upload,
        status: FileTransferStatus.failed,
      );
      final withError = state.copyWith(error: '서버 오류');
      expect(withError.error, '서버 오류');
      expect(withError.status, FileTransferStatus.failed);
    });
  });

  // ─── FileTransferNotifier 상태 전환 회귀 ───

  group('FileTransferNotifier 상태 전환 회귀', () {
    late FileTransferNotifier notifier;

    setUp(() {
      notifier = FileTransferNotifier();
    });

    test('fail 호출 시 state가 null이면 무시', () {
      notifier.fail('error');
      expect(notifier.state, isNull);
    });

    test('progress 경계값: 0.0 → 1.0', () {
      notifier.startTransfer('f.bin', FileTransferType.upload);
      expect(notifier.state!.progress, 0.0);

      notifier.updateProgress(1.0);
      expect(notifier.state!.progress, 1.0);
    });

    test('progress 소수점 정밀도 유지', () {
      notifier.startTransfer('f.bin', FileTransferType.upload);
      notifier.updateProgress(0.333);
      expect(notifier.state!.progress, 0.333);
    });

    test('upload 실패 후 재시도: 새 startTransfer로 상태 초기화', () {
      notifier.startTransfer('img.png', FileTransferType.upload);
      notifier.updateProgress(0.4);
      notifier.fail('timeout');

      // 실패 상태 확인
      expect(notifier.state!.status, FileTransferStatus.failed);
      expect(notifier.state!.error, 'timeout');
      expect(notifier.state!.progress, 0.4);

      // 재시도
      notifier.startTransfer('img.png', FileTransferType.upload);
      expect(notifier.state!.status, FileTransferStatus.inProgress);
      expect(notifier.state!.progress, 0.0);
      expect(notifier.state!.error, isNull);
    });

    test('download 실패 후 재시도: 새 startTransfer로 상태 초기화', () {
      notifier.startTransfer('video.mp4', FileTransferType.download);
      notifier.updateProgress(0.7);
      notifier.fail('네트워크 오류');

      expect(notifier.state!.status, FileTransferStatus.failed);

      // 재시도
      notifier.startTransfer('video.mp4', FileTransferType.download);
      expect(notifier.state!.status, FileTransferStatus.inProgress);
      expect(notifier.state!.progress, 0.0);
    });

    test('실패 상태에서 dismiss하면 state null', () {
      notifier.startTransfer('x.txt', FileTransferType.upload);
      notifier.fail('err');
      expect(notifier.state, isNotNull);

      notifier.dismiss();
      expect(notifier.state, isNull);
    });

    test('진행 중 dismiss하면 state null', () {
      notifier.startTransfer('x.txt', FileTransferType.download);
      notifier.updateProgress(0.5);
      notifier.dismiss();
      expect(notifier.state, isNull);
    });

    test('complete 후 다시 startTransfer 가능', () {
      notifier.startTransfer('a.txt', FileTransferType.upload);
      notifier.complete();
      expect(notifier.state, isNull);

      notifier.startTransfer('b.txt', FileTransferType.download);
      expect(notifier.state!.fileName, 'b.txt');
      expect(notifier.state!.type, FileTransferType.download);
    });

    test('연속 전송: 첫 번째 완료 후 두 번째 전송', () {
      notifier.startTransfer('first.txt', FileTransferType.upload);
      notifier.updateProgress(1.0);
      notifier.complete();

      notifier.startTransfer('second.txt', FileTransferType.download);
      notifier.updateProgress(0.5);
      expect(notifier.state!.fileName, 'second.txt');
      expect(notifier.state!.progress, 0.5);
    });

    test('실패 → 재시도 → 성공 전체 라이프사이클', () {
      // 1차 시도 실패
      notifier.startTransfer('doc.pdf', FileTransferType.upload);
      notifier.updateProgress(0.2);
      notifier.fail('서버 오류');
      expect(notifier.state!.status, FileTransferStatus.failed);

      // 재시도
      notifier.startTransfer('doc.pdf', FileTransferType.upload);
      expect(notifier.state!.progress, 0.0);

      notifier.updateProgress(0.5);
      notifier.updateProgress(1.0);
      notifier.complete();
      expect(notifier.state, isNull);
    });

    test('실패 → dismiss → 새 전송 시작', () {
      notifier.startTransfer('old.txt', FileTransferType.upload);
      notifier.fail('err');
      notifier.dismiss();

      notifier.startTransfer('new.txt', FileTransferType.download);
      expect(notifier.state!.fileName, 'new.txt');
      expect(notifier.state!.status, FileTransferStatus.inProgress);
    });
  });

  // ─── friendlyTransferError 순수 함수 회귀 ───

  group('friendlyTransferError', () {
    test('네트워크 오류 감지: network', () {
      expect(
        friendlyTransferError(Exception('NetworkError')),
        '네트워크 연결을 확인해주세요',
      );
    });

    test('네트워크 오류 감지: SocketException', () {
      expect(
        friendlyTransferError('SocketException: Connection refused'),
        '네트워크 연결을 확인해주세요',
      );
    });

    test('네트워크 오류 감지: connection', () {
      expect(
        friendlyTransferError('connection timed out'),
        '네트워크 연결을 확인해주세요',
      );
    });

    test('권한 오류 감지: permission', () {
      expect(
        friendlyTransferError('Permission denied'),
        '권한이 없습니다',
      );
    });

    test('권한 오류 감지: unauthorized', () {
      expect(
        friendlyTransferError('Unauthorized access'),
        '권한이 없습니다',
      );
    });

    test('권한 오류 감지: 403', () {
      expect(
        friendlyTransferError('HTTP 403 Forbidden'),
        '권한이 없습니다',
      );
    });

    test('용량 초과: quota', () {
      expect(
        friendlyTransferError('quota exceeded'),
        '저장 공간이 부족합니다',
      );
    });

    test('용량 초과: exceeded', () {
      expect(
        friendlyTransferError('storage limit exceeded'),
        '저장 공간이 부족합니다',
      );
    });

    test('파일 미발견: not found', () {
      expect(
        friendlyTransferError('File not found'),
        '파일을 찾을 수 없습니다',
      );
    });

    test('파일 미발견: 404', () {
      expect(
        friendlyTransferError('HTTP 404'),
        '파일을 찾을 수 없습니다',
      );
    });

    test('파일 미발견: object-not-found', () {
      expect(
        friendlyTransferError('[firebase_storage/object-not-found] No object'),
        '파일을 찾을 수 없습니다',
      );
    });

    test('Exception: 접두사 제거', () {
      final result = friendlyTransferError(Exception('custom error'));
      expect(result, 'custom error');
    });

    test('firebase_storage 접두사 제거', () {
      final result = friendlyTransferError(
          '[firebase_storage/unknown] Something went wrong');
      expect(result, 'Something went wrong');
    });

    test('100자 초과 메시지 잘림', () {
      final longMessage = 'A' * 200;
      final result = friendlyTransferError(longMessage);
      expect(result.length, 103); // 100 + '...'
      expect(result.endsWith('...'), true);
    });

    test('짧은 일반 메시지는 그대로 반환', () {
      final result = friendlyTransferError('some short error');
      expect(result, 'some short error');
    });
  });
}
