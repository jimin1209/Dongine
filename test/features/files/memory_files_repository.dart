import 'dart:async';

import 'package:dongine/features/files/data/files_repository.dart';
import 'package:dongine/shared/models/file_item_model.dart';

/// Firestore 없이 [FilesRepository] 계약(부모 ID·재귀 삭제·목록 정렬)을 동일하게 따르는 테스트 더블.
class MemoryFilesRepository implements FilesRepository {
  final Map<String, Map<String, FileItemModel>> _itemsByFamily = {};
  final StreamController<void> _updates = StreamController<void>.broadcast();
  int _idSeq = 0;

  Map<String, FileItemModel> _items(String familyId) =>
      _itemsByFamily.putIfAbsent(familyId, () => {});

  void _notify() {
    if (!_updates.isClosed) {
      _updates.add(null);
    }
  }

  String _newId() => 'mem-${++_idSeq}';

  List<FileItemModel> _sorted(String familyId, String? parentId) {
    final items = _items(familyId)
        .values
        .where((i) => i.parentId == parentId)
        .toList();
    items.sort((a, b) {
      if (a.isFolder && !b.isFolder) return -1;
      if (!a.isFolder && b.isFolder) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  /// 업로드 없이 파일/폴더 노드를 넣어 move·delete 흐름만 검증할 때 사용한다.
  void seedItem(String familyId, FileItemModel item) {
    _items(familyId)[item.id] = item;
    _notify();
  }

  /// 테스트 종료 시 구독 해제 후 호출하면 스트림 리스너가 대기하지 않도록 할 수 있다.
  void dispose() {
    _updates.close();
  }

  @override
  Stream<List<FileItemModel>> getFilesStream(
    String familyId,
    String? parentId,
  ) async* {
    yield _sorted(familyId, parentId);
    await for (final _ in _updates.stream) {
      yield _sorted(familyId, parentId);
    }
  }

  @override
  Future<FileItemModel> createFolder(
    String familyId,
    String name,
    String? parentId,
    String userId,
  ) async {
    final now = DateTime.now();
    final id = _newId();
    final folder = FileItemModel(
      id: id,
      name: name,
      type: 'folder',
      parentId: parentId,
      uploadedBy: userId,
      createdAt: now,
      updatedAt: now,
    );
    _items(familyId)[id] = folder;
    _notify();
    return folder;
  }

  @override
  Future<void> deleteItem(String familyId, String fileId) async {
    final item = _items(familyId)[fileId];
    if (item == null) return;
    if (item.isFolder) {
      await _deleteFolderRecursive(familyId, fileId);
    }
    _items(familyId).remove(fileId);
    _notify();
  }

  Future<void> _deleteFolderRecursive(String familyId, String folderId) async {
    final children = _items(familyId)
        .values
        .where((i) => i.parentId == folderId)
        .toList();
    for (final child in children) {
      if (child.isFolder) {
        await _deleteFolderRecursive(familyId, child.id);
      }
      _items(familyId).remove(child.id);
    }
  }

  @override
  Future<FileItemModel?> getItem(String familyId, String fileId) async =>
      _items(familyId)[fileId];

  @override
  Future<List<FileItemModel>> buildBreadcrumb(
    String familyId,
    String? folderId,
  ) async {
    final path = <FileItemModel>[];
    String? currentId = folderId;
    while (currentId != null) {
      final item = await getItem(familyId, currentId);
      if (item == null) break;
      path.insert(0, item);
      currentId = item.parentId;
    }
    return path;
  }

  @override
  Future<void> moveItem(
    String familyId,
    String fileId,
    String? newParentId,
  ) async {
    final m = _items(familyId)[fileId];
    if (m == null) return;
    final now = DateTime.now();
    _items(familyId)[fileId] = m.copyWith(
      parentId: newParentId,
      clearParentId: newParentId == null,
      updatedAt: now,
    );
    _notify();
  }

  @override
  Future<void> renameItem(
    String familyId,
    String fileId,
    String newName,
  ) async {
    final m = _items(familyId)[fileId];
    if (m == null) return;
    _items(familyId)[fileId] = m.copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<int> getStorageUsage(String familyId) async {
    var total = 0;
    for (final i in _items(familyId).values) {
      if (i.isFile) {
        total += i.size ?? 0;
      }
    }
    return total;
  }

  @override
  Future<FileItemModel> uploadFile(
    String familyId,
    String? parentId,
    String userId,
    String filePath,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    throw UnimplementedError('MemoryFilesRepository.uploadFile');
  }

  @override
  Future<String> downloadFile(
    FileItemModel item, {
    void Function(double progress)? onProgress,
  }) async {
    throw UnimplementedError('MemoryFilesRepository.downloadFile');
  }
}
