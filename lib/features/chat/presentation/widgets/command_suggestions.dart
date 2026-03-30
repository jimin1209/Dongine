import 'package:flutter/material.dart';

class CommandSuggestion {
  final String command;
  final IconData icon;
  final String description;

  const CommandSuggestion({
    required this.command,
    required this.icon,
    required this.description,
  });
}

const _allCommands = [
  CommandSuggestion(
    command: '/todo',
    icon: Icons.check_box_outlined,
    description: '할 일 추가',
  ),
  CommandSuggestion(
    command: '/remind',
    icon: Icons.alarm,
    description: '리마인더 설정',
  ),
  CommandSuggestion(
    command: '/location',
    icon: Icons.location_on_outlined,
    description: '현재 위치 공유',
  ),
  CommandSuggestion(
    command: '/calendar',
    icon: Icons.calendar_today,
    description: '일정 추가',
  ),
  CommandSuggestion(
    command: '/poll',
    icon: Icons.poll_outlined,
    description: '투표 만들기',
  ),
  CommandSuggestion(
    command: '/meal',
    icon: Icons.restaurant,
    description: '밥 투표 시작',
  ),
  CommandSuggestion(
    command: '/date',
    icon: Icons.favorite_border,
    description: '데이트 일정',
  ),
  CommandSuggestion(
    command: '/cart',
    icon: Icons.shopping_cart_outlined,
    description: '장바구니 추가',
  ),
  CommandSuggestion(
    command: '/expense',
    icon: Icons.receipt_long,
    description: '가계부 기록',
  ),
  CommandSuggestion(
    command: '/members',
    icon: Icons.people_outline,
    description: '가족 멤버 보기',
  ),
];

class CommandSuggestions extends StatelessWidget {
  final String currentInput;
  final ValueChanged<String> onCommandSelected;

  const CommandSuggestions({
    super.key,
    required this.currentInput,
    required this.onCommandSelected,
  });

  @override
  Widget build(BuildContext context) {
    final query = currentInput.toLowerCase();
    final filtered = _allCommands.where((cmd) {
      return cmd.command.startsWith(query) || query == '/';
    }).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final cmd = filtered[index];
          return ListTile(
            dense: true,
            leading: Icon(cmd.icon, size: 20),
            title: Text(
              cmd.command,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              cmd.description,
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => onCommandSelected('${cmd.command} '),
          );
        },
      ),
    );
  }
}
