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
  });
}
