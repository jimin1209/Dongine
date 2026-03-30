import 'package:dongine/shared/models/album_model.dart';

/// 선택 모드 진입 결과
class SelectionModeEntry {
  final bool isSelectionMode;
  final Set<String> selectedIds;

  const SelectionModeEntry({
    required this.isSelectionMode,
    required this.selectedIds,
  });
}

/// 롱프레스로 선택 모드에 진입한다.
/// 이미 선택 모드이면 아무 변화 없이 현재 상태를 그대로 돌려준다.
SelectionModeEntry enterSelectionMode({
  required bool isSelectionMode,
  required Set<String> currentSelection,
  required String photoId,
}) {
  if (isSelectionMode) {
    return SelectionModeEntry(
      isSelectionMode: true,
      selectedIds: Set.of(currentSelection),
    );
  }
  return SelectionModeEntry(
    isSelectionMode: true,
    selectedIds: {photoId},
  );
}

/// 선택 모드에서 사진을 탭했을 때 토글 결과를 반환한다.
/// 마지막 선택이 해제되면 선택 모드를 종료한다.
SelectionModeEntry togglePhotoSelection({
  required Set<String> currentSelection,
  required String photoId,
}) {
  final next = Set.of(currentSelection);
  if (next.contains(photoId)) {
    next.remove(photoId);
  } else {
    next.add(photoId);
  }
  return SelectionModeEntry(
    isSelectionMode: next.isNotEmpty,
    selectedIds: next,
  );
}

/// 전체 선택 토글: 전부 선택 상태이면 전부 해제, 아니면 전부 선택.
Set<String> toggleSelectAll({
  required Set<String> currentSelection,
  required List<String> allPhotoIds,
}) {
  if (currentSelection.length == allPhotoIds.length &&
      currentSelection.containsAll(allPhotoIds)) {
    return {};
  }
  return Set.of(allPhotoIds);
}

/// 일괄 삭제 후 앨범 사진 수를 계산한다.
int computeCountAfterBulkDelete({
  required int currentCount,
  required int deleteCount,
}) {
  return (currentCount - deleteCount).clamp(0, currentCount);
}

/// 일괄 삭제 후 커버 사진을 결정한다.
/// 반환값이 null이면 커버를 제거해야 한다.
/// [remainingPhotos] 는 삭제 대상이 제거된 뒤 최신순 정렬된 나머지 사진.
String? computeCoverAfterBulkDelete({
  required String? currentCoverUrl,
  required Set<String> deletedUrls,
  required List<PhotoModel> remainingPhotos,
}) {
  final isCoverDeleted =
      currentCoverUrl != null && deletedUrls.contains(currentCoverUrl);

  if (remainingPhotos.isEmpty) return null;
  if (isCoverDeleted) return remainingPhotos.first.imageUrl;
  return currentCoverUrl;
}

/// 선택된 사진 ID 로 삭제 대상 리스트를 필터링한다.
List<PhotoModel> filterSelectedPhotos({
  required List<PhotoModel> photos,
  required Set<String> selectedIds,
}) {
  return photos.where((p) => selectedIds.contains(p.id)).toList();
}

/// 선택 상태 앱바 타이틀 텍스트
String selectionTitle(int count) => '$count장 선택';
