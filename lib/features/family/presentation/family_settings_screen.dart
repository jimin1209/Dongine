import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    final currentFamilyId = currentFamilyIdAsync.valueOrNull;
    final currentFamily = currentFamilyAsync.valueOrNull;
    final membersAsync = currentFamilyId == null
        ? const AsyncValue.data(<FamilyMember>[])
        : ref.watch(familyMembersProvider(currentFamilyId));
    final isCurrentUserAdmin =
        membersAsync.valueOrNull?.any(
          (member) => member.uid == user?.uid && member.role == 'admin',
        ) ??
        false;
    final canManageInvites = user != null && isCurrentUserAdmin;
    final showInviteAdminHint =
        user != null && membersAsync.valueOrNull != null && !isCurrentUserAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user?.displayName ?? '로그인 사용자'),
              subtitle: Text(user?.email ?? '이메일 정보 없음'),
            ),
          ),
          const SizedBox(height: 16),
          Text('현재 가족', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          currentFamilyAsync.when(
            loading: () =>
                const Card(child: ListTile(title: Text('가족 정보를 불러오는 중...'))),
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
                    : Text(_buildInviteSubtitle(family)),
              ),
            ),
          ),
          if (currentFamily != null) ...[
            const SizedBox(height: 12),

            // 초대 코드 복사 + 재발급 버튼
            _buildInviteCodeActions(
              context,
              ref,
              currentFamily,
              user?.uid,
              canManageInvites,
            ),

            if (showInviteAdminHint)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '초대 코드 관리는 가족 관리자만 할 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // 구성원 목록
            const SizedBox(height: 24),
            Text('구성원', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildMembersList(context, membersAsync, user?.uid),
          ],
          const SizedBox(height: 24),
          Text('가족 전환', style: Theme.of(context).textTheme.titleMedium),
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
              return Column(
                children: families.map((family) {
                  return _FamilySelectorTile(
                    family: family,
                    isSelected: family.id == currentFamilyId,
                    onTap: () => _selectFamily(context, ref, family),
                  );
                }).toList(),
              );
            },
          ),

          // 가족 나가기
          if (currentFamily != null && user != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _confirmLeaveFamily(
                context,
                ref,
                currentFamily,
                user.uid,
                membersAsync.valueOrNull ?? [],
              ),
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              label: const Text('가족 나가기',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],

          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: user == null ? null : () => _signOut(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  // ─── Invite Code Actions ───

  Widget _buildInviteCodeActions(
    BuildContext context,
    WidgetRef ref,
    FamilyModel family,
    String? userUid,
    bool canManageInvites,
  ) {
    final hasValidCode = family.inviteCode.isNotEmpty &&
        family.inviteExpiresAt != null &&
        family.inviteExpiresAt!.isAfter(DateTime.now());

    return Row(
      children: [
        if (hasValidCode)
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: family.inviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('초대 코드 "${family.inviteCode}"가 복사되었습니다'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(family.inviteCode),
            ),
          ),
        if (hasValidCode) const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: !canManageInvites || userUid == null
                ? null
                : () => _refreshInviteCode(context, ref, family, userUid),
            icon: const Icon(Icons.refresh),
            label: Text(_buildRefreshButtonLabel(family)),
          ),
        ),
      ],
    );
  }

  // ─── Members List ───

  Widget _buildMembersList(
    BuildContext context,
    AsyncValue<List<FamilyMember>> membersAsync,
    String? currentUid,
  ) {
    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Card(
        child: ListTile(
          title: const Text('구성원 목록을 불러오지 못했습니다'),
          subtitle: Text(e.toString()),
        ),
      ),
      data: (members) {
        if (members.isEmpty) {
          return const Card(
            child: ListTile(title: Text('구성원이 없습니다')),
          );
        }

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < members.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildMemberTile(context, members[i], currentUid),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    FamilyMember member,
    String? currentUid,
  ) {
    final isMe = member.uid == currentUid;
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: member.role == 'admin'
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          member.role == 'admin' ? Icons.shield : Icons.person,
          color: member.role == 'admin'
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.nickname.isNotEmpty ? member.nickname : '(이름 없음)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            Text(
              '(나)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: member.role == 'admin'
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          member.role == 'admin' ? '관리자' : '멤버',
          style: theme.textTheme.labelSmall?.copyWith(
            color: member.role == 'admin'
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ─── Leave Family ───

  void _confirmLeaveFamily(
    BuildContext context,
    WidgetRef ref,
    FamilyModel family,
    String uid,
    List<FamilyMember> members,
  ) {
    final adminCount = members.where((m) => m.role == 'admin').length;
    final isSoleAdmin =
        adminCount == 1 && members.any((m) => m.uid == uid && m.role == 'admin');
    final hasOtherMembers = members.length > 1;

    if (isSoleAdmin && hasOtherMembers) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('가족 나가기 불가'),
          content: const Text(
            '현재 유일한 관리자입니다.\n'
            '다른 구성원에게 관리자 역할을 넘긴 후 나갈 수 있습니다.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가족 나가기'),
        content: Text(
          '"${family.name}" 가족에서 나가시겠습니까?\n'
          '${hasOtherMembers ? '' : '마지막 구성원이므로 가족 데이터가 남아 있을 수 있습니다.\n'}'
          '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _leaveFamily(context, ref, family, uid);
            },
            child: const Text('나가기'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveFamily(
    BuildContext context,
    WidgetRef ref,
    FamilyModel family,
    String uid,
  ) async {
    try {
      await ref.read(familyRepositoryProvider).leaveFamily(family.id, uid);
      await ref
          .read(selectedFamilyControllerProvider.notifier)
          .selectFamily(null);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${family.name}" 가족에서 나왔습니다')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가족 나가기 실패: $e')),
      );
    }
  }

  // ─── Existing Actions ───

  Future<void> _selectFamily(
    BuildContext context,
    WidgetRef ref,
    FamilyModel family,
  ) async {
    await ref
        .read(selectedFamilyControllerProvider.notifier)
        .selectFamily(family.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('현재 가족이 \'${family.name}\'(으)로 변경되었습니다.')),
    );
    context.pop();
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    await ref
        .read(selectedFamilyControllerProvider.notifier)
        .selectFamily(null);

    if (!context.mounted) return;
    context.go('/splash');
  }

  Future<void> _refreshInviteCode(
    BuildContext context,
    WidgetRef ref,
    FamilyModel family,
    String adminUid,
  ) async {
    try {
      final updatedFamily = await ref
          .read(familyRepositoryProvider)
          .refreshInviteCode(family.id, adminUid);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('새 초대 코드가 발급되었습니다: ${updatedFamily.inviteCode}'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류: ${e.toString()}')));
    }
  }

  String _buildInviteSubtitle(FamilyModel family) {
    final expiresAt = family.inviteExpiresAt;
    if (family.inviteCode.isEmpty) {
      return '초대 코드가 없습니다.';
    }

    if (expiresAt == null) {
      return '초대 코드: ${family.inviteCode} · 재발급 필요';
    }

    final formattedDate = DateFormat('M월 d일', 'ko_KR').format(expiresAt);
    if (expiresAt.isAfter(DateTime.now())) {
      return '초대 코드: ${family.inviteCode} · $formattedDate까지 유효';
    }

    return '초대 코드: ${family.inviteCode} · 만료됨';
  }

  String _buildRefreshButtonLabel(FamilyModel family) {
    final expiresAt = family.inviteExpiresAt;
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now())) {
      return '새 초대 코드 발급';
    }

    return '초대 코드 재발급';
  }
}

class _FamilySelectorTile extends StatelessWidget {
  final FamilyModel family;
  final bool isSelected;
  final VoidCallback onTap;

  const _FamilySelectorTile({
    required this.family,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: isSelected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.family_restroom),
        title: Text(family.name),
        subtitle: Text('구성원 ${family.memberIds.length}명'),
        selected: isSelected,
        onTap: onTap,
      ),
    );
  }
}
