import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/shared/models/family_model.dart';
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
              onPressed: () => _showTodoEditorSheet(
                context,
                familyAsync.valueOrNull!.id,
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showTodoEditorSheet(BuildContext context, String familyId,
      {TodoModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TodoEditorSheet(
        familyId: familyId,
        existing: existing,
      ),
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
    final membersAsync = ref.watch(familyMembersProvider(familyId));
    final theme = Theme.of(context);

    return todosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (todos) => membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (members) {
          if (todos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.grey),
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
                      members: members,
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
                      members: members,
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

// --- Todo Tile ---

class _TodoTile extends ConsumerWidget {
  final TodoModel todo;
  final String familyId;
  final List<FamilyMember> members;

  const _TodoTile({
    required this.todo,
    required this.familyId,
    required this.members,
  });

  static final _dueFormat = DateFormat('M월 d일', 'ko_KR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assigneeLabel = _assigneeSummary(todo, members);

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todo.description != null &&
                  todo.description!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    todo.description!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  Text(
                    todo.dueDate != null
                        ? _dueFormat.format(todo.dueDate!)
                        : '마감 없음',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: todo.dueDate != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.people_outline,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.55,
                    ),
                    child: Text(
                      assigneeLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (todo.category != null)
                    Chip(
                      label: Text(
                        todo.category!,
                        style: theme.textTheme.labelSmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: '편집',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => _TodoEditorSheet(
                familyId: familyId,
                existing: todo,
              ),
            );
          },
        ),
      ),
    );
  }

  static String _assigneeSummary(TodoModel todo, List<FamilyMember> members) {
    if (todo.assignedTo.isEmpty) return '담당: 미지정';
    final names = <String>[];
    for (final uid in todo.assignedTo) {
      FamilyMember? found;
      for (final m in members) {
        if (m.uid == uid) {
          found = m;
          break;
        }
      }
      if (found != null) {
        final n = found.nickname.trim();
        names.add(n.isEmpty ? '이름 없음' : n);
      } else {
        names.add('알 수 없음');
      }
    }
    return '담당: ${names.join(', ')}';
  }
}

// --- Add / Edit Todo Sheet ---

class _TodoEditorSheet extends ConsumerStatefulWidget {
  final String familyId;
  final TodoModel? existing;

  const _TodoEditorSheet({
    required this.familyId,
    this.existing,
  });

  @override
  ConsumerState<_TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends ConsumerState<_TodoEditorSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _category;
  DateTime? _dueDate;
  List<String> _assignedTo = [];

  static const _categories = ['장보기', '집안일', '학교', '기타'];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _descController.text = e.description ?? '';
      _category = e.category;
      _dueDate = e.dueDate;
      _assignedTo = List<String>.from(e.assignedTo);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider(widget.familyId));
    final theme = Theme.of(context);

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
              _isEdit ? '할 일 편집' : '할 일 추가',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: !_isEdit,
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
            DropdownButtonFormField<String?>(
              value: _category,
              decoration: const InputDecoration(labelText: '카테고리 (선택)'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('선택 안 함'),
                ),
                ..._categories.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                ),
              ],
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '담당자 (선택)',
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Text(
                _isEdit
                    ? '담당자 목록을 불러오지 못했습니다. 저장하면 현재 담당 설정이 유지됩니다.'
                    : '담당자 목록을 불러오지 못했습니다. 일단 담당 없이 저장할 수 있습니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              data: (members) {
                if (members.isEmpty) {
                  return Text(
                    '가족 구성원이 없습니다.',
                    style: TextStyle(color: theme.colorScheme.outline),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: members.map((m) {
                        final selected = _assignedTo.contains(m.uid);
                        final label = m.nickname.trim().isEmpty
                            ? '이름 없음'
                            : m.nickname;
                        return FilterChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                if (!_assignedTo.contains(m.uid)) {
                                  _assignedTo = [..._assignedTo, m.uid];
                                }
                              } else {
                                _assignedTo = _assignedTo
                                    .where((id) => id != m.uid)
                                    .toList();
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_assignedTo.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _assignedTo = []),
                          child: const Text('담당 해제 (전체)'),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEdit ? '저장' : '추가'),
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

    final descText = _descController.text.trim();
    final repo = ref.read(todoRepositoryProvider);

    if (_isEdit) {
      final existing = widget.existing!;
      await repo.updateTodo(
        widget.familyId,
        TodoModel(
          id: existing.id,
          title: title,
          description: descText.isEmpty ? null : descText,
          assignedTo: _assignedTo,
          createdBy: existing.createdBy,
          category: _category,
          dueDate: _dueDate,
          reminders: existing.reminders,
          isCompleted: existing.isCompleted,
          completedBy: existing.completedBy,
          completedAt: existing.completedAt,
          createdAt: existing.createdAt,
        ),
      );
    } else {
      final todo = TodoModel(
        id: const Uuid().v4(),
        title: title,
        description: descText.isEmpty ? null : descText,
        createdBy: authState.uid,
        category: _category,
        dueDate: _dueDate,
        assignedTo: _assignedTo,
        createdAt: DateTime.now(),
      );
      await repo.createTodo(widget.familyId, todo);
    }

    if (mounted) Navigator.pop(context);
  }
}
