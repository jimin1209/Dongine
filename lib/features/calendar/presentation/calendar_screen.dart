import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/features/calendar/presentation/google_calendar_settings.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/shared/models/event_model.dart';
import 'package:dongine/shared/models/todo_model.dart';
import 'package:dongine/shared/models/family_model.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  String _selectedCategory = '전체';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return familyAsync.when(
      data: (family) {
        if (family == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('캘린더')),
            body: const Center(child: Text('가족을 먼저 생성해주세요')),
          );
        }
        return _buildMainScaffold(family);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('캘린더')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('캘린더')),
        body: Center(child: Text('오류: $e')),
      ),
    );
  }

  Widget _buildMainScaffold(FamilyModel family) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Google Calendar 설정',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const GoogleCalendarSettings(),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '캘린더'),
            Tab(text: 'TODO'),
            Tab(text: '플래너'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CalendarTab(
            familyId: family.id,
            calendarFormat: _calendarFormat,
            focusedDay: _focusedDay,
            onFormatChanged: (format) =>
                setState(() => _calendarFormat = format),
            onFocusedDayChanged: (day) => setState(() => _focusedDay = day),
          ),
          _TodoTab(
            familyId: family.id,
            selectedCategory: _selectedCategory,
            onCategoryChanged: (cat) =>
                setState(() => _selectedCategory = cat),
          ),
          _PlannerTab(familyId: family.id),
        ],
      ),
      floatingActionButton: _buildFab(family.id),
    );
  }

  Widget _buildFab(String familyId) {
    return FloatingActionButton(
      onPressed: () {
        switch (_tabController.index) {
          case 0:
            _showCreateEventSheet(context, familyId);
            break;
          case 1:
            _showCreateTodoDialog(context, familyId);
            break;
          case 2:
            _showCreatePlannerSheet(context, familyId);
            break;
        }
      },
      child: const Icon(Icons.add),
    );
  }

  void _showCreateEventSheet(BuildContext context, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreateEventSheet(familyId: familyId),
    );
  }

  void _showCreateTodoDialog(BuildContext context, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreateTodoSheet(familyId: familyId),
    );
  }

  void _showCreatePlannerSheet(BuildContext context, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreatePlannerSheet(familyId: familyId),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar Tab
// ---------------------------------------------------------------------------
class _CalendarTab extends ConsumerWidget {
  final String familyId;
  final CalendarFormat calendarFormat;
  final DateTime focusedDay;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onFocusedDayChanged;

  const _CalendarTab({
    required this.familyId,
    required this.calendarFormat,
    required this.focusedDay,
    required this.onFormatChanged,
    required this.onFocusedDayChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final eventsAsync = ref.watch(eventsProvider(familyId));
    final selectedDayEvents =
        ref.watch(selectedDayEventsProvider(familyId));
    final membersAsync = ref.watch(familyMembersProvider(familyId));

    final allEvents = eventsAsync.valueOrNull ?? [];

    return Column(
      children: [
        TableCalendar<EventModel>(
          locale: 'ko_KR',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: focusedDay,
          calendarFormat: calendarFormat,
          selectedDayPredicate: (day) => isSameDay(selectedDay, day),
          onDaySelected: (selected, focused) {
            ref.read(selectedDayProvider.notifier).state = selected;
            onFocusedDayChanged(focused);
          },
          onFormatChanged: onFormatChanged,
          onPageChanged: onFocusedDayChanged,
          eventLoader: (day) {
            return allEvents.where((event) {
              final eventDay = DateTime(
                  event.startAt.year, event.startAt.month, event.startAt.day);
              return isSameDay(eventDay, day);
            }).toList();
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return null;
              return Positioned(
                bottom: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: events.take(3).map((event) {
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _parseColor(event.color),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              DateFormat('M월 d일 (E)', 'ko_KR').format(selectedDay),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        Expanded(
          child: selectedDayEvents.isEmpty
              ? const Center(child: Text('일정이 없습니다'))
              : ListView.builder(
                  itemCount: selectedDayEvents.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final event = selectedDayEvents[index];
                    final members = membersAsync.valueOrNull ?? [];
                    return _EventCard(event: event, members: members);
                  },
                ),
        ),
      ],
    );
  }
}

class _EventCard extends ConsumerWidget {
  final EventModel event;
  final List<FamilyMember> members;

  const _EventCard({required this.event, required this.members});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGoogleSignedIn = ref.watch(googleCalendarSignedInProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              _eventTypeIcon(event.type),
              color: _parseColor(event.color),
            ),
            title: Row(
              children: [
                Flexible(child: Text(event.title)),
                if (event.isGoogleImported) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Google',
                      style: TextStyle(fontSize: 10, color: Colors.blue),
                    ),
                  ),
                ],
                if (event.isGoogleExported) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      '연동됨',
                      style: TextStyle(fontSize: 10, color: Colors.green),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              event.isAllDay
                  ? '종일'
                  : '${DateFormat('HH:mm').format(event.startAt)} - ${DateFormat('HH:mm').format(event.endAt)}',
            ),
            trailing: event.assignedTo.isNotEmpty
                ? SizedBox(
                    width: 60,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: event.assignedTo.take(2).map((uid) {
                        final member = members
                            .where((m) => m.uid == uid)
                            .firstOrNull;
                        return Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: CircleAvatar(
                            radius: 12,
                            child: Text(
                              member?.nickname.isNotEmpty == true
                                  ? member!.nickname[0]
                                  : '?',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : null,
            onLongPress: () => _showDeleteDialog(context, ref, theme),
          ),
          // imported 일정은 export 버튼 숨기고, 아직 연동 안 된 로컬 일정만 export 표시
          if (isGoogleSignedIn && !event.isGoogleImported && !event.isGoogleExported)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: ExportToGoogleCalendarButton(event: event),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, ThemeData theme) {
    String message;
    if (event.isGoogleExported) {
      message = '이 일정을 삭제하면 Google Calendar에서도 함께 삭제됩니다.';
    } else if (event.isGoogleImported) {
      message = '앱에서만 삭제됩니다. Google Calendar의 원본 일정은 유지됩니다.';
    } else {
      message = '이 일정을 삭제하시겠습니까?';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteEvent(context, ref);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(BuildContext context, WidgetRef ref) async {
    final family = ref.read(currentFamilyProvider).valueOrNull;
    if (family == null) return;

    final calendarRepo = ref.read(calendarRepositoryProvider);
    final googleService = ref.read(googleCalendarServiceProvider);

    try {
      await calendarRepo.deleteEventWithPolicy(
        family.id,
        event,
        googleService.isSignedIn ? googleService.deleteEvent : null,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// TODO Tab
// ---------------------------------------------------------------------------
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
        Expanded(
          child: todosAsync.when(
            data: (todos) {
              final filtered = selectedCategory == '전체'
                  ? todos
                  : todos
                      .where((t) => t.category == selectedCategory)
                      .toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('할 일이 없습니다'));
              }

              return ListView.builder(
                itemCount: filtered.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final todo = filtered[index];
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
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                : null,
          ),
        ),
        subtitle: Row(
          children: [
            if (todo.category != null) ...[
              Chip(
                label: Text(todo.category!,
                    style: const TextStyle(fontSize: 10)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
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
        trailing: todo.dueDate != null
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isDueSoon(todo.dueDate!)
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  DateFormat('M/d').format(todo.dueDate!),
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDueSoon(todo.dueDate!)
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  bool _isDueSoon(DateTime due) {
    return due.difference(DateTime.now()).inDays <= 1;
  }
}

// ---------------------------------------------------------------------------
// Planner Tab
// ---------------------------------------------------------------------------
class _PlannerTab extends ConsumerWidget {
  final String familyId;

  const _PlannerTab({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider(familyId));

    return eventsAsync.when(
      data: (events) {
        final plannerEvents = events
            .where((e) => e.type != 'general')
            .where((e) => e.startAt.isAfter(
                DateTime.now().subtract(const Duration(days: 1))))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

        if (plannerEvents.isEmpty) {
          return const Center(child: Text('플래너 일정이 없습니다'));
        }

        return ListView.builder(
          itemCount: plannerEvents.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final event = plannerEvents[index];
            return _PlannerCard(event: event);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

class _PlannerCard extends StatelessWidget {
  final EventModel event;

  const _PlannerCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_eventTypeIcon(event.type),
                    color: _parseColor(event.color)),
                const SizedBox(width: 8),
                Chip(
                  label: Text(_eventTypeLabel(event.type),
                      style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                Text(
                  DateFormat('M월 d일 (E)', 'ko_KR').format(event.startAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.title,
                style: Theme.of(context).textTheme.titleMedium),
            if (event.description != null &&
                event.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(event.description!,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            // Type-specific info
            ..._buildTypeSpecificInfo(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeSpecificInfo(BuildContext context) {
    switch (event.type) {
      case 'meal':
        return _buildMealInfo(context);
      case 'date':
        return _buildDateInfo(context);
      case 'anniversary':
        return _buildAnniversaryInfo(context);
      case 'hospital':
        return _buildHospitalInfo(context);
      default:
        return [];
    }
  }

  List<Widget> _buildMealInfo(BuildContext context) {
    final vote = event.mealVote;
    if (vote == null) return [];

    final options = List<String>.from(vote['options'] ?? []);
    final votes = Map<String, String>.from(vote['votes'] ?? {});
    final decided = vote['decided'] as String?;

    return [
      if (decided != null && decided.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text('결정: $decided',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        )
      else ...[
        Text('메뉴 투표 (${votes.length}명 참여)',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: options
              .map((opt) => Chip(
                    label: Text(opt, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
      ],
    ];
  }

  List<Widget> _buildDateInfo(BuildContext context) {
    final widgets = <Widget>[];
    if (event.places != null && event.places!.isNotEmpty) {
      for (var i = 0; i < event.places!.length; i++) {
        final place = event.places![i];
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (place['address'] != null)
                        Text(place['address'],
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (event.budget != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 16),
              const SizedBox(width: 4),
              Text('예산: ${NumberFormat('#,###').format(event.budget)}원'),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildAnniversaryInfo(BuildContext context) {
    if (event.dday != true) return [];
    final now = DateTime.now();
    final diff = DateTime(event.startAt.year, event.startAt.month,
            event.startAt.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    String ddayText;
    if (diff > 0) {
      ddayText = 'D-$diff';
    } else if (diff == 0) {
      ddayText = 'D-Day';
    } else {
      ddayText = 'D+${-diff}';
    }

    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.pink.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          ddayText,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.pink,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildHospitalInfo(BuildContext context) {
    final widgets = <Widget>[];
    if (event.places != null && event.places!.isNotEmpty) {
      final place = event.places!.first;
      widgets.add(Row(
        children: [
          const Icon(Icons.location_on, size: 16),
          const SizedBox(width: 4),
          Text(place['name'] ?? ''),
        ],
      ));
    }
    widgets.add(Row(
      children: [
        const Icon(Icons.access_time, size: 16),
        const SizedBox(width: 4),
        Text(DateFormat('HH:mm').format(event.startAt)),
      ],
    ));
    return widgets;
  }
}

// ---------------------------------------------------------------------------
// Create Event Bottom Sheet
// ---------------------------------------------------------------------------
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

    final user = ref.read(authStateProvider).valueOrNull;
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

// ---------------------------------------------------------------------------
// Create Todo Bottom Sheet
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Create Planner Bottom Sheet
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Meal Planner Form
// ---------------------------------------------------------------------------
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
          // Menu options
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
    final user = ref.read(authStateProvider).valueOrNull;
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

// ---------------------------------------------------------------------------
// Date Planner Form
// ---------------------------------------------------------------------------
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
          // Places
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
          // Budget
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
    final user = ref.read(authStateProvider).valueOrNull;
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

// ---------------------------------------------------------------------------
// Anniversary Planner Form
// ---------------------------------------------------------------------------
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
    final user = ref.read(authStateProvider).valueOrNull;
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

// ---------------------------------------------------------------------------
// Hospital Planner Form
// ---------------------------------------------------------------------------
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
    final user = ref.read(authStateProvider).valueOrNull;
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
IconData _eventTypeIcon(String type) {
  switch (type) {
    case 'meal':
      return Icons.restaurant;
    case 'date':
      return Icons.favorite;
    case 'anniversary':
      return Icons.cake;
    case 'hospital':
      return Icons.local_hospital;
    default:
      return Icons.event;
  }
}

String _eventTypeLabel(String type) {
  switch (type) {
    case 'meal':
      return '식사';
    case 'date':
      return '데이트';
    case 'anniversary':
      return '기념일';
    case 'hospital':
      return '병원';
    default:
      return '일반';
  }
}

String _eventTypeColor(String type) {
  switch (type) {
    case 'meal':
      return '#FF9800';
    case 'date':
      return '#E91E63';
    case 'anniversary':
      return '#9C27B0';
    case 'hospital':
      return '#4CAF50';
    default:
      return '#4285F4';
  }
}

Color _parseColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return const Color(0xFF4285F4);
  }
}
