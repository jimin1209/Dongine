import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/shared/models/album_model.dart';

void main() {
  group('AlbumModel', () {
    test('photoCount가 0이면 빈 앨범으로 간주된다', () {
      final album = AlbumModel(
        id: 'test',
        title: '테스트 앨범',
        photoCount: 0,
        coverPhotoUrl: null,
        createdBy: 'user1',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(album.photoCount, 0);
      expect(album.coverPhotoUrl, isNull);
    });

    test('toFirestore에 coverPhotoUrl null이 포함된다', () {
      final album = AlbumModel(
        id: 'test',
        title: '빈 앨범',
        photoCount: 0,
        coverPhotoUrl: null,
        createdBy: 'user1',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = album.toFirestore();
      expect(map['coverPhotoUrl'], isNull);
      expect(map['photoCount'], 0);
    });

    test('toFirestore에 coverPhotoUrl이 포함된다', () {
      final album = AlbumModel(
        id: 'test',
        title: '앨범',
        photoCount: 3,
        coverPhotoUrl: 'https://example.com/photo.jpg',
        createdBy: 'user1',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = album.toFirestore();
      expect(map['coverPhotoUrl'], 'https://example.com/photo.jpg');
      expect(map['photoCount'], 3);
    });

    test('copyWith로 제목과 설명을 변경할 수 있다', () {
      final album = AlbumModel(
        id: 'test',
        title: '원래 제목',
        description: '원래 설명',
        createdBy: 'user1',
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = album.copyWith(title: '새 제목', description: '새 설명');
      expect(updated.title, '새 제목');
      expect(updated.description, '새 설명');
      expect(updated.id, album.id);
      expect(updated.createdBy, album.createdBy);
    });

    test('copyWith에서 clearDescription이 true이면 설명이 null이 된다', () {
      final album = AlbumModel(
        id: 'test',
        title: '제목',
        description: '설명 있음',
        createdBy: 'user1',
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = album.copyWith(clearDescription: true);
      expect(updated.description, isNull);
      expect(updated.title, '제목');
    });

    test('copyWith에서 변경하지 않으면 기존 값이 유지된다', () {
      final album = AlbumModel(
        id: 'test',
        title: '제목',
        description: '설명',
        createdBy: 'user1',
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = album.copyWith();
      expect(updated.title, album.title);
      expect(updated.description, album.description);
    });
  });

  group('PhotoModel', () {
    test('toFirestore가 필수 필드를 포함한다', () {
      final photo = PhotoModel(
        id: 'photo1',
        albumId: 'album1',
        imageUrl: 'https://example.com/img.jpg',
        uploadedBy: 'user1',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = photo.toFirestore();
      expect(map['albumId'], 'album1');
      expect(map['imageUrl'], 'https://example.com/img.jpg');
      expect(map['uploadedBy'], 'user1');
    });

    test('copyWith로 캡션을 변경할 수 있다', () {
      final photo = PhotoModel(
        id: 'photo1',
        albumId: 'album1',
        imageUrl: 'https://example.com/img.jpg',
        uploadedBy: 'user1',
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = photo.copyWith(caption: '새 캡션');
      expect(updated.caption, '새 캡션');
      expect(updated.id, photo.id);
      expect(updated.imageUrl, photo.imageUrl);
    });

    test('copyWith에서 clearCaption이 true이면 캡션이 null이 된다', () {
      final photo = PhotoModel(
        id: 'photo1',
        albumId: 'album1',
        imageUrl: 'https://example.com/img.jpg',
        caption: '기존 캡션',
        uploadedBy: 'user1',
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = photo.copyWith(clearCaption: true);
      expect(updated.caption, isNull);
    });
  });
}
