import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/album/domain/album_provider.dart';
import 'package:dongine/shared/models/album_model.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('가족 앨범'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '앨범'),
            Tab(text: '타임라인'),
          ],
        ),
      ),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (family) {
          if (family == null) {
            return const Center(child: Text('가족 그룹에 참여해주세요'));
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _AlbumsTab(familyId: family.id),
              _TimelineTab(familyId: family.id),
            ],
          );
        },
      ),
      floatingActionButton: familyAsync.valueOrNull != null
          ? FloatingActionButton(
              onPressed: () => _showCreateAlbumDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showCreateAlbumDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 앨범 만들기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '앨범 이름',
                hintText: '예: 가족 여행 2026',
              ),
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

              final family = ref.read(currentFamilyProvider).valueOrNull;
              final user = ref.read(authStateProvider).valueOrNull;
              if (family == null || user == null) return;

              final repo = ref.read(albumRepositoryProvider);
              await repo.createAlbum(
                family.id,
                title,
                user.uid,
                description: descController.text.trim().isNotEmpty
                    ? descController.text.trim()
                    : null,
              );

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  final String familyId;

  const _AlbumsTab({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider(familyId));
    final theme = Theme.of(context);

    return albumsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (albums) {
        if (albums.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_album_outlined,
                    size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  '아직 앨범이 없어요',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '+ 버튼을 눌러 첫 앨범을 만들어보세요!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return _AlbumCard(
              album: album,
              familyId: familyId,
            );
          },
        );
      },
    );
  }
}

class _AlbumCard extends ConsumerWidget {
  final AlbumModel album;
  final String familyId;

  const _AlbumCard({required this.album, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/album/${album.id}', extra: familyId);
        },
        onLongPress: () => _showAlbumOptionsSheet(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: album.coverPhotoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: album.coverPhotoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.photo,
                            size: 48, color: theme.colorScheme.outline),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.photo_album,
                          size: 48, color: theme.colorScheme.outline),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '사진 ${album.photoCount}장',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlbumOptionsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('앨범 편집'),
              onTap: () {
                Navigator.pop(context);
                _showEditAlbumDialog(context, ref);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text('앨범 삭제',
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

  void _showEditAlbumDialog(BuildContext context, WidgetRef ref) {
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
              decoration: const InputDecoration(
                labelText: '앨범 이름',
              ),
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
                familyId,
                album.id,
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

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앨범 삭제'),
        content: Text('"${album.title}" 앨범을 삭제하시겠어요?\n모든 사진이 함께 삭제됩니다.'),
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
              await repo.deleteAlbum(familyId, album.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _TimelineTab extends ConsumerWidget {
  final String familyId;

  const _TimelineTab({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(timelineProvider(familyId));
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy년 M월 d일 HH:mm');

    return timelineAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (photos) {
        if (photos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timeline,
                    size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  '아직 사진이 없어요',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return _TimelinePhotoCard(
              photo: photo,
              dateFormat: dateFormat,
            );
          },
        );
      },
    );
  }
}

class _TimelinePhotoCard extends ConsumerWidget {
  final PhotoModel photo;
  final DateFormat dateFormat;

  const _TimelinePhotoCard({
    required this.photo,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uploaderAsync = ref.watch(userProfileProvider(photo.uploadedBy));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 업로더 정보
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(Icons.person, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                uploaderAsync.when(
                  data: (user) => Text(
                    user?.displayName ?? '알 수 없음',
                    style: theme.textTheme.titleSmall,
                  ),
                  loading: () => const SizedBox(
                    width: 60,
                    height: 14,
                  ),
                  error: (_, _) => const Text('알 수 없음'),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(photo.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          // 사진
          CachedNetworkImage(
            imageUrl: photo.imageUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, _) => AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (_, _, _) => AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image,
                    size: 48, color: theme.colorScheme.outline),
              ),
            ),
          ),
          // 캡션
          if (photo.caption != null && photo.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Text(
                photo.caption!,
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}
