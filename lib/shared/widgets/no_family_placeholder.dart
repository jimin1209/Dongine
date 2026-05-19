import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 가족 그룹 미참여 시 각 feature 화면에서 표시하는 공용 안내 위젯.
///
/// 아이콘 + 안내 문구 + "가족 설정으로 이동" 버튼을 제공한다.
class NoFamilyPlaceholder extends StatelessWidget {
  const NoFamilyPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '가족 그룹에 참여해주세요',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '가족 그룹을 만들거나 초대 코드를 입력하면\n이 기능을 사용할 수 있어요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/family-setup'),
              icon: const Icon(Icons.group_add),
              label: const Text('가족 설정하기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
