import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/features/cart/domain/cart_provider.dart';
import 'package:dongine/features/expense/domain/expense_provider.dart';

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
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '가족 그룹에 참여해주세요',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '가족 그룹에 참여하면 할 일, 장보기, 가계부 등을\n함께 관리할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
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
                      value: todosAsync.when(
                        loading: () => null,
                        error: (_, _) => '-',
                        data: (todos) {
                          final count =
                              todos.where((t) => !t.isCompleted).length;
                          return count.toString();
                        },
                      ),
                      isLoading: todosAsync.isLoading,
                      onTap: () => context.push('/todo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.shopping_cart,
                      color: Colors.orange,
                      label: '장보기 남은 항목',
                      value: cartAsync.when(
                        loading: () => null,
                        error: (_, _) => '-',
                        data: (items) {
                          final count =
                              items.where((i) => !i.isChecked).length;
                          return count.toString();
                        },
                      ),
                      isLoading: cartAsync.isLoading,
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
                      value: expensesAsync.when(
                        loading: () => null,
                        error: (_, _) => '-',
                        data: (expenses) {
                          final now = DateTime.now();
                          final total = expenses
                              .where((e) =>
                                  e.date.year == now.year &&
                                  e.date.month == now.month)
                              .fold<int>(0, (sum, e) => sum + e.amount);
                          return _formatWon(total);
                        },
                      ),
                      isLoading: expensesAsync.isLoading,
                      onTap: () => context.push('/expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.calendar_month,
                      color: Colors.deepPurple,
                      label: '다가오는 일정',
                      value: eventsAsync.when(
                        loading: () => null,
                        error: (_, _) => '-',
                        data: (events) {
                          final count = events
                              .where(
                                  (e) => e.startAt.isAfter(DateTime.now()))
                              .length;
                          return '$count건';
                        },
                      ),
                      isLoading: eventsAsync.isLoading,
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
                error: (_, _) => const Text('할 일을 불러올 수 없습니다'),
                data: (todos) {
                  final pending =
                      todos.where((t) => !t.isCompleted).toList();
                  if (pending.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '모든 할 일을 완료했어요!',
                          style:
                              TextStyle(color: theme.colorScheme.outline),
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
                error: (_, _) => const Text('일정을 불러올 수 없습니다'),
                data: (events) {
                  final upcoming = events
                      .where((e) => e.startAt.isAfter(DateTime.now()))
                      .toList()
                    ..sort((a, b) => a.startAt.compareTo(b.startAt));
                  if (upcoming.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '예정된 일정이 없어요',
                          style:
                              TextStyle(color: theme.colorScheme.outline),
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
  final VoidCallback onTap;

  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.isLoading,
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

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
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
