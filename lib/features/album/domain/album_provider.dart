import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/album/data/album_repository.dart';
import 'package:dongine/shared/models/album_model.dart';

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  return AlbumRepository();
});

/// 가족의 앨범 목록 스트림
final albumsProvider =
    StreamProvider.family<List<AlbumModel>, String>((ref, familyId) {
  final repo = ref.watch(albumRepositoryProvider);
  return repo.getAlbumsStream(familyId);
});

/// 앨범 내 사진 목록 스트림
final albumPhotosProvider =
    StreamProvider.family<List<PhotoModel>, (String, String)>(
        (ref, params) {
  final (familyId, albumId) = params;
  final repo = ref.watch(albumRepositoryProvider);
  return repo.getPhotosStream(familyId, albumId);
});

/// 타임라인 (모든 사진 최신순)
final timelineProvider =
    StreamProvider.family<List<PhotoModel>, String>((ref, familyId) {
  final repo = ref.watch(albumRepositoryProvider);
  return repo.getTimelineStream(familyId);
});
