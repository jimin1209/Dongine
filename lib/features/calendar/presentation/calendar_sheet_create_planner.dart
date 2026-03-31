part of 'calendar_screen.dart';

class _CreatePlannerSheet extends ConsumerStatefulWidget {
  final String familyId;

  const _CreatePlannerSheet({required this.familyId});

  @override
  ConsumerState<_CreatePlannerSheet> createState() =>
      _CreatePlannerSheetState();
}

class _CreatePlannerSheetState extends ConsumerState<_CreatePlannerSheet> {
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: _selectedType == null
          ? _buildTypeSelection()
          : _buildTypeForm(),
    );
  }

  Widget _buildTypeSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('플래너 유형 선택',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _TypeSelectionTile(
          icon: Icons.restaurant,
          label: '식사',
          subtitle: '메뉴 투표, 장소 선택',
          onTap: () => setState(() => _selectedType = 'meal'),
        ),
        _TypeSelectionTile(
          icon: Icons.favorite,
          label: '데이트',
          subtitle: '코스, 장소, 예산',
          onTap: () => setState(() => _selectedType = 'date'),
        ),
        _TypeSelectionTile(
          icon: Icons.cake,
          label: '기념일',
          subtitle: 'D-day 카운트',
          onTap: () => setState(() => _selectedType = 'anniversary'),
        ),
        _TypeSelectionTile(
          icon: Icons.local_hospital,
          label: '병원',
          subtitle: '장소, 시간',
          onTap: () => setState(() => _selectedType = 'hospital'),
        ),
      ],
    );
  }

  Widget _buildTypeForm() {
    switch (_selectedType) {
      case 'meal':
        return _MealPlannerForm(
          familyId: widget.familyId,
          onBack: () => setState(() => _selectedType = null),
        );
      case 'date':
        return _DatePlannerForm(
          familyId: widget.familyId,
          onBack: () => setState(() => _selectedType = null),
        );
      case 'anniversary':
        return _AnniversaryPlannerForm(
          familyId: widget.familyId,
          onBack: () => setState(() => _selectedType = null),
        );
      case 'hospital':
        return _HospitalPlannerForm(
          familyId: widget.familyId,
          onBack: () => setState(() => _selectedType = null),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _TypeSelectionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeSelectionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _MealPlannerForm extends ConsumerStatefulWidget {
  final String familyId;
  final VoidCallback onBack;

  const _MealPlannerForm({required this.familyId, required this.onBack});

  @override
  ConsumerState<_MealPlannerForm> createState() => _MealPlannerFormState();
}

class _MealPlannerFormState extends ConsumerState<_MealPlannerForm> {
  final _titleController = TextEditingController();
  final _menuOptionController = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  final List<String> _menuOptions = [];

  @override
  void dispose() {
    _titleController.dispose();
    _menuOptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back)),
              Text('식사 플래너',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                      DateFormat('M/d (E)', 'ko_KR').format(_date)),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _date = date);
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (time != null) setState(() => _time = time);
                },
                child: Text(
                    '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('메뉴 옵션', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _menuOptionController,
                  decoration: const InputDecoration(
                    hintText: '메뉴 이름',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  if (_menuOptionController.text.trim().isNotEmpty) {
                    setState(() {
                      _menuOptions.add(_menuOptionController.text.trim());
                      _menuOptionController.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _menuOptions.map((opt) {
              return Chip(
                label: Text(opt),
                onDeleted: () =>
                    setState(() => _menuOptions.remove(opt)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    final user = _readCalendarActionUser(ref);
    if (user == null) return;

    final startAt = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);

    final event = EventModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      type: 'meal',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
      color: _eventTypeColor('meal'),
      createdBy: user.uid,
      createdAt: DateTime.now(),
      mealVote: {
        'options': _menuOptions,
        'votes': <String, String>{},
        'decided': null,
      },
    );

    ref
        .read(calendarRepositoryProvider)
        .createEvent(widget.familyId, event);
    Navigator.of(context).pop();
  }
}

class _DatePlannerForm extends ConsumerStatefulWidget {
  final String familyId;
  final VoidCallback onBack;

  const _DatePlannerForm({required this.familyId, required this.onBack});

  @override
  ConsumerState<_DatePlannerForm> createState() => _DatePlannerFormState();
}

class _DatePlannerFormState extends ConsumerState<_DatePlannerForm> {
  final _titleController = TextEditingController();
  final _budgetController = TextEditingController();
  final _placeNameController = TextEditingController();
  final _placeAddressController = TextEditingController();
  DateTime _date = DateTime.now();
  final List<Map<String, dynamic>> _places = [];

  @override
  void dispose() {
    _titleController.dispose();
    _budgetController.dispose();
    _placeNameController.dispose();
    _placeAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back)),
              Text('데이트 플래너',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(DateFormat('M/d (E)', 'ko_KR').format(_date)),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (date != null) setState(() => _date = date);
            },
          ),
          const SizedBox(height: 12),
          Text('코스 장소', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          TextField(
            controller: _placeNameController,
            decoration: const InputDecoration(
              hintText: '장소 이름',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _placeAddressController,
                  decoration: const InputDecoration(
                    hintText: '주소 (선택)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  if (_placeNameController.text.trim().isNotEmpty) {
                    setState(() {
                      _places.add({
                        'name': _placeNameController.text.trim(),
                        'address': _placeAddressController.text.trim(),
                        'order': _places.length,
                      });
                      _placeNameController.clear();
                      _placeAddressController.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._places.asMap().entries.map((entry) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 12,
                  child: Text('${entry.key + 1}',
                      style: const TextStyle(fontSize: 11)),
                ),
                title: Text(entry.value['name'] ?? ''),
                subtitle: entry.value['address']?.isNotEmpty == true
                    ? Text(entry.value['address'])
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      setState(() => _places.removeAt(entry.key)),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '예산 (원)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    final user = _readCalendarActionUser(ref);
    if (user == null) return;

    final startAt = DateTime(_date.year, _date.month, _date.day);
    final budget = int.tryParse(_budgetController.text.trim());

    final event = EventModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      type: 'date',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 23, minutes: 59)),
      isAllDay: true,
      color: _eventTypeColor('date'),
      createdBy: user.uid,
      createdAt: DateTime.now(),
      places: _places,
      budget: budget,
    );

    ref
        .read(calendarRepositoryProvider)
        .createEvent(widget.familyId, event);
    Navigator.of(context).pop();
  }
}

class _AnniversaryPlannerForm extends ConsumerStatefulWidget {
  final String familyId;
  final VoidCallback onBack;

  const _AnniversaryPlannerForm(
      {required this.familyId, required this.onBack});

  @override
  ConsumerState<_AnniversaryPlannerForm> createState() =>
      _AnniversaryPlannerFormState();
}

class _AnniversaryPlannerFormState
    extends ConsumerState<_AnniversaryPlannerForm> {
  final _titleController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _dday = true;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back)),
              Text('기념일 플래너',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(DateFormat('M/d (E)', 'ko_KR').format(_date)),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2030),
              );
              if (date != null) setState(() => _date = date);
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('D-day 표시'),
            value: _dday,
            onChanged: (v) => setState(() => _dday = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    final user = _readCalendarActionUser(ref);
    if (user == null) return;

    final startAt = DateTime(_date.year, _date.month, _date.day);

    final event = EventModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      type: 'anniversary',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 23, minutes: 59)),
      isAllDay: true,
      color: _eventTypeColor('anniversary'),
      createdBy: user.uid,
      createdAt: DateTime.now(),
      dday: _dday,
    );

    ref
        .read(calendarRepositoryProvider)
        .createEvent(widget.familyId, event);
    Navigator.of(context).pop();
  }
}

