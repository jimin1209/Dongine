import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dongine/features/files/domain/files_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/shared/models/file_item_model.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  bool _isGridView = false;
  bool _showFabMenu = false;
  bool _showSearch = false;
  final _searchController = TextEditingController();
  VoidCallback? _retryAction;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(filesListProvider);
    final breadcrumbAsync = ref.watch(breadcrumbProvider);
    final currentFolder = ref.watch(currentFolderProvider);
    final sortOption = ref.watch(filesSortOptionProvider);
    final typeFilter = ref.watch(filesTypeFilterProvider);
    final searchQuery = ref.watch(filesSearchQueryProvider);
    final hasActiveFilter = ref.watch(hasActiveFilterProvider);
    final rawCount = ref.watch(rawFilesCountProvider);
    final transfer = ref.watch(fileTransferProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: currentFolder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _navigateBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _showSearch
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '파일 검색...',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    ref.read(filesSearchQueryProvider.notifier).state = value;
                  },
                )
              : const Text('파일'),
          leading: currentFolder != null && !_showSearch
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateBack,
                )
              : _showSearch
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _closeSearch,
                    )
                  : null,
          actions: [
            if (!_showSearch)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _showSearch = true),
                tooltip: '검색',
              ),
            IconButton(
              icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
              onPressed: () => setState(() => _isGridView = !_isGridView),
              tooltip: _isGridView ? '목록 보기' : '그리드 보기',
            ),
          ],
        ),
        body: Column(
          children: [
            // 전송 상태 카드
            if (transfer != null) _buildTransferCard(transfer, theme),

            // Breadcrumb 네비게이션
            breadcrumbAsync.when(
              data: (breadcrumbs) =>
                  _buildBreadcrumb(breadcrumbs, theme),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // 정렬 & 필터 바
            _buildSortFilterBar(theme, sortOption, typeFilter),

            // 활성 필터 표시 바
            if (hasActiveFilter)
              _buildActiveFilterBar(theme, searchQuery, typeFilter),

            // 파일 목록
            Expanded(
              child: filesAsync.when(
                data: (files) {
                  if (files.isEmpty) {
                    final kind = resolveFilesEmptyListKind(
                      rawItemCount: rawCount.valueOrNull,
                      hasActiveFilter: hasActiveFilter,
                    );
                    return _buildEmptyState(theme, kind);
                  }
                  return _isGridView
                      ? _buildGridView(files)
                      : _buildListView(files);
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('오류가 발생했습니다: $e')),
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFab(),
      ),
    );
  }

  void _closeSearch() {
    _searchController.clear();
    ref.read(filesSearchQueryProvider.notifier).state = '';
    setState(() => _showSearch = false);
  }

  // ─── Sort & Filter Bar ───

  Widget _buildSortFilterBar(
      ThemeData theme, FilesSortOption sort, FilesTypeFilter typeFilter) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // 정렬 드롭다운
          PopupMenuButton<FilesSortOption>(
            initialValue: sort,
            onSelected: (value) {
              ref.read(filesSortOptionProvider.notifier).state = value;
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: FilesSortOption.name, child: Text('이름순')),
              PopupMenuItem(
                  value: FilesSortOption.newest, child: Text('최신순')),
              PopupMenuItem(
                  value: FilesSortOption.oldest, child: Text('오래된순')),
              PopupMenuItem(
                  value: FilesSortOption.largest, child: Text('큰 용량순')),
            ],
            child: Chip(
              avatar: const Icon(Icons.sort, size: 18),
              label: Text(_sortLabel(sort)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          // 타입 필터 칩
          ChoiceChip(
            label: const Text('전체'),
            selected: typeFilter == FilesTypeFilter.all,
            onSelected: (_) => ref
                .read(filesTypeFilterProvider.notifier)
                .state = FilesTypeFilter.all,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('폴더'),
            selected: typeFilter == FilesTypeFilter.foldersOnly,
            onSelected: (_) => ref
                .read(filesTypeFilterProvider.notifier)
                .state = FilesTypeFilter.foldersOnly,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('파일'),
            selected: typeFilter == FilesTypeFilter.filesOnly,
            onSelected: (_) => ref
                .read(filesTypeFilterProvider.notifier)
                .state = FilesTypeFilter.filesOnly,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _sortLabel(FilesSortOption sort) {
    return switch (sort) {
      FilesSortOption.name => '이름순',
      FilesSortOption.newest => '최신순',
      FilesSortOption.oldest => '오래된순',
      FilesSortOption.largest => '큰 용량순',
    };
  }

  // ─── Breadcrumb ───

  Widget _buildBreadcrumb(
      List<FileItemModel> breadcrumbs, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          key: const Key('files_breadcrumb_row'),
          children: [
            InkWell(
              onTap: () {
                _resetFilters();
                ref.read(currentFolderProvider.notifier).state = null;
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '홈',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (int i = 0; i < breadcrumbs.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right,
                    size: 16, color: theme.colorScheme.outline),
              ),
              InkWell(
                onTap: i < breadcrumbs.length - 1
                    ? () {
                        _resetFilters();
                        ref.read(currentFolderProvider.notifier).state =
                            breadcrumbs[i].id;
                      }
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Text(
                    breadcrumbs[i].name,
                    style: TextStyle(
                      color: i < breadcrumbs.length - 1
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: i < breadcrumbs.length - 1
                          ? FontWeight.w500
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Empty State ───

  Widget _buildEmptyState(ThemeData theme, FilesEmptyListKind kind) {
    // 필터/검색 결과가 없는 경우
    if (kind == FilesEmptyListKind.noSearchResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 80, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '검색어나 필터를 변경해보세요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _resetFilters,
              child: const Text('필터 초기화'),
            ),
          ],
        ),
      );
    }

    // 폴더 자체가 빈 경우
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open,
              size: 80, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '빈 폴더입니다',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '파일을 업로드하거나 폴더를 만들어보세요!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Active Filter Bar ───

  Widget _buildActiveFilterBar(
      ThemeData theme, String query, FilesTypeFilter typeFilter) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.filter_list,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (query.isNotEmpty)
                  InputChip(
                    label: Text('"$query"'),
                    avatar: const Icon(Icons.search, size: 16),
                    onDeleted: () {
                      _searchController.clear();
                      ref.read(filesSearchQueryProvider.notifier).state =
                          '';
                      if (_showSearch) setState(() => _showSearch = false);
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (typeFilter != FilesTypeFilter.all)
                  InputChip(
                    label: Text(typeFilter == FilesTypeFilter.foldersOnly
                        ? '폴더만'
                        : '파일만'),
                    onDeleted: () {
                      ref.read(filesTypeFilterProvider.notifier).state =
                          FilesTypeFilter.all;
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _resetFilters,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('전체 해제'),
          ),
        ],
      ),
    );
  }

  // ─── List View ───

  Widget _buildListView(List<FileItemModel> files) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: files.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = files[index];
        return _buildListTile(item);
      },
    );
  }

  Widget _buildListTile(FileItemModel item) {
    return ListTile(
      leading: _buildItemIcon(item, 40),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.isFolder
            ? DateFormat('yyyy.MM.dd').format(item.createdAt)
            : '${_formatFileSize(item.size ?? 0)}  ${DateFormat('yyyy.MM.dd').format(item.createdAt)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showItemOptions(item),
      ),
      onTap: () => _onItemTap(item),
      onLongPress: () => _showItemOptions(item),
    );
  }

  // ─── Grid View ───

  Widget _buildGridView(List<FileItemModel> files) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final item = files[index];
        return _buildGridTile(item);
      },
    );
  }

  Widget _buildGridTile(FileItemModel item) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _onItemTap(item),
      onLongPress: () => _showItemOptions(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildItemIcon(item, 48),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (item.isFile) ...[
              const SizedBox(height: 2),
              Text(
                _formatFileSize(item.size ?? 0),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Item Icon ───

  Widget _buildItemIcon(FileItemModel item, double size) {
    if (item.isFolder) {
      return Icon(Icons.folder, size: size, color: Colors.amber[700]);
    }

    final mime = item.mimeType ?? '';
    IconData iconData;
    Color color;

    if (mime.startsWith('image/')) {
      iconData = Icons.image;
      color = Colors.blue;
    } else if (mime.startsWith('video/')) {
      iconData = Icons.videocam;
      color = Colors.red;
    } else if (mime.startsWith('audio/')) {
      iconData = Icons.audiotrack;
      color = Colors.purple;
    } else if (mime == 'application/pdf') {
      iconData = Icons.picture_as_pdf;
      color = Colors.red[800]!;
    } else if (mime.contains('word') || mime.contains('document')) {
      iconData = Icons.description;
      color = Colors.blue[800]!;
    } else if (mime.contains('sheet') || mime.contains('excel')) {
      iconData = Icons.table_chart;
      color = Colors.green[700]!;
    } else if (mime.contains('presentation') || mime.contains('powerpoint')) {
      iconData = Icons.slideshow;
      color = Colors.orange[700]!;
    } else if (mime.contains('zip') || mime.contains('archive')) {
      iconData = Icons.archive;
      color = Colors.brown;
    } else {
      iconData = Icons.insert_drive_file;
      color = Colors.grey;
    }

    return Icon(iconData, size: size, color: color);
  }

  // ─── FAB ───

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_showFabMenu) ...[
          _buildFabOption(
            icon: Icons.create_new_folder,
            label: '새 폴더',
            onTap: () {
              setState(() => _showFabMenu = false);
              _showCreateFolderDialog();
            },
          ),
          const SizedBox(height: 8),
          _buildFabOption(
            icon: Icons.upload_file,
            label: '파일 업로드',
            onTap: () {
              setState(() => _showFabMenu = false);
              _pickAndUploadFile();
            },
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          onPressed: () {
            setState(() => _showFabMenu = !_showFabMenu);
          },
          child: AnimatedRotation(
            turns: _showFabMenu ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildFabOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          child: Icon(icon),
        ),
      ],
    );
  }

  // ─── Actions ───

  void _onItemTap(FileItemModel item) {
    if (item.isFolder) {
      _resetFilters();
      ref.read(currentFolderProvider.notifier).state = item.id;
    } else {
      _showFileOptionsSheet(item);
    }
  }

  void _navigateBack() {
    _resetFilters();
    final breadcrumbs = ref.read(breadcrumbProvider).valueOrNull ?? [];
    ref.read(currentFolderProvider.notifier).state =
        computeNavigateBackTarget(breadcrumbs);
  }

  /// 폴더 이동 시 검색어·타입 필터 초기화 (정렬은 유지)
  void _resetFilters() {
    _searchController.clear();
    ref.read(filesSearchQueryProvider.notifier).state = '';
    ref.read(filesTypeFilterProvider.notifier).state = FilesTypeFilter.all;
    if (_showSearch) setState(() => _showSearch = false);
  }

  void _showFileOptionsSheet(FileItemModel item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildItemIcon(item, 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall),
                        if (item.size != null)
                          Text(_formatFileSize(item.size!),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (item.isFile)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('다운로드'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile(item);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('이름 변경'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move),
              title: const Text('이동'),
              onTap: () {
                Navigator.pop(context);
                _showMoveDialog(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('삭제', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirm(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showItemOptions(FileItemModel item) {
    _showFileOptionsSheet(item);
  }

  // ─── Create Folder ───

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 폴더'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '폴더 이름',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                _createFolder(name);
              }
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder(String name) async {
    final family = ref.read(currentFamilyProvider).valueOrNull;
    final user = ref.read(authStateProvider).valueOrNull;
    if (family == null || user == null) return;

    final currentFolder = ref.read(currentFolderProvider);
    final repo = ref.read(filesRepositoryProvider);

    try {
      await repo.createFolder(family.id, name, currentFolder, user.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('폴더 생성 실패: $e')),
        );
      }
    }
  }

  // ─── Upload File ───

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;

    final family = ref.read(currentFamilyProvider).valueOrNull;
    final user = ref.read(authStateProvider).valueOrNull;
    if (family == null || user == null) return;

    final currentFolder = ref.read(currentFolderProvider);
    _doUpload(
      family.id, currentFolder, user.uid, pickedFile.path!, pickedFile.name,
    );
  }

  Future<void> _doUpload(
    String familyId,
    String? parentId,
    String userId,
    String filePath,
    String fileName,
  ) async {
    final repo = ref.read(filesRepositoryProvider);
    final transfer = ref.read(fileTransferProvider.notifier);

    transfer.startTransfer(fileName, FileTransferType.upload);
    _retryAction = () => _doUpload(
      familyId, parentId, userId, filePath, fileName,
    );

    try {
      await repo.uploadFile(
        familyId,
        parentId,
        userId,
        filePath,
        fileName,
        onProgress: (progress) {
          transfer.updateProgress(progress);
        },
      );
      transfer.complete();
      _retryAction = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('업로드 완료!')),
        );
      }
    } catch (e) {
      transfer.fail(_friendlyError(e));
    }
  }

  // ─── Download File ───

  Future<void> _downloadFile(FileItemModel item) async {
    final repo = ref.read(filesRepositoryProvider);
    final transfer = ref.read(fileTransferProvider.notifier);

    transfer.startTransfer(item.name, FileTransferType.download);
    _retryAction = () => _downloadFile(item);

    try {
      final localPath = await repo.downloadFile(
        item,
        onProgress: (progress) {
          transfer.updateProgress(progress);
        },
      );
      transfer.complete();
      _retryAction = null;

      if (mounted) {
        await Share.shareXFiles([XFile(localPath)]);
      }
    } catch (e) {
      transfer.fail(_friendlyError(e));
    }
  }

  // ─── Rename ───

  void _showRenameDialog(FileItemModel item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '새 이름',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = validateRename(item.name, controller.text);
              if (name != null) {
                Navigator.pop(context);
                _renameItem(item, name);
              }
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameItem(FileItemModel item, String newName) async {
    final family = ref.read(currentFamilyProvider).valueOrNull;
    if (family == null) return;

    final repo = ref.read(filesRepositoryProvider);
    try {
      await repo.renameItem(family.id, item.id, newName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이름 변경 실패: $e')),
        );
      }
    }
  }

  // ─── Delete ───

  void _showDeleteConfirm(FileItemModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제'),
        content: Text(deleteConfirmMessage(item)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(item);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(FileItemModel item) async {
    final family = ref.read(currentFamilyProvider).valueOrNull;
    if (family == null) return;

    final repo = ref.read(filesRepositoryProvider);
    try {
      await repo.deleteItem(family.id, item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${item.name}" 삭제됨')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  // ─── Move ───

  void _showMoveDialog(FileItemModel item) {
    showDialog(
      context: context,
      builder: (context) => _MoveDialog(item: item),
    );
  }

  // ─── Transfer Card ───

  Widget _buildTransferCard(FileTransferState transfer, ThemeData theme) {
    final isUpload = transfer.type == FileTransferType.upload;
    final label = isUpload ? '업로드' : '다운로드';
    final isFailed = transfer.status == FileTransferStatus.failed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFailed
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFailed
                    ? Icons.error_outline
                    : (isUpload ? Icons.upload : Icons.download),
                size: 20,
                color: isFailed
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFailed
                      ? '$label 실패: ${transfer.fileName}'
                      : '$label 중: ${transfer.fileName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isFailed
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isFailed)
                Text(
                  '${(transfer.progress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  ref.read(fileTransferProvider.notifier).dismiss();
                  _retryAction = null;
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18,
                      color: isFailed
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
          if (!isFailed) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: transfer.progress,
                minHeight: 6,
              ),
            ),
          ],
          if (isFailed) ...[
            const SizedBox(height: 4),
            Text(
              transfer.error ?? '알 수 없는 오류',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (_retryAction != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: _retryAction,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('다시 시도'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _friendlyError(dynamic e) => friendlyTransferError(e);

  // ─── Utils ───

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ─── Move Dialog (별도 위젯) ───

class _MoveDialog extends ConsumerStatefulWidget {
  final FileItemModel item;

  const _MoveDialog({required this.item});

  @override
  ConsumerState<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends ConsumerState<_MoveDialog> {
  String? _selectedFolderId; // null = 루트
  List<FileItemModel> _folders = [];
  List<FileItemModel> _breadcrumb = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders(null);
  }

  Future<void> _loadFolders(String? parentId) async {
    setState(() => _loading = true);

    final family = ref.read(currentFamilyProvider).valueOrNull;
    if (family == null) return;

    final repo = ref.read(filesRepositoryProvider);

    final items = await repo
        .getFilesStream(family.id, parentId)
        .first;
    final folders = filterMoveTargets(items, widget.item.id);

    final breadcrumb = await repo.buildBreadcrumb(family.id, parentId);

    setState(() {
      _selectedFolderId = parentId;
      _folders = folders;
      _breadcrumb = breadcrumb;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이동할 위치 선택'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 경로 표시
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _loadFolders(null),
                    child: Text('홈',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.primary)),
                  ),
                  for (int i = 0; i < _breadcrumb.length; i++) ...[
                    const Text(' > '),
                    InkWell(
                      onTap: () => _loadFolders(_breadcrumb[i].id),
                      child: Text(_breadcrumb[i].name,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _folders.isEmpty
                      ? const Center(child: Text('하위 폴더 없음'))
                      : ListView.builder(
                          itemCount: _folders.length,
                          itemBuilder: (context, index) {
                            final folder = _folders[index];
                            return ListTile(
                              leading: Icon(Icons.folder,
                                  color: Colors.amber[700]),
                              title: Text(folder.name),
                              dense: true,
                              onTap: () =>
                                  _loadFolders(folder.id),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            await _moveItem();
          },
          child: const Text('여기로 이동'),
        ),
      ],
    );
  }

  Future<void> _moveItem() async {
    final family = ref.read(currentFamilyProvider).valueOrNull;
    if (family == null) return;

    final repo = ref.read(filesRepositoryProvider);
    try {
      await repo.moveItem(family.id, widget.item.id, _selectedFolderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${widget.item.name}" 이동 완료')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이동 실패: $e')),
        );
      }
    }
  }
}
