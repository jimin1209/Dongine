import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/files/data/files_repository.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/file_item_model.dart';

final filesRepositoryProvider = Provider<FilesRepository>((ref) {
  return FilesRepository();
});

/// 현재 폴더 ID (null = 루트)
final currentFolderProvider = StateProvider<String?>((ref) => null);

/// 현재 폴더의 파일 목록 스트림
final filesListProvider = StreamProvider<List<FileItemModel>>((ref) {
  final familyAsync = ref.watch(currentFamilyProvider);
  final currentFolder = ref.watch(currentFolderProvider);
  final repo = ref.watch(filesRepositoryProvider);

  final family = familyAsync.valueOrNull;
  if (family == null) return Stream.value([]);

  return repo.getFilesStream(family.id, currentFolder);
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
