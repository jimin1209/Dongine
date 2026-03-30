import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/cart/data/cart_repository.dart';
import 'package:dongine/features/cart/domain/cart_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/cart_item_model.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _quickAddController = TextEditingController();
  final _quickAddFocusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _quickAddFocusNode.addListener(_onFocusChange);
    _quickAddController.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _quickAddFocusNode.removeListener(_onFocusChange);
    _quickAddController.removeListener(_onTextChange);
    _quickAddController.dispose();
    _quickAddFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showSuggestions = _quickAddFocusNode.hasFocus;
    });
  }

  void _onTextChange() {
    // Rebuild to update suggestion visibility
    setState(() {});
  }

  String? get _currentUserId {
    final authState = ref.read(authStateProvider).valueOrNull;
    return authState?.uid;
  }

  String? get _familyId {
    final family = ref.read(currentFamilyProvider).valueOrNull;
    return family?.id;
  }

  Future<void> _quickAdd() async {
    final name = _quickAddController.text.trim();
    if (name.isEmpty) return;
    final familyId = _familyId;
    final userId = _currentUserId;
    if (familyId == null || userId == null) return;

    final repo = ref.read(cartRepositoryProvider);
    await repo.addOrMergeItem(familyId, name, userId);
    _quickAddController.clear();
    _quickAddFocusNode.requestFocus();
    // Invalidate frequent items so they refresh
    ref.invalidate(frequentItemsProvider(familyId));
  }

  Future<void> _addSuggestion(String name) async {
    final familyId = _familyId;
    final userId = _currentUserId;
    if (familyId == null || userId == null) return;

    final repo = ref.read(cartRepositoryProvider);
    await repo.addOrMergeItem(familyId, name, userId);
    ref.invalidate(frequentItemsProvider(familyId));
  }

  Future<void> _showAddItemSheet() async {
    final familyId = _familyId;
    final userId = _currentUserId;
    if (familyId == null || userId == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddEditItemSheet(
        familyId: familyId,
        userId: userId,
        repo: ref.read(cartRepositoryProvider),
      ),
    );
    ref.invalidate(frequentItemsProvider(familyId));
  }

  Future<void> _showEditItemSheet(CartItemModel item) async {
    final familyId = _familyId;
    if (familyId == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddEditItemSheet(
        familyId: familyId,
        userId: _currentUserId ?? '',
        repo: ref.read(cartRepositoryProvider),
        editItem: item,
      ),
    );
  }

  Future<void> _confirmClearChecked() async {
    final familyId = _familyId;
    if (familyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구매 완료 항목 삭제'),
        content: const Text('체크된 항목을 모두 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(cartRepositoryProvider).clearCheckedItems(familyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);
    final filter = ref.watch(cartFilterProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return familyAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('오류가 발생했어요: $e')),
      ),
      data: (family) {
        if (family == null) {
          return const Scaffold(
            body: Center(child: Text('가족 그룹에 참여해주세요')),
          );
        }

        final itemsAsync = ref.watch(cartItemsProvider(family.id));
        final frequentAsync = ref.watch(frequentItemsProvider(family.id));

        // Get current cart item names for filtering suggestions
        final currentItemNames = itemsAsync.valueOrNull
                ?.where((i) => !i.isChecked)
                .map((i) => i.name)
                .toSet() ??
            <String>{};

        return Scaffold(
          appBar: AppBar(
            title: const Text('장보기 목록'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: '구매 완료 항목 삭제',
                onPressed: _confirmClearChecked,
              ),
            ],
          ),
          body: Column(
            children: [
              // Category filter chips
              _CategoryFilterBar(
                selected: filter,
                onSelected: (cat) {
                  ref.read(cartFilterProvider.notifier).state = cat;
                },
              ),
              // Item list
              Expanded(
                child: itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('오류: $e')),
                  data: (items) {
                    // Apply filter
                    final filtered = filter == null
                        ? items
                        : items
                            .where((item) => item.category == filter)
                            .toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          '장보기 목록이 비어있어요',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }

                    final unchecked =
                        filtered.where((i) => !i.isChecked).toList();
                    final checked =
                        filtered.where((i) => i.isChecked).toList();
                    final uncheckedCount = unchecked.length;

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 80),
                      children: [
                        // Remaining count header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            '남은 항목: $uncheckedCount개',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Unchecked items
                        ...unchecked.map((item) => _CartItemTile(
                              key: ValueKey(item.id),
                              item: item,
                              familyId: family.id,
                              onEdit: () => _showEditItemSheet(item),
                            )),
                        // Checked items section
                        if (checked.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              '구매 완료 (${checked.length})',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ...checked.map((item) => _CartItemTile(
                                key: ValueKey(item.id),
                                item: item,
                                familyId: family.id,
                                onEdit: () => _showEditItemSheet(item),
                              )),
                        ],
                      ],
                    );
                  },
                ),
              ),
              // Frequent items suggestion chips
              if (_showSuggestions && _quickAddController.text.trim().isEmpty)
                frequentAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (suggestions) {
                    // Filter out items already in the unchecked cart
                    final filtered = suggestions
                        .where((s) => !currentItemNames.contains(s))
                        .toList();
                    if (filtered.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      width: double.infinity,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: filtered.map((name) {
                          return ActionChip(
                            label: Text(name),
                            avatar: const Icon(Icons.history, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _addSuggestion(name),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              // Quick add bar
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _quickAddController,
                          focusNode: _quickAddFocusNode,
                          decoration: const InputDecoration(
                            hintText: '빠른 추가 (이름 입력 후 엔터)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _quickAdd(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _quickAdd,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddItemSheet,
            child: const Icon(Icons.add_shopping_cart),
          ),
        );
      },
    );
  }
}

// --- Category Filter Bar ---

class _CategoryFilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _CategoryFilterBar({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = ['전체', ...CartItemModel.categories];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isAll = cat == '전체';
          final isSelected = isAll ? selected == null : selected == cat;

          return FilterChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (_) {
              onSelected(isAll ? null : cat);
            },
          );
        },
      ),
    );
  }
}

