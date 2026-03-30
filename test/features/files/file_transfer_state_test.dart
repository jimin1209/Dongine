import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/files/domain/files_provider.dart';

void main() {
  group('FileTransferState', () {
    test('copyWith preserves unchanged fields', () {
      const state = FileTransferState(
        fileName: 'photo.jpg',
        type: FileTransferType.upload,
        status: FileTransferStatus.inProgress,
        progress: 0.5,
      );

      final updated = state.copyWith(progress: 0.8);

      expect(updated.fileName, 'photo.jpg');
      expect(updated.type, FileTransferType.upload);
      expect(updated.status, FileTransferStatus.inProgress);
      expect(updated.progress, 0.8);
      expect(updated.error, isNull);
    });

    test('copyWith updates status and error', () {
      const state = FileTransferState(
        fileName: 'doc.pdf',
        type: FileTransferType.download,
        status: FileTransferStatus.inProgress,
      );

      final failed = state.copyWith(
        status: FileTransferStatus.failed,
        error: '네트워크 오류',
      );

      expect(failed.status, FileTransferStatus.failed);
      expect(failed.error, '네트워크 오류');
      expect(failed.fileName, 'doc.pdf');
      expect(failed.type, FileTransferType.download);
    });
  });

  group('FileTransferNotifier', () {
    late FileTransferNotifier notifier;

    setUp(() {
      notifier = FileTransferNotifier();
    });

    test('initial state is null', () {
      expect(notifier.state, isNull);
    });

    test('startTransfer sets inProgress state', () {
      notifier.startTransfer('test.txt', FileTransferType.upload);

      final state = notifier.state!;
      expect(state.fileName, 'test.txt');
      expect(state.type, FileTransferType.upload);
      expect(state.status, FileTransferStatus.inProgress);
      expect(state.progress, 0.0);
    });

    test('updateProgress updates progress value', () {
      notifier.startTransfer('test.txt', FileTransferType.upload);
      notifier.updateProgress(0.5);

      expect(notifier.state!.progress, 0.5);
    });

    test('updateProgress is ignored when no active transfer', () {
      notifier.updateProgress(0.5);
      expect(notifier.state, isNull);
    });

    test('updateProgress is ignored after failure', () {
      notifier.startTransfer('test.txt', FileTransferType.upload);
      notifier.fail('error');
      notifier.updateProgress(0.9);

      expect(notifier.state!.progress, 0.0);
      expect(notifier.state!.status, FileTransferStatus.failed);
    });

    test('complete clears state', () {
      notifier.startTransfer('test.txt', FileTransferType.upload);
      notifier.updateProgress(1.0);
      notifier.complete();

      expect(notifier.state, isNull);
    });

    test('fail sets error state', () {
      notifier.startTransfer('video.mp4', FileTransferType.download);
      notifier.fail('네트워크 연결을 확인해주세요');

      final state = notifier.state!;
      expect(state.status, FileTransferStatus.failed);
      expect(state.error, '네트워크 연결을 확인해주세요');
      expect(state.fileName, 'video.mp4');
    });

    test('dismiss clears state regardless of status', () {
      notifier.startTransfer('test.txt', FileTransferType.upload);
      notifier.fail('error');
      notifier.dismiss();

      expect(notifier.state, isNull);
    });

    test('startTransfer for download type', () {
      notifier.startTransfer('report.pdf', FileTransferType.download);

      final state = notifier.state!;
      expect(state.type, FileTransferType.download);
      expect(state.status, FileTransferStatus.inProgress);
    });

    test('full upload lifecycle', () {
      notifier.startTransfer('image.png', FileTransferType.upload);
      expect(notifier.state!.status, FileTransferStatus.inProgress);

      notifier.updateProgress(0.25);
      expect(notifier.state!.progress, 0.25);

      notifier.updateProgress(0.75);
      expect(notifier.state!.progress, 0.75);

      notifier.complete();
      expect(notifier.state, isNull);
    });

    test('full retry lifecycle', () {
      notifier.startTransfer('data.csv', FileTransferType.upload);
      notifier.updateProgress(0.3);
      notifier.fail('timeout');

      expect(notifier.state!.status, FileTransferStatus.failed);
      expect(notifier.state!.error, 'timeout');

      // Retry
      notifier.startTransfer('data.csv', FileTransferType.upload);
      expect(notifier.state!.status, FileTransferStatus.inProgress);
      expect(notifier.state!.progress, 0.0);

      notifier.updateProgress(1.0);
      notifier.complete();
      expect(notifier.state, isNull);
    });
  });
}
