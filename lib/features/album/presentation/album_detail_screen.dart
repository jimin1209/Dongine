import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/album/data/album_repository.dart';
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
  bool _isSelectionMode = false;
  final Set<String> _selectedPhotoIds = {};

  AlbumModel? _currentAlbum(List<AlbumModel>? albums) {
    if (albums == null) return null;
    try {
      return albums.firstWhere((a) => a.id == widget.albumId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(
      albumPhotosProvider((widget.familyId, widget.albumId)),
    );
    final albumsAsync = ref.watch(albumsProvider(widget.familyId));
    final theme = Theme.of(context);
    final album = _currentAlbum(albumsAsync.valueOrNull);

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedPhotoIds.clear();
                }),
              )
            : null,
        title: _isSelectionMode
            ? Text('${_selectedPhotoIds.length}장 선택')
            : Text(album?.title ?? '앨범'),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: '전체 선택',
              onPressed: () {
                final photos = ref
                    .read(albumPhotosProvider(
                        (widget.familyId, widget.albumId)))
                    .valueOrNull;
                if (photos == null) return;
                setState(() {
                  if (_selectedPhotoIds.length == photos.length) {
                    _selectedPhotoIds.clear();
                  } else {
                    _selectedPhotoIds
                      ..clear()
                      ..addAll(photos.map((p) => p.id));
                  }
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.delete,
                  color: _selectedPhotoIds.isEmpty
                      ? null
                      : theme.colorScheme.error),
              tooltip: '선택 삭제',
              onPressed: _selectedPhotoIds.isEmpty
                  ? null
                  : () => _showBulkDeleteDialog(context),
            ),
          ] else ...[
            if (album != null)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: '앨범 편집',
                onPressed: () => _showEditAlbumDialog(context, album),
              ),
          ],
        ],
      ),
      body: Stack(
        children: [
          photosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (photos) {
              if (photos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          '아직 사진이 없어요',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '아래 버튼을 눌러 첫 사진을 추가해보세요!',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (album?.description != null &&
                            album!.description!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            album.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return CustomScrollView(
                slivers: [
                  // 앨범 메타 정보 헤더
                  SliverToBoxAdapter(
                    child: _AlbumMetaHeader(album: album, photoCount: photos.length),
                  ),
                  // 사진 그리드
                  SliverPadding(
                    padding: const EdgeInsets.all(4),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final photo = photos[index];
                          final isSelected =
                              _selectedPhotoIds.contains(photo.id);
                          return _PhotoGridItem(
                            photo: photo,
                            familyId: widget.familyId,
                            albumId: widget.albumId,
                            isSelectionMode: _isSelectionMode,
                            isSelected: isSelected,
                            onTap: () {
                              if (_isSelectionMode) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedPhotoIds.remove(photo.id);
                                    if (_selectedPhotoIds.isEmpty) {
                                      _isSelectionMode = false;
                                    }
                                  } else {
                                    _selectedPhotoIds.add(photo.id);
                                  }
                                });
                              } else {
                                _showFullScreenPhoto(context, photo);
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedPhotoIds.add(photo.id);
                                });
                              }
                            },
                          );
                        },
                        childCount: photos.length,
                      ),
                    ),
                  ),
                ],
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
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
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

  void _showBulkDeleteDialog(BuildContext context) {
    final count = _selectedPhotoIds.length;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('사진 일괄 삭제'),
        content: Text('선택한 $count장의 사진을 삭제하시겠어요?\n삭제된 사진은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final photos = ref
                  .read(albumPhotosProvider(
                      (widget.familyId, widget.albumId)))
                  .valueOrNull;
              if (photos == null) return;

              final selectedPhotos = photos
                  .where((p) => _selectedPhotoIds.contains(p.id))
                  .toList();

              final repo = ref.read(albumRepositoryProvider);
              await repo.deletePhotos(
                widget.familyId,
                widget.albumId,
                selectedPhotos,
              );

              if (mounted) {
                setState(() {
                  _isSelectionMode = false;
                  _selectedPhotoIds.clear();
                });
                messenger.showSnackBar(
                  SnackBar(content: Text('$count장의 사진이 삭제되었습니다')),
                );
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showEditAlbumDialog(BuildContext context, AlbumModel album) {
    final titleController = TextEditingController(text: album.title);
    final descController =
        TextEditingController(text: album.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앨범 편집'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '앨범 이름'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                hintText: '앨범에 대한 설명',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              final repo = ref.read(albumRepositoryProvider);
              final desc = descController.text.trim();
              await repo.updateAlbum(
                widget.familyId,
                widget.albumId,
                title: title,
                description: desc.isNotEmpty ? desc : null,
                clearDescription: desc.isEmpty,
              );

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
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
    final XFile? image;
    try {
      image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 선택할 수 없습니다. 권한을 확인해주세요.')),
        );
      }
      return;
    }

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
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );
    } on PhotoUploadException catch (e) {
      if (mounted) {
        _showUploadFailureSnackBar(e.message, source);
      }
    } catch (_) {
      if (mounted) {
        _showUploadFailureSnackBar('알 수 없는 오류가 발생했습니다. 다시 시도해주세요.', source);
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

  void _showUploadFailureSnackBar(String message, ImageSource source) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '재시도',
          onPressed: () => _pickAndUpload(source),
        ),
      ),
    );
  }

  void _showFullScreenPhoto(BuildContext context, PhotoModel photo) {
    showDialog(
      context: context,
      builder: (context) => _FullScreenPhotoDialog(
        photo: photo,
        familyId: widget.familyId,
        albumId: widget.albumId,
      ),
    );
  }
}