// --- Cart Item Tile ---

class _CartItemTile extends ConsumerWidget {
  final CartItemModel item;
  final String familyId;
  final VoidCallback onEdit;

  const _CartItemTile({
    super.key,
    required this.item,
    required this.familyId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(cartRepositoryProvider);
    final userId = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('항목 삭제'),
            content: Text('"${item.name}"을(를) 삭제하시겠어요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => repo.deleteItem(familyId, item.id),
      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (val) {
            repo.toggleItem(familyId, item.id, val ?? false, userId);
          },
        ),
        title: Text(
          item.name,
          style: item.isChecked
              ? theme.textTheme.bodyLarge?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                )
              : null,
        ),
        subtitle: item.category != null
            ? Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    item.category!,
                    style: const TextStyle(fontSize: 11),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 6),
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: item.quantity > 1
                  ? () => repo.updateQuantity(
                      familyId, item.id, item.quantity - 1)
                  : null,
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${item.quantity}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: item.quantity < 99
                  ? () => repo.updateQuantity(
                      familyId, item.id, item.quantity + 1)
                  : null,
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

// --- Add/Edit Item Bottom Sheet ---

class _AddEditItemSheet extends StatefulWidget {
  final String familyId;
  final String userId;
  final CartRepository repo;
  final CartItemModel? editItem;

  const _AddEditItemSheet({
    required this.familyId,
    required this.userId,
    required this.repo,
    this.editItem,
  });

  @override
  State<_AddEditItemSheet> createState() => _AddEditItemSheetState();
}

class _AddEditItemSheetState extends State<_AddEditItemSheet> {
  final _nameController = TextEditingController();
  int _quantity = 1;
  String? _category;

  bool get _isEditing => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.editItem!.name;
      _quantity = widget.editItem!.quantity;
      _category = widget.editItem!.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_isEditing) {
      final item = widget.editItem!;
      await widget.repo.updateItem(
        widget.familyId,
        item.id,
        name: name != item.name ? name : null,
        quantity: _quantity != item.quantity ? _quantity : null,
        category: _category != item.category ? _category : null,
        clearCategory: _category == null && item.category != null,
      );
    } else {
      await widget.repo.addOrMergeItem(
        widget.familyId,
        name,
        widget.userId,
        quantity: _quantity,
        category: _category,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? '항목 편집' : '항목 추가',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '이름',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          // Quantity selector
          Row(
            children: [
              const Text('수량: '),
              IconButton(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_quantity',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: _quantity < 99
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Category dropdown
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: '카테고리',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('없음'),
              ),
              ...CartItemModel.categories.map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  )),
            ],
            onChanged: (val) => setState(() => _category = val),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            child: Text(_isEditing ? '저장' : '추가'),
          ),
        ],
      ),
    );
  }
}
