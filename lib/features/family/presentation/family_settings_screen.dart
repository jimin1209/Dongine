import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/shared/models/family_model.dart';

class FamilySettingsScreen extends ConsumerWidget {
  const FamilySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final currentFamilyAsync = ref.watch(currentFamilyProvider);
    final familiesAsync = ref.watch(userFamiliesProvider);
    final currentFamilyIdAsync = ref.watch(currentFamilyIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(user?.displayName ?? '로그인 사용자'),
              subtitle: Text(user?.email ?? '이메일 정보 없음'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '현재 가족',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          currentFamilyAsync.when(
            loading: () => const Card(
              child: ListTile(
                title: Text('가족 정보를 불러오는 중...'),
              ),
            ),
            error: (error, _) => Card(
              child: ListTile(
                title: const Text('가족 정보를 불러오지 못했습니다'),
                subtitle: Text(error.toString()),
              ),
            ),
            data: (family) => Card(
              child: ListTile(
                leading: const Icon(Icons.family_restroom),
                title: Text(family?.name ?? '선택된 가족 없음'),
                subtitle: family == null
                    ? const Text('가족 그룹에 참여하지 않았습니다')
                    : Text('초대 코드: ${family.inviteCode}'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '가족 전환',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          familiesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Card(
              child: ListTile(
                title: const Text('가족 목록을 불러오지 못했습니다'),
                subtitle: Text(error.toString()),
              ),
            ),
            data: (families) {
              if (families.isEmpty) {
                return Card(
                  child: ListTile(
                    title: const Text('참여한 가족이 없습니다'),
                    subtitle: const Text('가족 설정 화면에서 새 가족을 만들거나 참가하세요'),
                    trailing: FilledButton(
                      onPressed: () => context.go('/family-setup'),
                      child: const Text('가족 설정'),
                    ),
                  ),
                );
              }

              final currentFamilyId = currentFamilyIdAsync.valueOrNull;
              return RadioGroup<String>(
                groupValue: currentFamilyId,
                onChanged: (familyId) {
                  final family = families.firstWhere(
                    (item) => item.id == familyId,
                  );
                  _selectFamily(context, ref, family);
                },
                child: Column(
                  children: families.map((family) {
                    return _FamilySelectorTile(
                      family: family,
                      isSelected: family.id == currentFamilyId,
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: user == null ? null : () => _signOut(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFamily(
    BuildContext context,
    WidgetRef ref,
    FamilyModel family,
  ) async {
    await ref.read(selectedFamilyControllerProvider.notifier).selectFamily(
          family.id,
        );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('현재 가족이 \'${family.name}\'(으)로 변경되었습니다.')),
    );
    context.pop();
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    await ref.read(selectedFamilyControllerProvider.notifier).selectFamily(
          null,
        );

    if (!context.mounted) return;
    context.go('/splash');
  }
}

class _FamilySelectorTile extends StatelessWidget {
  final FamilyModel family;
  final bool isSelected;

  const _FamilySelectorTile({
    required this.family,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: RadioListTile<String>(
        value: family.id,
        title: Text(family.name),
        subtitle: Text('구성원 ${family.memberIds.length}명'),
        selected: isSelected,
        secondary: isSelected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.family_restroom),
      ),
    );
  }
}
