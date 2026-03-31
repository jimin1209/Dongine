import 'package:flutter/material.dart';

/// 커맨드/액션 메뉴를 BottomSheet로 표시하는 위젯.
/// 입력창 왼쪽 '+' 버튼을 누르면 열린다.
class CommandActionSheet extends StatelessWidget {
  final ValueChanged<String> onCommandSelected;

  const CommandActionSheet({
    super.key,
    required this.onCommandSelected,
  });

  static const _actions = [
    _ActionItem(
      command: '/poll ',
      icon: Icons.poll_outlined,
      label: '투표 만들기',
      description: '가족에게 투표를 시작합니다',
    ),
    _ActionItem(
      command: '/todo ',
      icon: Icons.check_box_outlined,
      label: '할 일 공유',
      description: '가족 공유 할 일을 추가합니다',
    ),
    _ActionItem(
      command: '/meal ',
      icon: Icons.restaurant,
      label: '식단 투표',
      description: '오늘 뭐 먹을지 투표합니다',
    ),
    _ActionItem(
      command: '/remind ',
      icon: Icons.alarm,
      label: '리마인더',
      description: '시간에 맞춰 알림을 보냅니다',
    ),
    _ActionItem(
      command: '/calendar ',
      icon: Icons.calendar_today,
      label: '일정 공유',
      description: '가족 캘린더에 일정을 추가합니다',
    ),
    _ActionItem(
      command: '/date ',
      icon: Icons.favorite_border,
      label: '데이트 일정',
      description: '데이트 일정을 공유합니다',
    ),
    _ActionItem(
      command: '/location',
      icon: Icons.location_on_outlined,
      label: '위치 공유',
      description: '현재 위치를 채팅에 공유합니다',
    ),
    _ActionItem(
      command: '/cart ',
      icon: Icons.shopping_cart_outlined,
      label: '장바구니 추가',
      description: '공유 장바구니에 항목을 추가합니다',
    ),
    _ActionItem(
      command: '/expense ',
      icon: Icons.receipt_long,
      label: '가계부 기록',
      description: '지출 내역을 기록합니다',
    ),
    _ActionItem(
      command: '/members',
      icon: Icons.people_outline,
      label: '가족 멤버 보기',
      description: '현재 가족 구성원을 확인합니다',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.apps, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '커맨드 메뉴',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _actions.length,
              itemBuilder: (context, index) {
                final action = _actions[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      action.icon,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    action.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    action.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => onCommandSelected(action.command),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  final String command;
  final IconData icon;
  final String label;
  final String description;

  const _ActionItem({
    required this.command,
    required this.icon,
    required this.label,
    required this.description,
  });
}
