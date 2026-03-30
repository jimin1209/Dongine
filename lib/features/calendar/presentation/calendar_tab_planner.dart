part of 'calendar_screen.dart';

class _PlannerTab extends ConsumerWidget {
  final String familyId;

  const _PlannerTab({required this.familyId});

  static const _typeOrder = ['anniversary', 'hospital', 'meal', 'date'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider(familyId));
    final theme = Theme.of(context);

    return eventsAsync.when(
      data: (events) {
        final plannerEvents = events
            .where((e) => e.type != 'general')
            .where((e) => e.startAt.isAfter(
                DateTime.now().subtract(const Duration(days: 1))))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

        if (plannerEvents.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_note,
                    size: 48,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                Text(
                  '플래너 일정이 없습니다\n+버튼으로 식사/데이트/기념일/병원 일정을 추가하세요',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        // Group by type
        final grouped = <String, List<EventModel>>{};
        for (final e in plannerEvents) {
          grouped.putIfAbsent(e.type, () => []).add(e);
        }

        // Build sections in type order
        final sections = <Widget>[];
        for (final type in _typeOrder) {
          final items = grouped[type];
          if (items == null || items.isEmpty) continue;

          sections.add(
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Row(
                children: [
                  Icon(_eventTypeIcon(type),
                      size: 18, color: _parseColor(_eventTypeColor(type))),
                  const SizedBox(width: 6),
                  Text(_eventTypeLabel(type),
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${items.length}',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          );

          for (final event in items) {
            sections.add(_PlannerCard(event: event));
          }
        }

        // Handle any types not in _typeOrder
        for (final entry in grouped.entries) {
          if (!_typeOrder.contains(entry.key)) {
            for (final event in entry.value) {
              sections.add(_PlannerCard(event: event));
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: sections,
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
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(
        event.startAt.year, event.startAt.month, event.startAt.day);
    final daysUntil = eventDay.difference(today).inDays;
    final isUpcoming = daysUntil >= 0 && daysUntil <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: isUpcoming
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: _parseColor(event.color).withValues(alpha: 0.4),
                  width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(event.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                // D-day / date badge
                _buildDateBadge(context, daysUntil),
              ],
            ),
            if (event.description != null &&
                event.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(event.description!,
                  style: theme.textTheme.bodySmall),
            ],
            // Status badge row
            ..._buildStatusBadges(context),
            const SizedBox(height: 4),
            // Type-specific info
            ..._buildTypeSpecificInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBadge(BuildContext context, int daysUntil) {
    // For anniversary type with dday flag, show prominent D-day
    if (event.dday == true || daysUntil <= 7) {
      String text;
      Color color;

      if (daysUntil > 0) {
        text = 'D-$daysUntil';
        color = daysUntil <= 3 ? Colors.red : Colors.orange;
      } else if (daysUntil == 0) {
        text = 'D-Day';
        color = Colors.red;
      } else {
        text = 'D+${-daysUntil}';
        color = Colors.grey;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: daysUntil <= 3 && daysUntil >= 0
              ? Border.all(color: color.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color)),
      );
    }

    return Text(
      DateFormat('M/d (E)', 'ko_KR').format(event.startAt),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  List<Widget> _buildStatusBadges(BuildContext context) {
    final badges = <Widget>[];

    if (event.type == 'meal' && event.mealVote != null) {
      final decided = event.mealVote!['decided'] as String?;
      final votes = Map<String, String>.from(event.mealVote!['votes'] ?? {});
      if (decided != null && decided.isNotEmpty) {
        badges.add(_statusChip('결정됨', Colors.green, Icons.check_circle));
      } else {
        badges.add(_statusChip('투표중 (${votes.length}명)', Colors.amber,
            Icons.how_to_vote));
      }
    }

    if (event.type == 'date') {
      final placeCount = event.places?.length ?? 0;
      if (placeCount > 0) {
        badges.add(
            _statusChip('$placeCount곳', Colors.blue, Icons.place));
      }
      if (event.budget != null) {
        badges.add(_statusChip(
            '${NumberFormat.compact(locale: 'ko').format(event.budget)}원',
            Colors.teal,
            Icons.account_balance_wallet));
      }
    }

    if (event.type == 'hospital') {
      badges.add(_statusChip(
          DateFormat('HH:mm').format(event.startAt),
          Colors.green,
          Icons.access_time));
    }

    if (badges.isEmpty) return [];

    return [
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 4, children: badges),
    ];
  }

  Widget _statusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
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
    // D-day is already shown in _buildDateBadge, no duplicate needed
    return [];
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
