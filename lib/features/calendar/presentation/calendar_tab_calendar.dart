part of 'calendar_screen.dart';

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
