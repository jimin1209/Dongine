import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';

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
              // TODO: 설정 화면 이동
            },
          ),
        ],
      ),
      body: familyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (family) {
          if (family == null) {
            return const Center(child: Text('가족 그룹에 참여해주세요'));
          }

          final todosAsync = ref.watch(todosProvider(family.id));
          final eventsAsync = ref.watch(eventsProvider(family.id));

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
                      onTap: () {
                        // Phase 3
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.photo_album,
                      label: '앨범',
                      color: Colors.purple,
                      onTap: () {
                        // Phase 3
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 오늘의 할 일
              Text(
                '오늘의 할 일',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              todosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Text('할 일을 불러올 수 없습니다'),
                data: (todos) {
                  final pending = todos.where((t) => !t.isCompleted).toList();
                  if (pending.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '모든 할 일을 완료했어요!',
                          style: TextStyle(color: theme.colorScheme.outline),
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
                              ? Text('마감: ${todo.dueDate!.month}/${todo.dueDate!.day}')
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
                loading: () => const Center(child: CircularProgressIndicator()),
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
                          style: TextStyle(color: theme.colorScheme.outline),
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
