import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/file_item_model.dart';

class FilesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference _filesCollection(String familyId) {
    return _firestore.collection(FirestorePaths.files(familyId));
  }

  /// 특정 폴더의 파일/폴더 목록을 스트림으로 반환 (폴더 먼저, 이름순)
  Stream<List<FileItemModel>> getFilesStream(
      String familyId, String? parentId) {
    Query query = _filesCollection(familyId);

    if (parentId == null) {
      query = query.where('parentId', isNull: true);
    } else {
      query = query.where('parentId', isEqualTo: parentId);
    }

    return query.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => FileItemModel.fromFirestore(doc))
          .toList();
      // 폴더 먼저, 그 다음 이름순
      items.sort((a, b) {
        if (a.isFolder && !b.isFolder) return -1;
        if (!a.isFolder && b.isFolder) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return items;
    });
  }

  /// 새 폴더 생성
  Future<FileItemModel> createFolder(
    String familyId,
    String name,
    String? parentId,
    String userId,
  ) async {
    final now = DateTime.now();
    final docRef = _filesCollection(familyId).doc();

    final folder = FileItemModel(
      id: docRef.id,
      name: name,
      type: 'folder',
      parentId: parentId,
      uploadedBy: userId,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(folder.toFirestore());
    return folder;
  }

  /// 파일 업로드
  Future<FileItemModel> uploadFile(
    String familyId,
    String? parentId,
    String userId,
    String filePath,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    final docRef = _filesCollection(familyId).doc();
    final storagePath = 'families/$familyId/files/${docRef.id}/$fileName';

    final file = File(filePath);
    final fileSize = await file.length();
    final ref = _storage.ref(storagePath);

    // 파일 업로드
    final uploadTask = ref.putFile(file);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }

    await uploadTask;

    // 다운로드 URL 가져오기
    final downloadUrl = await ref.getDownloadURL();

    // MIME type 추측
    final mimeType = _guessMimeType(fileName);

    final now = DateTime.now();
    final fileItem = FileItemModel(
      id: docRef.id,
      name: fileName,
      type: 'file',
      mimeType: mimeType,
      size: fileSize,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      parentId: parentId,
      uploadedBy: userId,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(fileItem.toFirestore());
    return fileItem;
  }

  /// 항목 삭제 (파일이면 Storage도 삭제)
  Future<void> deleteItem(String familyId, String fileId) async {
    final docRef = _filesCollection(familyId).doc(fileId);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final item = FileItemModel.fromFirestore(doc);

    // 폴더면 하위 항목도 모두 삭제
    if (item.isFolder) {
      await _deleteFolderRecursive(familyId, fileId);
    } else {
      // 파일이면 Storage에서도 삭제
      if (item.storagePath != null) {
        try {
          await _storage.ref(item.storagePath!).delete();
        } catch (_) {
          // Storage 삭제 실패해도 Firestore 문서는 삭제 진행
        }
      }
    }

    await docRef.delete();
  }

  Future<void> _deleteFolderRecursive(
      String familyId, String folderId) async {
    final children = await _filesCollection(familyId)
        .where('parentId', isEqualTo: folderId)
        .get();

    for (final child in children.docs) {
      final childItem = FileItemModel.fromFirestore(child);
      if (childItem.isFolder) {
        await _deleteFolderRecursive(familyId, childItem.id);
      } else if (childItem.storagePath != null) {
        try {
          await _storage.ref(childItem.storagePath!).delete();
        } catch (_) {}
      }
      await child.reference.delete();
    }
  }

  /// 항목 이름 변경
  Future<void> renameItem(
      String familyId, String fileId, String newName) async {
    await _filesCollection(familyId).doc(fileId).update({
      'name': newName,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// 항목 이동 (parentId 변경)
  Future<void> moveItem(
      String familyId, String fileId, String? newParentId) async {
    await _filesCollection(familyId).doc(fileId).update({
      'parentId': newParentId,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// 스토리지 사용량 조회 (총 바이트)
  Future<int> getStorageUsage(String familyId) async {
    final snapshot = await _filesCollection(familyId)
        .where('type', isEqualTo: 'file')
        .get();

    int totalBytes = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalBytes += (data['size'] as int?) ?? 0;
    }
    return totalBytes;
  }

  /// 특정 파일/폴더 정보 가져오기
  Future<FileItemModel?> getItem(String familyId, String fileId) async {
    final doc = await _filesCollection(familyId).doc(fileId).get();
    if (!doc.exists) return null;
    return FileItemModel.fromFirestore(doc);
  }

  /// 루트까지의 경로(breadcrumb) 빌드
  Future<List<FileItemModel>> buildBreadcrumb(
      String familyId, String? folderId) async {
    final List<FileItemModel> path = [];
    String? currentId = folderId;

    while (currentId != null) {
      final item = await getItem(familyId, currentId);
      if (item == null) break;
      path.insert(0, item);
      currentId = item.parentId;
    }

    return path;
  }

  /// 파일 다운로드 (로컬 임시 경로로 저장)
  Future<String> downloadFile(
    FileItemModel item, {
    void Function(double progress)? onProgress,
  }) async {
    if (item.storagePath == null) {
      throw Exception('파일 저장 경로가 없습니다');
    }

    final ref = _storage.ref(item.storagePath!);
    final tempDir = Directory.systemTemp;
    final localFile = File('${tempDir.path}/${item.name}');

    final downloadTask = ref.writeToFile(localFile);

    if (onProgress != null) {
      downloadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        }
      });
    }

    await downloadTask;
    return localFile.path;
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'zip':
        return 'application/zip';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
