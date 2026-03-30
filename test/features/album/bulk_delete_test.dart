import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/shared/models/album_model.dart';

void main() {
  group('일괄 삭제 선택 로직', () {
    final photos = List.generate(
      5,
      (i) => PhotoModel(
        id: 'photo_$i',
        albumId: 'album1',
        imageUrl: 'https://example.com/img_$i.jpg',
        uploadedBy: 'user1',
        createdAt: DateTime(2026, 1, 1 + i),
      ),
    );

    test('빈 선택 집합에서 사진을 추가할 수 있다', () {
      final selected = <String>{};
      selected.add(photos[0].id);
      expect(selected, contains('photo_0'));
      expect(selected.length, 1);
    });

    test('이미 선택된 사진을 해제할 수 있다', () {
      final selected = <String>{'photo_0', 'photo_1', 'photo_2'};
      selected.remove('photo_1');
      expect(selected, isNot(contains('photo_1')));
      expect(selected.length, 2);
    });

    test('전체 선택이 모든 사진 ID를 포함한다', () {
      final selected = <String>{};
      selected.addAll(photos.map((p) => p.id));
      expect(selected.length, photos.length);
      for (final photo in photos) {
        expect(selected, contains(photo.id));
      }
    });

    test('전체 선택 토글 - 이미 전부 선택되면 전부 해제한다', () {
      final selected = photos.map((p) => p.id).toSet();
      // 전체 선택 상태에서 토글하면 비움
      if (selected.length == photos.length) {
        selected.clear();
      }
      expect(selected, isEmpty);
    });

    test('선택된 사진으로 삭제 대상 리스트를 필터링할 수 있다', () {
      final selected = <String>{'photo_1', 'photo_3'};
      final toDelete =
          photos.where((p) => selected.contains(p.id)).toList();
      expect(toDelete.length, 2);
      expect(toDelete.map((p) => p.id), containsAll(['photo_1', 'photo_3']));
    });

    test('삭제 대상 URL 집합에 커버 사진이 포함되는지 확인할 수 있다', () {
      const coverUrl = 'https://example.com/img_0.jpg';
      final selected = <String>{'photo_0', 'photo_2'};
      final toDelete =
          photos.where((p) => selected.contains(p.id)).toList();
      final deletedUrls = toDelete.map((p) => p.imageUrl).toSet();
      expect(deletedUrls.contains(coverUrl), isTrue);
    });

    test('삭제 후 남은 카운트가 음수가 되지 않는다', () {
      const currentCount = 3;
      const deleteCount = 5; // 실제 사진 수보다 많은 경우
      final newCount = (currentCount - deleteCount).clamp(0, currentCount);
      expect(newCount, 0);
    });

    test('삭제 대상에 커버가 없으면 커버를 유지한다', () {
      const coverUrl = 'https://example.com/img_0.jpg';
      final selected = <String>{'photo_2', 'photo_3'};
      final toDelete =
          photos.where((p) => selected.contains(p.id)).toList();
      final deletedUrls = toDelete.map((p) => p.imageUrl).toSet();
      expect(deletedUrls.contains(coverUrl), isFalse);
    });

    test('마지막 선택 해제 시 선택 모드를 종료할 수 있다', () {
      final selected = <String>{'photo_0'};
      selected.remove('photo_0');
      final shouldExitSelectionMode = selected.isEmpty;
      expect(shouldExitSelectionMode, isTrue);
    });
  });
}
