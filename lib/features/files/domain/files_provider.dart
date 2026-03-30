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

/// 검색 + 정렬 + 필터 적용된 파일 목록
final filesListProvider = Provider<AsyncValue<List<FileItemModel>>>((ref) {
  final rawAsync = ref.watch(_rawFilesListProvider);
  final query = ref.watch(filesSearchQueryProvider).toLowerCase();
  final sort = ref.watch(filesSortOptionProvider);
  final typeFilter = ref.watch(filesTypeFilterProvider);

  return rawAsync.whenData((items) {
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
    if (query.isNotEmpty) {
      filtered = filtered
          .where((f) => f.name.toLowerCase().contains(query))
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
  });
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

/// 스토리지 사용량
final storageUsageProvider = FutureProvider<int>((ref) async {
  final familyAsync = ref.watch(currentFamilyProvider);
  final repo = ref.watch(filesRepositoryProvider);

  final family = familyAsync.valueOrNull;
  if (family == null) return 0;

  return repo.getStorageUsage(family.id);
});
