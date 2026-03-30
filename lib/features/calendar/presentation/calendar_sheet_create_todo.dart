part of 'calendar_screen.dart';

class _CreateTodoSheet extends ConsumerStatefulWidget {
  final String familyId;

  const _CreateTodoSheet({required this.familyId});

  @override
  ConsumerState<_CreateTodoSheet> createState() => _CreateTodoSheetState();
}

class _CreateTodoSheetState extends ConsumerState<_CreateTodoSheet> {
  final _titleController = TextEditingController();
  String? _category;
  DateTime? _dueDate;
  final List<String> _assignedTo = [];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider(widget.familyId));
    final members = membersAsync.valueOrNull ?? [];

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
            Text('새 할 일', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Category
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: '카테고리',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '장보기', child: Text('장보기')),
                DropdownMenuItem(value: '집안일', child: Text('집안일')),
                DropdownMenuItem(value: '학교', child: Text('학교')),
                DropdownMenuItem(value: '기타', child: Text('기타')),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            // Due date
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_dueDate != null
                  ? DateFormat('M월 d일 (E)', 'ko_KR').format(_dueDate!)
                  : '마감일 선택'),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _dueDate = date);
              },
            ),
            const SizedBox(height: 12),
            // Assign members
            if (members.isNotEmpty) ...[
              Text('담당자', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: members.map((m) {
                  final isSelected = _assignedTo.contains(m.uid);
                  return FilterChip(
                    label: Text(m.nickname),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _assignedTo.add(m.uid);
                        } else {
                          _assignedTo.remove(m.uid);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final todo = TodoModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      assignedTo: _assignedTo,
      createdBy: user.uid,
      category: _category,
      dueDate: _dueDate,
      createdAt: DateTime.now(),
    );

    ref.read(todoRepositoryProvider).createTodo(widget.familyId, todo);
    Navigator.of(context).pop();
  }
}
