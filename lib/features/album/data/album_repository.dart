import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dongine/shared/models/album_model.dart';

/// 사진 업로드 실패 시 사용자에게 표시할 메시지를 담는 예외
class PhotoUploadException implements Exception {
  final String message;
  const PhotoUploadException(this.message);

  @override
  String toString() => message;
}

class AlbumRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference _albumsCollection(String familyId) {
    return _firestore.collection('families/$familyId/albums');
  }

  CollectionReference _photosCollection(String familyId, String albumId) {
    return _firestore
        .collection('families/$familyId/albums/$albumId/photos');
  }

  /// 모든 앨범 스트림 (최신순)
  Stream<List<AlbumModel>> getAlbumsStream(String familyId) {
    return _albumsCollection(familyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AlbumModel.fromFirestore(doc))
          .toList();
    });
  }

  /// 앨범 생성
  Future<AlbumModel> createAlbum(
    String familyId,
    String title,
    String userId, {
    String? description,
    String? eventId,
  }) async {
    final docRef = _albumsCollection(familyId).doc();
    final now = DateTime.now();

    final album = AlbumModel(
      id: docRef.id,
      title: title,
      description: description,
      eventId: eventId,
      createdBy: userId,
      createdAt: now,
    );

    await docRef.set(album.toFirestore());
    return album;
  }

  /// 앨범 제목/설명 수정
  Future<void> updateAlbum(
    String familyId,
    String albumId, {
    String? title,
    String? description,
    bool clearDescription = false,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (clearDescription) {
      data['description'] = null;
    } else if (description != null) {
      data['description'] = description;
    }
    if (data.isNotEmpty) {
      await _albumsCollection(familyId).doc(albumId).update(data);
    }
  }

  /// 사진 캡션 수정
  Future<void> updatePhotoCaption(
    String familyId,
    String albumId,
    String photoId,
    String? caption,
  ) async {
    await _photosCollection(familyId, albumId).doc(photoId).update({
      'caption': caption,
    });
  }

  /// 앨범 삭제 (사진 + Storage 파일 포함)
  Future<void> deleteAlbum(String familyId, String albumId) async {
    // 모든 사진 삭제
    final photosSnapshot =
        await _photosCollection(familyId, albumId).get();

    for (final doc in photosSnapshot.docs) {
      final photo = PhotoModel.fromFirestore(doc);
      // Storage 파일 삭제
      try {
        final storagePath =
            'families/$familyId/albums/$albumId/${photo.id}.jpg';
        await _storage.ref(storagePath).delete();
      } catch (_) {
        // Storage 삭제 실패해도 계속 진행
      }
      await doc.reference.delete();
    }

    // 앨범 문서 삭제
    await _albumsCollection(familyId).doc(albumId).delete();
  }

  /// 앨범 내 사진 스트림 (최신순)
  Stream<List<PhotoModel>> getPhotosStream(
      String familyId, String albumId) {
    return _photosCollection(familyId, albumId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PhotoModel.fromFirestore(doc))
          .toList();
    });
  }

  /// 사진 업로드
  Future<PhotoModel> uploadPhoto(
    String familyId,
    String albumId,
    String userId,
    String filePath, {
    String? caption,
    void Function(double progress)? onProgress,
  }) async {
    // 파일 존재 확인
    final file = File(filePath);
    if (!file.existsSync()) {
      throw PhotoUploadException('선택한 파일을 찾을 수 없습니다. 다시 시도해주세요.');
    }

    final docRef = _photosCollection(familyId, albumId).doc();
    final storagePath =
        'families/$familyId/albums/$albumId/${docRef.id}.jpg';
    final storageRef = _storage.ref(storagePath);

    // 파일 업로드 (contentType 명시)
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final uploadTask = storageRef.putFile(file, metadata);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        }
      });
    }

    try {
      await uploadTask;
    } on FirebaseException catch (e) {
      throw PhotoUploadException(
        storageErrorMessage(e.code),
      );
    }

    // 다운로드 URL 가져오기
    final String downloadUrl;
    try {
      downloadUrl = await storageRef.getDownloadURL();
    } catch (_) {
      // Storage에 올라간 파일 정리
      try {
        await storageRef.delete();
      } catch (_) {}
      throw PhotoUploadException('업로드 후 URL을 가져오지 못했습니다. 다시 시도해주세요.');
    }

    final now = DateTime.now();
    final photo = PhotoModel(
      id: docRef.id,
      albumId: albumId,
      imageUrl: downloadUrl,
      caption: caption,
      uploadedBy: userId,
      createdAt: now,
    );

    // Firestore 문서 저장 — 실패 시 Storage 파일 정리
    try {
      await docRef.set(photo.toFirestore());
    } catch (_) {
      try {
        await storageRef.delete();
      } catch (_) {}
      throw PhotoUploadException('사진 정보를 저장하지 못했습니다. 다시 시도해주세요.');
    }

    // 앨범 photoCount 증가 + 첫 사진이면 커버 설정
    try {
      final albumRef = _albumsCollection(familyId).doc(albumId);
      final albumDoc = await albumRef.get();
      final albumData = albumDoc.data() as Map<String, dynamic>?;
      final currentCount = albumData?['photoCount'] ?? 0;

      final updateData = <String, dynamic>{
        'photoCount': FieldValue.increment(1),
      };
      if (currentCount == 0) {
        updateData['coverPhotoUrl'] = downloadUrl;
      }
      await albumRef.update(updateData);
    } catch (_) {
      // 사진 자체는 업로드 완료 — 카운트는 다음 업로드 시 보정됨
    }

    return photo;
  }

  /// Storage 에러 코드를 사용자 메시지로 변환
  static String storageErrorMessage(String code) {
    switch (code) {
      case 'storage/unauthorized':
        return '사진을 업로드할 권한이 없습니다. 가족 멤버인지 확인해주세요.';
      case 'storage/canceled':
        return '업로드가 취소되었습니다.';
      case 'storage/retry-limit-exceeded':
        return '네트워크 상태가 불안정합니다. 잠시 후 다시 시도해주세요.';
      case 'storage/quota-exceeded':
        return '저장 용량이 초과되었습니다.';
      default:
        return '사진 업로드에 실패했습니다. 다시 시도해주세요.';
    }
  }

  /// 사진 삭제 (커버/카운트 정합성 보장)
  Future<void> deletePhoto(
    String familyId,
    String albumId,
    String photoId,
    String storagePath,
  ) async {
    // 삭제 대상 사진의 URL 가져오기
    final photoDoc =
        await _photosCollection(familyId, albumId).doc(photoId).get();
    final deletedPhoto = photoDoc.exists
        ? PhotoModel.fromFirestore(photoDoc)
        : null;

    // Storage 파일 삭제
    try {
      await _storage.ref(storagePath).delete();
    } catch (_) {
      // Storage 삭제 실패해도 계속 진행
    }

    // Firestore 문서 삭제
    await _photosCollection(familyId, albumId).doc(photoId).delete();

    // 앨범 정보 갱신
    final albumRef = _albumsCollection(familyId).doc(albumId);
    final albumDoc = await albumRef.get();
    if (!albumDoc.exists) return;

    final albumData = albumDoc.data() as Map<String, dynamic>;
    final currentCover = albumData['coverPhotoUrl'];
    final currentCount = (albumData['photoCount'] as int? ?? 1) - 1;
    final newCount = currentCount < 0 ? 0 : currentCount;

    final updateData = <String, dynamic>{
      'photoCount': newCount,
    };

    // 삭제한 사진이 커버였거나 카운트가 0이면 커버 재설정
    final isCoverDeleted = deletedPhoto != null &&
        currentCover == deletedPhoto.imageUrl;

    if (newCount == 0) {
      updateData['coverPhotoUrl'] = null;
    } else if (isCoverDeleted) {
      // 남은 사진 중 가장 최근 것을 커버로
      final remainingPhotos = await _photosCollection(familyId, albumId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (remainingPhotos.docs.isNotEmpty) {
        final nextCover = PhotoModel.fromFirestore(remainingPhotos.docs.first);
        updateData['coverPhotoUrl'] = nextCover.imageUrl;
      } else {
        updateData['coverPhotoUrl'] = null;
      }
    }

    await albumRef.update(updateData);
  }

  /// 사진 일괄 삭제 (커버/카운트 정합성 보장)
  Future<void> deletePhotos(
    String familyId,
    String albumId,
    List<PhotoModel> photos,
  ) async {
    if (photos.isEmpty) return;

    // 삭제 대상 URL 수집
    final deletedUrls = photos.map((p) => p.imageUrl).toSet();

    // Storage + Firestore 문서 삭제
    for (final photo in photos) {
      try {
        final storagePath =
            'families/$familyId/albums/$albumId/${photo.id}.jpg';
        await _storage.ref(storagePath).delete();
      } catch (_) {
        // Storage 삭제 실패해도 계속 진행
      }
      await _photosCollection(familyId, albumId).doc(photo.id).delete();
    }

    // 앨범 정보 갱신
    final albumRef = _albumsCollection(familyId).doc(albumId);
    final albumDoc = await albumRef.get();
    if (!albumDoc.exists) return;

    final albumData = albumDoc.data() as Map<String, dynamic>;
    final currentCover = albumData['coverPhotoUrl'];
    final currentCount = albumData['photoCount'] as int? ?? photos.length;
    final newCount = (currentCount - photos.length).clamp(0, currentCount);

    final updateData = <String, dynamic>{
      'photoCount': newCount,
    };

    // 커버가 삭제 대상에 포함되면 재설정
    final isCoverDeleted =
        currentCover != null && deletedUrls.contains(currentCover);

    if (newCount == 0) {
      updateData['coverPhotoUrl'] = null;
    } else if (isCoverDeleted) {
      final remainingPhotos = await _photosCollection(familyId, albumId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (remainingPhotos.docs.isNotEmpty) {
        final nextCover =
            PhotoModel.fromFirestore(remainingPhotos.docs.first);
        updateData['coverPhotoUrl'] = nextCover.imageUrl;
      } else {
        updateData['coverPhotoUrl'] = null;
      }
    }

    await albumRef.update(updateData);
  }

  /// 타임라인: 모든 앨범의 사진을 최신순으로
  Stream<List<PhotoModel>> getTimelineStream(String familyId) {
    return _firestore
        .collectionGroup('photos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      // collectionGroup은 모든 photos 하위 컬렉션을 가져오므로
      // 현재 가족의 경로인지 확인
      return snapshot.docs
          .where((doc) => doc.reference.path.startsWith('families/$familyId/'))
          .map((doc) => PhotoModel.fromFirestore(doc))
          .toList();
    });
  }
}
