import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/album/domain/album_provider.dart';
import 'package:dongine/shared/models/album_model.dart';

class AlbumDetailScreen extends ConsumerStatefulWidget {
  final String albumId;
  final String familyId;

  const AlbumDetailScreen({
    super.key,
    required this.albumId,
    required this.familyId,
  });

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(
      albumPhotosProvider((widget.familyId, widget.albumId)),
    );
    final albumsAsync = ref.watch(albumsProvider(widget.familyId));
    final theme = Theme.of(context);

    // 앨범 제목 가져오기
    final albumTitle = albumsAsync.whenOrNull(
      data: (albums) {
        try {
          return albums
              .firstWhere((a) => a.id == widget.albumId)
              .title;
        } catch (_) {
          return null;
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(albumTitle ?? '앨범'),
      ),
      body: Stack(
        children: [
          photosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (photos) {
              if (photos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate,
                          size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        '사진을 추가해보세요!',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return _PhotoGridItem(
                    photo: photo,
                    familyId: widget.familyId,
                    albumId: widget.albumId,
                    onTap: () => _showFullScreenPhoto(context, photo),
                  );
                },
              );
            },
          ),
          // 업로드 진행률 표시
          if (_isUploading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: theme.colorScheme.surface.withValues(alpha: 0.9),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text(
                      '업로드 중... ${(_uploadProgress * 100).toInt()}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : () => _showPickerChoice(context),
        child: _isUploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add_a_photo),
      ),
    );
  }

  void _showPickerChoice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final repo = ref.read(albumRepositoryProvider);
      await repo.uploadPhoto(
        widget.familyId,
        widget.albumId,
        user.uid,
        image.path,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _showFullScreenPhoto(BuildContext context, PhotoModel photo) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: photo.caption != null && photo.caption!.isNotEmpty
                ? Text(photo.caption!)
                : null,
          ),
          backgroundColor: Colors.black,
          body: InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: photo.imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoGridItem extends ConsumerWidget {
  final PhotoModel photo;
  final String familyId;
  final String albumId;
  final VoidCallback onTap;

  const _PhotoGridItem({
    required this.photo,
    required this.familyId,
    required this.albumId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showDeleteDialog(context, ref),
      child: CachedNetworkImage(
        imageUrl: photo.thumbnailUrl ?? photo.imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, _, _) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image, color: theme.colorScheme.outline),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final repo = ref.read(albumRepositoryProvider);
              final storagePath =
                  'families/$familyId/albums/$albumId/${photo.id}.jpg';
              await repo.deletePhoto(
                  familyId, albumId, photo.id, storagePath);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