class _HospitalPlannerForm extends ConsumerStatefulWidget {
  final String familyId;
  final VoidCallback onBack;

  const _HospitalPlannerForm(
      {required this.familyId, required this.onBack});

  @override
  ConsumerState<_HospitalPlannerForm> createState() =>
      _HospitalPlannerFormState();
}

class _HospitalPlannerFormState
    extends ConsumerState<_HospitalPlannerForm> {
  final _titleController = TextEditingController();
  final _placeNameController = TextEditingController();
  final _placeAddressController = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  @override
  void dispose() {
    _titleController.dispose();
    _placeNameController.dispose();
    _placeAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back)),
              Text('병원 플래너',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                      DateFormat('M/d (E)', 'ko_KR').format(_date)),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _date = date);
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (time != null) setState(() => _time = time);
                },
                child: Text(
                    '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _placeNameController,
            decoration: const InputDecoration(
              labelText: '병원 이름',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _placeAddressController,
            decoration: const InputDecoration(
              labelText: '주소 (선택)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    final user = _readCalendarActionUser(ref);
    if (user == null) return;

    final startAt = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);

    final places = <Map<String, dynamic>>[];
    if (_placeNameController.text.trim().isNotEmpty) {
      places.add({
        'name': _placeNameController.text.trim(),
        'address': _placeAddressController.text.trim(),
        'order': 0,
      });
    }

    final event = EventModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      type: 'hospital',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
      color: _eventTypeColor('hospital'),
      createdBy: user.uid,
      createdAt: DateTime.now(),
      places: places.isNotEmpty ? places : null,
    );

    ref
        .read(calendarRepositoryProvider)
        .createEvent(widget.familyId, event);
    Navigator.of(context).pop();
  }
}