/// 앨범 메타 정보 헤더
class _AlbumMetaHeader extends StatelessWidget {
  final AlbumModel? album;
  final int photoCount;

  const _AlbumMetaHeader({required this.album, required this.photoCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy년 M월 d일');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 설명
          if (album?.description != null &&
              album!.description!.isNotEmpty) ...[
            Text(
              album!.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
          // 사진 수 + 생성일
          Row(
            children: [
              Icon(Icons.photo_library,
                  size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                '사진 $photoCount장',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              if (album != null) ...[
                const SizedBox(width: 16),
                Icon(Icons.calendar_today,
                    size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(album!.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }
}

/// 전체화면 사진 뷰어 (캡션 편집 지원)
class _FullScreenPhotoDialog extends ConsumerStatefulWidget {
  final PhotoModel photo;
  final String familyId;
  final String albumId;

  const _FullScreenPhotoDialog({
    required this.photo,
    required this.familyId,
    required this.albumId,
  });

  @override
  ConsumerState<_FullScreenPhotoDialog> createState() =>
      _FullScreenPhotoDialogState();
}

class _FullScreenPhotoDialogState
    extends ConsumerState<_FullScreenPhotoDialog> {
  @override
  Widget build(BuildContext context) {
    final caption = widget.photo.caption;
    final hasCaption = caption != null && caption.isNotEmpty;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: hasCaption ? Text(caption) : const Text('사진'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: '캡션 편집',
              onPressed: () => _showEditCaptionDialog(context),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        body: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.photo.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child:
                          CircularProgressIndicator(color: Colors.white),
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
            // 하단 캡션 표시
            if (hasCaption)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                color: Colors.black87,
                child: Text(
                  caption,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditCaptionDialog(BuildContext context) {
    final controller = TextEditingController(
        text: widget.photo.caption ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('캡션 편집'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '사진에 대한 설명을 입력하세요',
            labelText: '캡션',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final repo = ref.read(albumRepositoryProvider);
              final text = controller.text.trim();
              await repo.updatePhotoCaption(
                widget.familyId,
                widget.albumId,
                widget.photo.id,
                text.isNotEmpty ? text : null,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              // 전체화면도 닫고 다시 열도록
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _PhotoGridItem extends ConsumerWidget {
  final PhotoModel photo;
  final String familyId;
  final String albumId;
  final VoidCallback onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;

  const _PhotoGridItem({
    required this.photo,
    required this.familyId,
    required this.albumId,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasCaption =
        photo.caption != null && photo.caption!.isNotEmpty;

    return GestureDetector(
      onTap: isSelectionMode ? onTap : onTap,
      onLongPress: isSelectionMode
          ? null
          : (onLongPress ?? () => _showPhotoOptionsSheet(context, ref)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
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
              child: Icon(Icons.broken_image,
                  color: theme.colorScheme.outline),
            ),
          ),
          // 선택 모드 오버레이
          if (isSelectionMode) ...[
            Container(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.black38,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ],
          // 캡션 인디케이터
          if (hasCaption && !isSelectionMode)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.chat_bubble,
                    size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _showPhotoOptionsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('캡션 편집'),
              onTap: () {
                Navigator.pop(context);
                _showEditCaptionDialog(context, ref);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text('사진 삭제',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCaptionDialog(BuildContext context, WidgetRef ref) {
    final controller =
        TextEditingController(text: photo.caption ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('캡션 편집'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '사진에 대한 설명을 입력하세요',
            labelText: '캡션',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final repo = ref.read(albumRepositoryProvider);
              final text = controller.text.trim();
              await repo.updatePhotoCaption(
                familyId,
                albumId,
                photo.id,
                text.isNotEmpty ? text : null,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
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
