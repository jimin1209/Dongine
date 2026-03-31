import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/location/domain/location_provider.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/features/iot/domain/iot_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/features/cart/domain/cart_provider.dart';
import 'package:dongine/features/expense/domain/expense_provider.dart';
import 'package:dongine/shared/widgets/home_status_model.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(currentFamilyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('동이네'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (family) {
          if (family == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.family_restroom,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '아직 가족 그룹이 없어요',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '가족 그룹을 만들거나 참여하면\n캘린더, 장보기, 가계부 등을 함께 관리할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go('/family-setup'),
                      icon: const Icon(Icons.group_add),
                      label: const Text('가족 그룹 설정하기'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 48),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      color: theme.colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '시작하는 방법',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildGuideStep(theme, '1', '위 버튼을 눌러 가족 그룹을 만드세요'),
                            const SizedBox(height: 4),
                            _buildGuideStep(theme, '2', '생성된 초대 코드를 가족에게 공유하세요'),
                            const SizedBox(height: 4),
                            _buildGuideStep(theme, '3', '함께 일정·장보기·가계부를 관리하세요'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final familyId = family.id;
          final todosAsync = ref.watch(todosProvider(familyId));
          final eventsAsync = ref.watch(eventsProvider(familyId));
          final cartAsync = ref.watch(cartItemsProvider(familyId));
          final expensesAsync = ref.watch(expensesProvider(familyId));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 가족 이름
              Text(
                family.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '초대 코드: ${family.inviteCode}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),

              // 시스템 상태 요약
              const _SystemStatusSurface(),
              const SizedBox(height: 20),

              // 한눈에 보기 요약 섹션
              Text(
                '한눈에 보기',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.checklist,
                      color: Colors.blue,
                      label: '남은 할 일',
                      value: todosAsync.whenData((todos) {
                        final count =
                            todos.where((t) => !t.isCompleted).length;
                        return count.toString();
                      }).value,
                      isLoading: todosAsync.isLoading,
                      isError: todosAsync.hasError,
                      onTap: () => context.push('/todo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.shopping_cart,
                      color: Colors.orange,
                      label: '장보기 남은 항목',
                      value: cartAsync.whenData((items) {
                        final count =
                            items.where((i) => !i.isChecked).length;
                        return count.toString();
                      }).value,
                      isLoading: cartAsync.isLoading,
                      isError: cartAsync.hasError,
                      onTap: () => context.push('/cart'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.account_balance_wallet,
                      color: Colors.green,
                      label: '이번 달 지출',
                      value: expensesAsync.whenData((expenses) {
                        final now = DateTime.now();
                        final total = expenses
                            .where((e) =>
                                e.date.year == now.year &&
                                e.date.month == now.month)
                            .fold<int>(0, (sum, e) => sum + e.amount);
                        return _formatWon(total);
                      }).value,
                      isLoading: expensesAsync.isLoading,
                      isError: expensesAsync.hasError,
                      onTap: () => context.push('/expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.calendar_month,
                      color: Colors.deepPurple,
                      label: '오늘 이후 일정',
                      value: eventsAsync.whenData((events) {
                        final now = DateTime.now();
                        final startOfDay =
                            DateTime(now.year, now.month, now.day);
                        final count = events
                            .where((e) =>
                                !e.startAt.isBefore(startOfDay))
                            .length;
                        return '$count건';
                      }).value,
                      isLoading: eventsAsync.isLoading,
                      isError: eventsAsync.hasError,
                      onTap: () => context.push('/calendar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 빠른 액세스 카드
              Text(
                '바로가기',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.shopping_cart,
                      label: '장보기',
                      color: Colors.orange,
                      onTap: () => context.push('/cart'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.account_balance_wallet,
                      label: '가계부',
                      color: Colors.green,
                      onTap: () => context.push('/expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.photo_album,
                      label: '앨범',
                      color: Colors.purple,
                      onTap: () => context.push('/album'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.devices,
                      label: 'IoT',
                      color: Colors.teal,
                      onTap: () => context.push('/iot'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.checklist,
                      label: '할 일',
                      color: Colors.blue,
                      onTap: () => context.push('/todo'),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 24),

              // 오늘의 할 일
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '오늘의 할 일',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/todo'),
                    child: const Text('전체 보기'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              todosAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 16, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '할 일을 불러올 수 없습니다: $e',
                            style: TextStyle(color: theme.colorScheme.error),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (todos) {
                  final pending =
                      todos.where((t) => !t.isCompleted).toList();
                  if (pending.isEmpty) {
                    return Card(
                      child: InkWell(
                        onTap: () => context.push('/todo'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                todos.isEmpty
                                    ? Icons.lightbulb_outline
                                    : Icons.check_circle_outline,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  todos.isEmpty
                                      ? '할 일을 추가해 보세요'
                                      : '모든 할 일을 완료했어요!',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (todos.isEmpty)
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: theme.colorScheme.outline,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: pending.take(5).map((todo) {
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.check_circle_outline,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(todo.title),
                          subtitle: todo.dueDate != null
                              ? Text(
                                  '마감: ${todo.dueDate!.month}/${todo.dueDate!.day}')
                              : null,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 다가오는 일정
              Text(
                '다가오는 일정',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              eventsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 16, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '일정을 불러올 수 없습니다: $e',
                            style: TextStyle(color: theme.colorScheme.error),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (events) {
                  final now = DateTime.now();
                  final startOfDay =
                      DateTime(now.year, now.month, now.day);
                  final upcoming = events
                      .where(
                          (e) => !e.startAt.isBefore(startOfDay))
                      .toList()
                    ..sort((a, b) => a.startAt.compareTo(b.startAt));
                  if (upcoming.isEmpty) {
                    return Card(
                      child: InkWell(
                        onTap: () => context.push('/calendar'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event_note_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '캘린더에서 가족 일정을 추가해 보세요',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: theme.colorScheme.outline,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: upcoming.take(5).map((event) {
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            _eventIcon(event.type),
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(event.title),
                          subtitle: Text(
                            '${event.startAt.month}/${event.startAt.day} ${event.startAt.hour}:${event.startAt.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatWon(int amount) {
    if (amount == 0) return '0원';
    if (amount >= 10000) {
      final man = amount ~/ 10000;
      final remainder = amount % 10000;
      if (remainder == 0) return '$man만원';
      return '$man만 ${_addCommas(remainder)}원';
    }
    return '${_addCommas(amount)}원';
  }

  static String _addCommas(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  static Widget _buildGuideStep(ThemeData theme, String number, String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  IconData _eventIcon(String type) {
    return switch (type) {
      'meal' => Icons.restaurant,
      'date' => Icons.favorite,
      'anniversary' => Icons.cake,
      'hospital' => Icons.local_hospital,
      _ => Icons.event,
    };
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final bool isLoading;
  final bool isError;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.isLoading,
    this.isError = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 12),
              if (isLoading)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isError)
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '불러오지 못함',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  value ?? '-',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemStatusSurface extends ConsumerWidget {
  const _SystemStatusSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locationSharing = ref.watch(locationSharingEnabledProvider);
    final permSnap = ref.watch(locationPermissionSnapshotProvider);
    final calendarSync = ref.watch(googleCalendarSyncUiProvider);
    final mqttStatus = ref.watch(mqttConnectionStatusProvider);
    final mqttConfigured = ref.watch(mqttBrokerConfiguredProvider);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '시스템 상태',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            // 위치 공유
            _buildStatusRow(
              context,
              icon: Icons.location_on,
              label: locationStatusLabel(locationSharing, permSnap.valueOrNull),
              ok: locationStatusOk(locationSharing, permSnap.valueOrNull),
              hint: locationStatusHint(locationSharing, permSnap.valueOrNull),
            ),
            const Divider(height: 16),
            // Google Calendar 동기화
            _buildStatusRow(
              context,
              icon: Icons.calendar_month,
              label: calendarStatusLabel(calendarSync),
              ok: calendarStatusOk(calendarSync),
              hint: calendarStatusHint(calendarSync),
            ),
            const Divider(height: 16),
            // MQTT 연결
            _buildStatusRow(
              context,
              icon: Icons.sensors,
              label: mqttStatusLabel(mqttStatus.valueOrNull, mqttConfigured),
              ok: mqttStatusOk(mqttStatus.valueOrNull, mqttConfigured),
              hint: mqttStatusHint(mqttStatus.valueOrNull, mqttConfigured),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool ok,
    required String? hint,
  }) {
    final theme = Theme.of(context);
    final statusColor = ok ? Colors.green : theme.colorScheme.error;

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Icon(
          ok ? Icons.check_circle : Icons.warning_amber_rounded,
          size: 16,
          color: statusColor,
        ),
      ],
    );
  }

}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(familyLocationTrackingBootstrapProvider);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '채팅',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '지도',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '파일',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '캘린더',
          ),
        ],
      ),
    );
  }
}
