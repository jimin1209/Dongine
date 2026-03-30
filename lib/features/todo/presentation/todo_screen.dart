import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/shared/models/todo_model.dart';

class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('할 일'),
      ),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (family) {
          if (family == null) {
            return const Center(child: Text('가족 그룹에 참여해주세요'));
          }
          return _TodoList(familyId: family.id);
        },
      ),
      floatingActionButton: familyAsync.valueOrNull != null
          ? FloatingActionButton(
              onPressed: () => _showAddTodoSheet(
                context,
                ref,
                familyAsync.valueOrNull!.id,
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddTodoSheet(
      BuildContext context, WidgetRef ref, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddTodoSheet(familyId: familyId),
    );
  }
}

// --- Todo List ---

class _TodoList extends ConsumerWidget {
  final String familyId;
  const _TodoList({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosProvider(familyId));
    final theme = Theme.of(context);

    return todosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (todos) {
        if (todos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('할 일이 없습니다'),
                SizedBox(height: 8),
                Text(
                  '+ 버튼을 눌러 할 일을 추가하세요',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final pending = todos.where((t) => !t.isCompleted).toList();
        final completed = todos.where((t) => t.isCompleted).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (pending.isNotEmpty) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '미완료 (${pending.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...pending.map((todo) => _TodoTile(
                    todo: todo,
                    familyId: familyId,
                  )),
            ],
            if (completed.isNotEmpty) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '완료 (${completed.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              ...completed.map((todo) => _TodoTile(
                    todo: todo,
                    familyId: familyId,
                  )),
            ],
          ],
        );
      },
    );
  }
}

// --- Todo Tile ---

class _TodoTile extends ConsumerWidget {
  final TodoModel todo;
  final String familyId;

  const _TodoTile({required this.todo, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('할 일 삭제'),
          content: Text('"${todo.title}"을(를) 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        final repo = ref.read(todoRepositoryProvider);
        repo.deleteTodo(familyId, todo.id);
      },
      child: ListTile(
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (v) {
            if (v == null) return;
            final authState = ref.read(authStateProvider).valueOrNull;
            if (authState == null) return;
            final repo = ref.read(todoRepositoryProvider);
            repo.toggleTodo(familyId, todo.id, v, authState.uid);
          },
        ),
        title: Text(
          todo.title,
          style: todo.isCompleted
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.outline,
                )
              : null,
        ),
        subtitle: _buildSubtitle(theme),
        trailing: todo.category != null
            ? Chip(
                label: Text(
                  todo.category!,
                  style: theme.textTheme.labelSmall,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )
            : null,
      ),
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final parts = <String>[];
    if (todo.description != null && todo.description!.isNotEmpty) {
      parts.add(todo.description!);
    }
    if (todo.dueDate != null) {
      parts.add(
          '마감: ${todo.dueDate!.month}/${todo.dueDate!.day}');
    }
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: theme.colorScheme.outline),
    );
  }
}

// --- Add Todo Sheet ---

class _AddTodoSheet extends ConsumerStatefulWidget {
  final String familyId;
  const _AddTodoSheet({required this.familyId});

  @override
  ConsumerState<_AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends ConsumerState<_AddTodoSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _category;
  DateTime? _dueDate;

  static const _categories = ['장보기', '집안일', '학교', '기타'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '할 일 추가',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '무엇을 해야 하나요?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: '카테고리 (선택)'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_dueDate != null
                  ? '마감일: ${_dueDate!.year}/${_dueDate!.month}/${_dueDate!.day}'
                  : '마감일 선택 (선택)'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
                  const Icon(Icons.calendar_today),
                ],
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _dueDate = date);
                }
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final authState = ref.read(authStateProvider).valueOrNull;
    if (authState == null) return;

    final todo = TodoModel(
      id: const Uuid().v4(),
      title: title,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      createdBy: authState.uid,
      category: _category,
      dueDate: _dueDate,
      createdAt: DateTime.now(),
    );

    final repo = ref.read(todoRepositoryProvider);
    await repo.createTodo(widget.familyId, todo);
    if (mounted) Navigator.pop(context);
  }
}
