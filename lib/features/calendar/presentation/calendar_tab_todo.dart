part of 'calendar_screen.dart';

class _TodoTab extends ConsumerWidget {
  final String familyId;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const _TodoTab({
    required this.familyId,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  static const _categories = ['전체', '장보기', '집안일', '학교', '기타'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosProvider(familyId));
    final authState = ref.watch(authStateProvider);
    final currentUserId = authState.valueOrNull?.uid ?? '';
    final membersAsync = ref.watch(familyMembersProvider(familyId));
    final theme = Theme.of(context);

    return Column(
      children: [
        // Category filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: _categories.map((cat) {
              final isSelected = selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => onCategoryChanged(cat),
                ),
              );
            }).toList(),
          ),
        ),
        // Summary bar
        todosAsync.when(
          data: (todos) {
            final filtered = selectedCategory == '전체'
                ? todos
                : todos.where((t) => t.category == selectedCategory).toList();
            final total = filtered.length;
            final done = filtered.where((t) => t.isCompleted).length;
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final overdue = filtered
                .where((t) =>
                    !t.isCompleted &&
                    t.dueDate != null &&
                    DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day)
                        .isBefore(today))
                .length;
            final dueSoon = filtered
                .where((t) =>
                    !t.isCompleted &&
                    t.dueDate != null &&
                    !DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day)
                        .isBefore(today) &&
                    t.dueDate!.difference(now).inDays <= 2)
                .length;

            if (total == 0) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text('$done/$total 완료',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600)),
                  if (total > 0) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      height: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: total > 0 ? done / total : 0,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (overdue > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('지연 $overdue',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (dueSoon > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('임박 $dueSoon',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: todosAsync.when(
            data: (todos) {
              final filtered = selectedCategory == '전체'
                  ? todos
                  : todos
                      .where((t) => t.category == selectedCategory)
                      .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt,
                          size: 48,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text(
                        selectedCategory == '전체'
                            ? '할 일이 없습니다\n+버튼으로 추가해보세요'
                            : '\'$selectedCategory\' 항목이 없습니다',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Sort: incomplete first, then overdue first, then by due date
              final sorted = List<TodoModel>.from(filtered)..sort((a, b) {
                if (a.isCompleted != b.isCompleted) {
                  return a.isCompleted ? 1 : -1;
                }
                final aDue = a.dueDate;
                final bDue = b.dueDate;
                if (aDue == null && bDue == null) return 0;
                if (aDue == null) return 1;
                if (bDue == null) return -1;
                return aDue.compareTo(bDue);
              });

              return ListView.builder(
                itemCount: sorted.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final todo = sorted[index];
                  final members = membersAsync.valueOrNull ?? [];
                  return Dismissible(
                    key: Key(todo.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Colors.red,
                      child:
                          const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(todoRepositoryProvider)
                          .deleteTodo(familyId, todo.id);
                    },
                    child: _TodoTile(
                      todo: todo,
                      members: members,
                      onToggle: (value) {
                        ref.read(todoRepositoryProvider).toggleTodo(
                            familyId, todo.id, value, currentUserId);
                      },
                    ),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),
        ),
      ],
    );
  }
}

class _TodoTile extends StatelessWidget {
  final TodoModel todo;
  final List<FamilyMember> members;
  final ValueChanged<bool> onToggle;

  const _TodoTile({
    required this.todo,
    required this.members,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueBadge = _buildDueBadge();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (v) => onToggle(v ?? false),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration:
                todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted
                ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                : null,
          ),
        ),
        subtitle: Row(
          children: [
            if (todo.category != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _categoryColor(todo.category!).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(todo.category!,
                    style: TextStyle(
                        fontSize: 10,
                        color: _categoryColor(todo.category!))),
              ),
              const SizedBox(width: 4),
            ],
            if (todo.assignedTo.isNotEmpty)
              ...todo.assignedTo.take(2).map((uid) {
                final member =
                    members.where((m) => m.uid == uid).firstOrNull;
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: CircleAvatar(
                    radius: 10,
                    child: Text(
                      member?.nickname.isNotEmpty == true
                          ? member!.nickname[0]
                          : '?',
                      style: const TextStyle(fontSize: 8),
                    ),
                  ),
                );
              }),
          ],
        ),
        trailing: dueBadge,
      ),
    );
  }

  Widget? _buildDueBadge() {
    if (todo.dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
        todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day);
    final diff = due.difference(today).inDays;

    Color badgeColor;
    String label;

    if (todo.isCompleted) {
      badgeColor = Colors.grey;
      label = DateFormat('M/d').format(todo.dueDate!);
    } else if (diff < 0) {
      badgeColor = Colors.red;
      label = '${-diff}일 지연';
    } else if (diff == 0) {
      badgeColor = Colors.red;
      label = '오늘 마감';
    } else if (diff <= 2) {
      badgeColor = Colors.orange;
      label = diff == 1 ? '내일 마감' : 'D-$diff';
    } else {
      badgeColor = Colors.grey;
      label = DateFormat('M/d').format(todo.dueDate!);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: diff <= 0 && !todo.isCompleted
            ? Border.all(color: badgeColor.withValues(alpha: 0.4))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: diff <= 2 && !todo.isCompleted
              ? FontWeight.w600
              : FontWeight.normal,
          color: badgeColor,
        ),
      ),
    );
  }

  static Color _categoryColor(String category) {
    switch (category) {
      case '장보기':
        return Colors.green;
      case '집안일':
        return Colors.blue;
      case '학교':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
