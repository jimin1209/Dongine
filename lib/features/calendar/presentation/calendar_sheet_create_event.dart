part of 'calendar_screen.dart';

class _CreateEventSheet extends ConsumerStatefulWidget {
  final String familyId;

  const _CreateEventSheet({required this.familyId});

  @override
  ConsumerState<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends ConsumerState<_CreateEventSheet> {
  final _titleController = TextEditingController();
  String _type = 'general';
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  bool _isAllDay = false;
  final List<String> _assignedTo = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate;
  }

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
            Text('새 일정', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Type selector
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: '유형',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('일반')),
                DropdownMenuItem(value: 'meal', child: Text('식사')),
                DropdownMenuItem(value: 'date', child: Text('데이트')),
                DropdownMenuItem(
                    value: 'anniversary', child: Text('기념일')),
                DropdownMenuItem(value: 'hospital', child: Text('병원')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'general'),
            ),
            const SizedBox(height: 12),
            // All day toggle
            SwitchListTile(
              title: const Text('종일'),
              value: _isAllDay,
              onChanged: (v) => setState(() => _isAllDay = v),
              contentPadding: EdgeInsets.zero,
            ),
            // Date pickers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('M/d (E)', 'ko_KR')
                        .format(_startDate)),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          _startDate = date;
                          if (_endDate.isBefore(_startDate)) {
                            _endDate = _startDate;
                          }
                        });
                      }
                    },
                  ),
                ),
                if (!_isAllDay) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) {
                        setState(() => _startTime = time);
                      }
                    },
                    child: Text(
                        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}'),
                  ),
                ],
              ],
            ),
            if (!_isAllDay) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('M/d (E)', 'ko_KR')
                          .format(_endDate)),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setState(() => _endDate = date);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() => _endTime = time);
                      }
                    },
                    child: Text(
                        '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Assign members
            if (members.isNotEmpty) ...[
              Text('참여 가족', style: Theme.of(context).textTheme.bodyMedium),
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

    final user = _readCalendarActionUser(ref);
    if (user == null) return;

    final startAt = _isAllDay
        ? _startDate
        : DateTime(_startDate.year, _startDate.month, _startDate.day,
            _startTime.hour, _startTime.minute);
    final endAt = _isAllDay
        ? _startDate.add(const Duration(hours: 23, minutes: 59))
        : DateTime(_endDate.year, _endDate.month, _endDate.day,
            _endTime.hour, _endTime.minute);

    final event = EventModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      type: _type,
      startAt: startAt,
      endAt: endAt,
      isAllDay: _isAllDay,
      color: _eventTypeColor(_type),
      assignedTo: _assignedTo,
      createdBy: user.uid,
      createdAt: DateTime.now(),
    );

    ref
        .read(calendarRepositoryProvider)
        .createEvent(widget.familyId, event);
    Navigator.of(context).pop();
  }
}
