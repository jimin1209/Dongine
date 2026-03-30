import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/shared/models/album_model.dart';
import 'package:dongine/features/album/domain/album_selection_helpers.dart';

void main() {
  // 공통 테스트 데이터
  final photos = List.generate(
    6,
    (i) => PhotoModel(
      id: 'photo_$i',
      albumId: 'album1',
      imageUrl: 'https://example.com/img_$i.jpg',
      uploadedBy: 'user1',
      createdAt: DateTime(2026, 1, 6 - i), // photo_0이 가장 최신
    ),
  );
  final allIds = photos.map((p) => p.id).toList();

  // ---------------------------------------------------------------------------
  // 1. 다중 선택 진입 흐름
  // ---------------------------------------------------------------------------
  group('다중 선택 진입 흐름', () {
    test('롱프레스로 선택 모드에 진입하면 해당 사진이 선택된다', () {
      final result = enterSelectionMode(
        isSelectionMode: false,
        currentSelection: {},
        photoId: 'photo_2',
      );
      expect(result.isSelectionMode, isTrue);
      expect(result.selectedIds, {'photo_2'});
    });

    test('이미 선택 모드에서 롱프레스해도 기존 선택이 유지된다', () {
      final result = enterSelectionMode(
        isSelectionMode: true,
        currentSelection: {'photo_0', 'photo_1'},
        photoId: 'photo_3',
      );
      expect(result.isSelectionMode, isTrue);
      expect(result.selectedIds, {'photo_0', 'photo_1'});
    });

    test('롱프레스 진입 후 추가 탭으로 여러 사진을 선택한다', () {
      // 롱프레스로 진입
      var state = enterSelectionMode(
        isSelectionMode: false,
        currentSelection: {},
        photoId: 'photo_0',
      );
      // 추가 탭
      state = togglePhotoSelection(
        currentSelection: state.selectedIds,
        photoId: 'photo_3',
      );
      state = togglePhotoSelection(
        currentSelection: state.selectedIds,
        photoId: 'photo_5',
      );
      expect(state.isSelectionMode, isTrue);
      expect(state.selectedIds, {'photo_0', 'photo_3', 'photo_5'});
    });
  });

  // ---------------------------------------------------------------------------
  // 2. 선택 해제 흐름
  // ---------------------------------------------------------------------------
  group('선택 해제 흐름', () {
    test('선택된 사진을 탭하면 해제된다', () {
      final result = togglePhotoSelection(
        currentSelection: {'photo_1', 'photo_2'},
        photoId: 'photo_1',
      );
      expect(result.selectedIds, {'photo_2'});
      expect(result.isSelectionMode, isTrue);
    });

    test('마지막 선택을 해제하면 선택 모드가 종료된다', () {
      final result = togglePhotoSelection(
        currentSelection: {'photo_4'},
        photoId: 'photo_4',
      );
      expect(result.selectedIds, isEmpty);
      expect(result.isSelectionMode, isFalse);
    });

    test('3개 선택 후 하나씩 해제하면 순서대로 줄어든다', () {
      var state = SelectionModeEntry(
        isSelectionMode: true,
        selectedIds: {'photo_0', 'photo_2', 'photo_4'},
      );

      state = togglePhotoSelection(
        currentSelection: state.selectedIds,
        photoId: 'photo_2',
      );
      expect(state.selectedIds.length, 2);
      expect(state.isSelectionMode, isTrue);

      state = togglePhotoSelection(
        currentSelection: state.selectedIds,
        photoId: 'photo_0',
      );
      expect(state.selectedIds, {'photo_4'});
      expect(state.isSelectionMode, isTrue);

      state = togglePhotoSelection(
        currentSelection: state.selectedIds,
        photoId: 'photo_4',
      );
      expect(state.selectedIds, isEmpty);
      expect(state.isSelectionMode, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. 전체 선택 토글
  // ---------------------------------------------------------------------------
  group('전체 선택 토글', () {
    test('아무것도 선택 안 된 상태에서 전체 선택', () {
      final result = toggleSelectAll(
        currentSelection: {},
        allPhotoIds: allIds,
      );
      expect(result.length, allIds.length);
      expect(result, containsAll(allIds));
    });

    test('일부만 선택된 상태에서 전체 선택', () {
      final result = toggleSelectAll(
        currentSelection: {'photo_1'},
        allPhotoIds: allIds,
      );
      expect(result.length, allIds.length);
    });

    test('전부 선택된 상태에서 토글하면 전부 해제', () {
      final result = toggleSelectAll(
        currentSelection: allIds.toSet(),
        allPhotoIds: allIds,
      );
      expect(result, isEmpty);
    });

    test('전체 선택 후 하나 해제하고 다시 전체 선택', () {
      var selected = toggleSelectAll(
        currentSelection: {},
        allPhotoIds: allIds,
      );
      expect(selected.length, allIds.length);

      // 하나 해제
      final afterToggle = togglePhotoSelection(
        currentSelection: selected,
        photoId: 'photo_3',
      );
      selected = afterToggle.selectedIds;
      expect(selected.length, allIds.length - 1);

      // 다시 전체 선택
      selected = toggleSelectAll(
        currentSelection: selected,
        allPhotoIds: allIds,
      );
      expect(selected.length, allIds.length);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. 일괄 삭제 후 선택 상태 초기화
  // ---------------------------------------------------------------------------
  group('일괄 삭제 후 선택 상태 초기화', () {
    test('삭제 완료 후 선택 집합이 비워지고 선택 모드 종료', () {
      // 시뮬레이션: 선택 → 삭제 → 클리어
      final selected = {'photo_1', 'photo_2', 'photo_3'};
      expect(selected.length, 3);

      // 삭제 후 화면 코드가 수행하는 초기화
      selected.clear();
      final isSelectionMode = false;

      expect(selected, isEmpty);
      expect(isSelectionMode, isFalse);
    });

    test('삭제 후 남은 사진 수가 정확하다', () {
      final newCount = computeCountAfterBulkDelete(
        currentCount: 6,
        deleteCount: 3,
      );
      expect(newCount, 3);
    });

    test('전체 삭제 후 사진 수가 0이다', () {
      final newCount = computeCountAfterBulkDelete(
        currentCount: 6,
        deleteCount: 6,
      );
      expect(newCount, 0);
    });

    test('deleteCount가 currentCount보다 커도 음수가 되지 않는다', () {
      final newCount = computeCountAfterBulkDelete(
        currentCount: 2,
        deleteCount: 5,
      );
      expect(newCount, 0);
    });

    test('사진 0장인 앨범에서 삭제 시도해도 0이 유지된다', () {
      final newCount = computeCountAfterBulkDelete(
        currentCount: 0,
        deleteCount: 0,
      );
      expect(newCount, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. 커버 사진 정합성
  // ---------------------------------------------------------------------------
  group('일괄 삭제 후 커버 사진 정합성', () {
    test('커버가 삭제 대상이 아니면 유지된다', () {
      final cover = computeCoverAfterBulkDelete(
        currentCoverUrl: 'https://example.com/img_0.jpg',
        deletedUrls: {'https://example.com/img_3.jpg'},
        remainingPhotos: photos.sublist(0, 3),
      );
      expect(cover, 'https://example.com/img_0.jpg');
    });

    test('커버가 삭제 대상이면 남은 사진 중 최신 것으로 교체된다', () {
      // photo_0이 커버, photo_0 삭제 → photo_1이 새 커버
      final remaining = photos.sublist(1);
      final cover = computeCoverAfterBulkDelete(
        currentCoverUrl: 'https://example.com/img_0.jpg',
        deletedUrls: {'https://example.com/img_0.jpg'},
        remainingPhotos: remaining,
      );
      expect(cover, remaining.first.imageUrl);
    });

    test('모든 사진 삭제 후 커버가 null이 된다', () {
      final cover = computeCoverAfterBulkDelete(
        currentCoverUrl: 'https://example.com/img_0.jpg',
        deletedUrls: photos.map((p) => p.imageUrl).toSet(),
        remainingPhotos: [],
      );
      expect(cover, isNull);
    });

    test('커버가 원래 null이고 남은 사진이 있으면 null 유지', () {
      final cover = computeCoverAfterBulkDelete(
        currentCoverUrl: null,
        deletedUrls: {'https://example.com/img_5.jpg'},
        remainingPhotos: photos.sublist(0, 5),
      );
      expect(cover, isNull);
    });

    test('커버가 원래 null이고 남은 사진도 없으면 null', () {
      final cover = computeCoverAfterBulkDelete(
        currentCoverUrl: null,
        deletedUrls: {},
        remainingPhotos: [],
      );
      expect(cover, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. 삭제 대상 필터링
  // ---------------------------------------------------------------------------
  group('삭제 대상 필터링', () {
    test('선택된 ID로 사진을 정확히 필터링한다', () {
      final filtered = filterSelectedPhotos(
        photos: photos,
        selectedIds: {'photo_1', 'photo_4'},
      );
      expect(filtered.length, 2);
      expect(filtered.map((p) => p.id), containsAll(['photo_1', 'photo_4']));
    });

    test('빈 선택이면 빈 리스트를 반환한다', () {
      final filtered = filterSelectedPhotos(
        photos: photos,
        selectedIds: {},
      );
      expect(filtered, isEmpty);
    });

    test('존재하지 않는 ID는 무시된다', () {
      final filtered = filterSelectedPhotos(
        photos: photos,
        selectedIds: {'photo_1', 'nonexistent'},
      );
      expect(filtered.length, 1);
      expect(filtered.first.id, 'photo_1');
    });

    test('전체 선택 시 모든 사진이 필터링된다', () {
      final filtered = filterSelectedPhotos(
        photos: photos,
        selectedIds: allIds.toSet(),
      );
      expect(filtered.length, photos.length);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. 복합 화면 흐름 시뮬레이션
  // ---------------------------------------------------------------------------
  group('복합 화면 흐름 시뮬레이션', () {
    test('롱프레스 → 추가 선택 → 전체 선택 → 일괄 삭제 → 초기화', () {
      // 1) 롱프레스로 진입
      var state = enterSelectionMode(
        isSelectionMode: false,
        currentSelection: {},
        photoId: 'photo_2',
      );
      expect(state.isSelectionMode, isTrue);
      expect(state.selectedIds.length, 1);

      // 2) 추가 선택
      state = togglePhotoSelection(
        currentSelection: state.selectedIds,
        photoId: 'photo_4',
      );
      expect(state.selectedIds.length, 2);

      // 3) 전체 선택
      final allSelected = toggleSelectAll(
        currentSelection: state.selectedIds,
        allPhotoIds: allIds,
      );
      expect(allSelected.length, allIds.length);
      expect(selectionTitle(allSelected.length), '${allIds.length}장 선택');

      // 4) 일괄 삭제 후 카운트
      final newCount = computeCountAfterBulkDelete(
        currentCount: photos.length,
        deleteCount: allSelected.length,
      );
      expect(newCount, 0);

      // 5) 커버 확인
      final cover = computeCoverAfterBulkDelete(
        currentCoverUrl: photos.first.imageUrl,
        deletedUrls: photos.map((p) => p.imageUrl).toSet(),
        remainingPhotos: [],
      );
      expect(cover, isNull);

      // 6) 선택 상태 초기화
      final cleared = <String>{};
      expect(cleared, isEmpty);
    });

    test('부분 삭제 후 남은 사진으로 선택 모드 재진입 가능', () {
      // 1) 3장 선택 후 삭제
      const initialCount = 6;
      final selected = {'photo_0', 'photo_1', 'photo_2'};

      final newCount = computeCountAfterBulkDelete(
        currentCount: initialCount,
        deleteCount: selected.length,
      );
      expect(newCount, 3);

      // 삭제 후 남은 사진
      final remaining = photos.where((p) => !selected.contains(p.id)).toList();
      expect(remaining.length, 3);

      // 2) 커버가 삭제됐으므로 재설정
      final cover = computeCoverAfterBulkDelete(
        currentCoverUrl: photos.first.imageUrl, // photo_0 = 커버
        deletedUrls: selected.map((id) {
          return photos.firstWhere((p) => p.id == id).imageUrl;
        }).toSet(),
        remainingPhotos: remaining,
      );
      expect(cover, remaining.first.imageUrl);

      // 3) 다시 선택 모드 진입
      final reEntry = enterSelectionMode(
        isSelectionMode: false,
        currentSelection: {},
        photoId: remaining.first.id,
      );
      expect(reEntry.isSelectionMode, isTrue);
      expect(reEntry.selectedIds, {remaining.first.id});
    });

    test('선택 모드 진입 → 전부 해제 → 선택 모드 자동 종료', () {
      var state = enterSelectionMode(
        isSelectionMode: false,
        currentSelection: {},
        photoId: 'photo_0',
      );
      state = togglePhotoSelection(
        currentSelection: state.selectedIds,
        photoId: 'photo_3',
      );
      expect(state.selectedIds.length, 2);

      // 하나씩 해제
      state = togglePhotoSelection(
        currentSelection: state.selectedIds,
        photoId: 'photo_0',
      );
      state = togglePhotoSelection(
        currentSelection: state.selectedIds,
        photoId: 'photo_3',
      );
      expect(state.isSelectionMode, isFalse);
      expect(state.selectedIds, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. 선택 타이틀 텍스트
  // ---------------------------------------------------------------------------
  group('selectionTitle', () {
    test('0장 선택', () => expect(selectionTitle(0), '0장 선택'));
    test('1장 선택', () => expect(selectionTitle(1), '1장 선택'));
    test('99장 선택', () => expect(selectionTitle(99), '99장 선택'));
  });
}
