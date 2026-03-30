import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/files/data/files_repository.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/file_item_model.dart';

enum FilesSortOption { name, newest, oldest, largest }

enum FilesTypeFilter { all, foldersOnly, filesOnly }

final filesRepositoryProvider = Provider<FilesRepository>((ref) {
  return FilesRepository();
});

/// 현재 폴더 ID (null = 루트)
final currentFolderProvider = StateProvider<String?>((ref) => null);

/// 검색어
final filesSearchQueryProvider = StateProvider<String>((ref) => '');

/// 정렬 옵션
final filesSortOptionProvider =
    StateProvider<FilesSortOption>((ref) => FilesSortOption.name);

/// 타입 필터
final filesTypeFilterProvider =
    StateProvider<FilesTypeFilter>((ref) => FilesTypeFilter.all);

/// 현재 폴더의 원본 파일 목록 스트림
final _rawFilesListProvider = StreamProvider<List<FileItemModel>>((ref) {
  final familyAsync = ref.watch(currentFamilyProvider);
  final currentFolder = ref.watch(currentFolderProvider);
  final repo = ref.watch(filesRepositoryProvider);

  final family = familyAsync.valueOrNull;
  if (family == null) return Stream.value([]);

  return repo.getFilesStream(family.id, currentFolder);
});

/// 검색 + 정렬 + 타입 필터를 적용하는 순수 함수 (테스트 가능)
List<FileItemModel> applyFilesFilters({
  required List<FileItemModel> items,
  required String query,
  required FilesSortOption sort,
  required FilesTypeFilter typeFilter,
}) {
  var filtered = items.toList();

  // 타입 필터
  switch (typeFilter) {
    case FilesTypeFilter.foldersOnly:
      filtered = filtered.where((f) => f.isFolder).toList();
    case FilesTypeFilter.filesOnly:
      filtered = filtered.where((f) => f.isFile).toList();
    case FilesTypeFilter.all:
      break;
  }

  // 검색 필터
  final lowerQuery = query.toLowerCase();
  if (lowerQuery.isNotEmpty) {
    filtered = filtered
        .where((f) => f.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // 정렬 (폴더 우선 유지)
  filtered.sort((a, b) {
    if (a.isFolder && !b.isFolder) return -1;
    if (!a.isFolder && b.isFolder) return 1;
    switch (sort) {
      case FilesSortOption.name:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case FilesSortOption.newest:
        return b.createdAt.compareTo(a.createdAt);
      case FilesSortOption.oldest:
        return a.createdAt.compareTo(b.createdAt);
      case FilesSortOption.largest:
        return (b.size ?? 0).compareTo(a.size ?? 0);
    }
  });

  return filtered;
}

/// 검색 + 정렬 + 필터 적용된 파일 목록
final filesListProvider = Provider<AsyncValue<List<FileItemModel>>>((ref) {
  final rawAsync = ref.watch(_rawFilesListProvider);
  final query = ref.watch(filesSearchQueryProvider);
  final sort = ref.watch(filesSortOptionProvider);
  final typeFilter = ref.watch(filesTypeFilterProvider);

  return rawAsync.whenData((items) => applyFilesFilters(
        items: items,
        query: query,
        sort: sort,
        typeFilter: typeFilter,
      ));
});

/// 현재 폴더까지의 breadcrumb 경로
final breadcrumbProvider = FutureProvider<List<FileItemModel>>((ref) async {
  final familyAsync = ref.watch(currentFamilyProvider);
  final currentFolder = ref.watch(currentFolderProvider);
  final repo = ref.watch(filesRepositoryProvider);

  final family = familyAsync.valueOrNull;
  if (family == null) return [];

  return repo.buildBreadcrumb(family.id, currentFolder);
});

/// 현재 폴더의 원본(필터 미적용) 아이템 수 — 빈 폴더 vs 검색 결과 없음 구분용
final rawFilesCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(_rawFilesListProvider).whenData((items) => items.length);
});

/// 검색어 또는 타입 필터가 활성화되어 있는지 여부
final hasActiveFilterProvider = Provider<bool>((ref) {
  final query = ref.watch(filesSearchQueryProvider);
  final typeFilter = ref.watch(filesTypeFilterProvider);
  return query.isNotEmpty || typeFilter != FilesTypeFilter.all;
});

/// 스토리지 사용량
final storageUsageProvider = FutureProvider<int>((ref) async {
  final familyAsync = ref.watch(currentFamilyProvider);
  final repo = ref.watch(filesRepositoryProvider);

  final family = familyAsync.valueOrNull;
  if (family == null) return 0;

  return repo.getStorageUsage(family.id);
});

// ─── Transfer State ───

enum FileTransferType { upload, download }

enum FileTransferStatus { inProgress, completed, failed }

class FileTransferState {
  final String fileName;
  final FileTransferType type;
  final FileTransferStatus status;
  final double progress;
  final String? error;

  const FileTransferState({
    required this.fileName,
    required this.type,
    required this.status,
    this.progress = 0.0,
    this.error,
  });

  FileTransferState copyWith({
    FileTransferStatus? status,
    double? progress,
    String? error,
  }) {
    return FileTransferState(
      fileName: fileName,
      type: type,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

class FileTransferNotifier extends StateNotifier<FileTransferState?> {
  FileTransferNotifier() : super(null);

  void startTransfer(String fileName, FileTransferType type) {
    state = FileTransferState(
      fileName: fileName,
      type: type,
      status: FileTransferStatus.inProgress,
    );
  }

  void updateProgress(double progress) {
    if (state != null && state!.status == FileTransferStatus.inProgress) {
      state = state!.copyWith(progress: progress);
    }
  }

  void complete() {
    state = null;
  }

  void fail(String error) {
    if (state != null) {
      state = state!.copyWith(
        status: FileTransferStatus.failed,
        error: error,
      );
    }
  }

  void dismiss() {
    state = null;
  }
}

final fileTransferProvider =
    StateNotifierProvider<FileTransferNotifier, FileTransferState?>((ref) {
  return FileTransferNotifier();
});

/// 전송 오류를 사용자 친화적 메시지로 변환하는 순수 함수 (테스트 가능)
String friendlyTransferError(dynamic e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('network') ||
      msg.contains('socketexception') ||
      msg.contains('connection')) {
    return '네트워크 연결을 확인해주세요';
  }
  if (msg.contains('permission') ||
      msg.contains('unauthorized') ||
      msg.contains('403')) {
    return '권한이 없습니다';
  }
  if (msg.contains('quota') || msg.contains('exceeded')) {
    return '저장 공간이 부족합니다';
  }
  if (msg.contains('not found') ||
      msg.contains('404') ||
      msg.contains('object-not-found')) {
    return '파일을 찾을 수 없습니다';
  }
  final raw = e.toString();
  final clean = raw
      .replaceAll('Exception: ', '')
      .replaceAll(RegExp(r'^\[firebase_storage/[^\]]+\]\s*'), '');
  return clean.length > 100 ? '${clean.substring(0, 100)}...' : clean;
}
