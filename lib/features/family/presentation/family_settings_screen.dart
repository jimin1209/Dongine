import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dongine/features/auth/data/auth_repository.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/todo/domain/todo_provider.dart';
import 'package:dongine/features/cart/domain/cart_provider.dart';
import 'package:dongine/features/expense/domain/expense_provider.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/family/presentation/demo_seed_service.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:dongine/shared/models/user_model.dart';
import 'package:dongine/features/family/presentation/family_settings_helpers.dart';

class FamilySettingsScreen extends ConsumerWidget {
  const FamilySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(familySessionUserProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final currentFamilyAsync = ref.watch(currentFamilyProvider);
    final familiesAsync = ref.watch(userFamiliesProvider);
    final currentFamilyIdAsync = ref.watch(currentFamilyIdProvider);
    final currentFamilyId = currentFamilyIdAsync.valueOrNull;
    final currentFamily = currentFamilyAsync.valueOrNull;
    final membersAsync = currentFamilyId == null
        ? const AsyncValue.data(<FamilyMember>[])
        : ref.watch(familyMembersProvider(currentFamilyId));
    final members = membersAsync.valueOrNull ?? [];
    final isCurrentUserAdmin = isUserAdmin(members, user?.uid);
    final canManageInvites = user != null && isCurrentUserAdmin;
    final showInviteAdminHint =
        user != null && membersAsync.valueOrNull != null && !isCurrentUserAdmin;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 프로필 카드 ───
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: user == null
                  ? null
                  : () => _showEditDisplayNameBottomSheet(
                        context,
                        ref,
                        initialName: _initialDisplayNameForEdit(profileAsync, user),
                        email: user.email,
                      ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        _avatarInitial(profileAsync, user),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayNameLabel(profileAsync, user),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '이메일 정보 없음',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (currentFamily != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.family_restroom,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    currentFamily.name,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (user != null)
                      Icon(
                        Icons.edit_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── 현재 가족 ───
          Text('현재 가족', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          currentFamilyAsync.when(
            loading: () => const Card(
              child: ListTile(
                leading: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('가족 정보를 불러오는 중...'),
              ),
            ),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('가족 정보를 불러오지 못했습니다'),
                subtitle: Text(error.toString()),
              ),
            ),
            data: (family) {
              if (family == null) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.family_restroom,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '선택된 가족이 없습니다',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '아래에서 가족을 선택하거나, 새 가족을 만들어 시작하세요.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return _buildCurrentFamilyCard(context, family, members.length);
            },
          ),
          if (currentFamily != null) ...[
            const SizedBox(height: 12),

            // ─── 초대 코드 ───
            _buildInviteCodeSection(
              context,
              ref,
              currentFamily,
              user?.uid,
              canManageInvites,
              showInviteAdminHint,
            ),

            // ─── 구성원 목록 ───
            const SizedBox(height: 24),
            Row(
              children: [
                Text('구성원', style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                if (members.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${members.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMembersList(
              context,
              ref,
              membersAsync,
              user?.uid,
              currentFamilyId,
              isCurrentUserAdmin,
            ),
          ],
          const SizedBox(height: 24),

          // ─── 가족 전환 ───
          Text('가족 전환', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          familiesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('가족 목록을 불러오지 못했습니다'),
                subtitle: Text(error.toString()),
              ),
            ),
            data: (families) {
              if (families.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_add,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '참여한 가족이 없습니다',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '새 가족을 만들거나 초대 코드를 입력해 참가하세요.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.go('/family-setup'),
                          icon: const Icon(Icons.add),
                          label: const Text('가족 설정'),
                        ),
                      ],
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

          // ─── 가족 나가기 ───
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

          // ─── 데모 데이터 (debug 전용) ───
          if (kDebugMode && currentFamily != null && user != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _seedDemoData(context, ref, currentFamily.id, user.uid),
              icon: const Icon(Icons.science_outlined),
              label: const Text('데모 데이터 채우기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _resetDemoData(context, ref, currentFamily.id),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('데모 데이터 초기화'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
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

  // ─── Demo Seed (debug only) ───

  Future<void> _seedDemoData(
    BuildContext context,
    WidgetRef ref,
    String familyId,
    String userId,
  ) async {
    final service = DemoSeedService(
      todoRepo: ref.read(todoRepositoryProvider),
      cartRepo: ref.read(cartRepositoryProvider),
      expenseRepo: ref.read(expenseRepositoryProvider),
      calendarRepo: ref.read(calendarRepositoryProvider),
    );

    // Duplicate guard
    final alreadySeeded = await service.hasSeedData(familyId);
    if (alreadySeeded) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 데모 데이터가 존재합니다.')),
      );
      return;
    }

    try {
      await service.seed(familyId, userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('데모 데이터를 추가했습니다.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데모 데이터 추가 실패: $e')),
      );
    }
  }

  // ─── Demo Reset (debug only) ───

  Future<void> _resetDemoData(
    BuildContext context,
    WidgetRef ref,
    String familyId,
  ) async {
    final service = DemoSeedService(
      todoRepo: ref.read(todoRepositoryProvider),
      cartRepo: ref.read(cartRepositoryProvider),
      expenseRepo: ref.read(expenseRepositoryProvider),
      calendarRepo: ref.read(calendarRepositoryProvider),
    );

    try {
      final result = await service.reset(familyId);
      if (!context.mounted) return;
      if (result.total == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제할 데모 데이터가 없습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데모 데이터 ${result.total}건을 삭제했습니다.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데모 데이터 초기화 실패: $e')),
      );
    }
  }

  // ─── Current Family Card ───

  Widget _buildCurrentFamilyCard(
    BuildContext context,
    FamilyModel family,
    int memberCount,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(
                Icons.family_restroom,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(family.name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '$memberCount명 참여 중',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _buildInviteStatusChip(context, family),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteStatusChip(BuildContext context, FamilyModel family) {
    final theme = Theme.of(context);
    final hasCode = family.inviteCode.isNotEmpty;
    final expiresAt = family.inviteExpiresAt;
    final isExpired = expiresAt == null || !expiresAt.isAfter(DateTime.now());

    if (!hasCode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '초대 코드 없음',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 12, color: theme.colorScheme.error),
            const SizedBox(width: 4),
            Text(
              '초대 만료',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      );
    }

    final formattedDate = DateFormat('M/d', 'ko_KR').format(expiresAt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$formattedDate까지',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  // ─── Invite Code Section ───

  Widget _buildInviteCodeSection(
    BuildContext context,
    WidgetRef ref,
    FamilyModel family,
    String? userUid,
    bool canManageInvites,
    bool showAdminHint,
  ) {
    final theme = Theme.of(context);
    final hasValidCode = family.inviteCode.isNotEmpty &&
        family.inviteExpiresAt != null &&
        family.inviteExpiresAt!.isAfter(DateTime.now());
    final isExpiredCode = family.inviteCode.isNotEmpty &&
        (family.inviteExpiresAt == null ||
            !family.inviteExpiresAt!.isAfter(DateTime.now()));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('초대 코드', style: theme.textTheme.labelLarge),
              ],
            ),
            if (isExpiredCode) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '이전 초대 코드가 만료되었습니다. 새 코드를 발급해주세요.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (hasValidCode)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: family.inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '초대 코드 "${family.inviteCode}"가 복사되었습니다'),
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
                        : () =>
                            _refreshInviteCode(context, ref, family, userUid),
                    icon: const Icon(Icons.refresh),
                    label: Text(_buildRefreshButtonLabel(family)),
                  ),
                ),
              ],
            ),
            if (showAdminHint)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '초대 코드 관리는 가족 관리자만 할 수 있습니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Members List ───

  Widget _buildMembersList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<FamilyMember>> membersAsync,
    String? currentUid,
    String? familyId,
    bool isCurrentUserAdmin,
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
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '아직 구성원 정보가 없습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final adminCount = countAdmins(members);

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < members.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildMemberTile(
                  context,
                  ref,
                  members[i],
                  currentUid,
                  familyId,
                  isCurrentUserAdmin,
                  adminCount,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
    String? currentUid,
    String? familyId,
    bool isCurrentUserAdmin,
    int adminCount,
  ) {
    final isMe = member.uid == currentUid;
    final theme = Theme.of(context);
    final canChangeRoleFlag = canChangeRole(
      isCurrentUserAdmin: isCurrentUserAdmin,
      familyId: familyId,
      currentUid: currentUid,
    );
    // 마지막 관리자는 해제 불가
    final isSoleAdminFlag = isSoleAdmin(member, adminCount);

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
      trailing: canChangeRoleFlag
          ? _RoleBadgeButton(
              member: member,
              isSoleAdmin: isSoleAdminFlag,
              onTap: () => _showRoleChangeDialog(
                context,
                ref,
                familyId!,
                currentUid!,
                member,
                isSoleAdminFlag,
              ),
            )
          : Container(
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

  void _showRoleChangeDialog(
    BuildContext context,
    WidgetRef ref,
    String familyId,
    String adminUid,
    FamilyMember member,
    bool isSoleAdmin,
  ) {
    final isAdmin = member.role == 'admin';
    final targetRole = isAdmin ? 'member' : 'admin';
    final actionLabel = isAdmin ? '멤버로 변경' : '관리자로 지정';
    final memberName =
        member.nickname.isNotEmpty ? member.nickname : '(이름 없음)';

    if (isAdmin && isSoleAdmin) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('역할 변경 불가'),
          content: const Text(
            '마지막 관리자는 해제할 수 없습니다.\n'
            '먼저 다른 구성원을 관리자로 지정해주세요.',
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
        title: Text(actionLabel),
        content: Text(
          '"$memberName"님을 ${targetRole == 'admin' ? '관리자' : '멤버'}(으)로 변경하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _updateMemberRole(
                context,
                ref,
                familyId,
                adminUid,
                member.uid,
                targetRole,
              );
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMemberRole(
    BuildContext context,
    WidgetRef ref,
    String familyId,
    String adminUid,
    String targetUid,
    String newRole,
  ) async {
    try {
      await ref.read(familyRepositoryProvider).updateMemberRole(
            familyId,
            adminUid,
            targetUid,
            newRole,
          );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newRole == 'admin' ? '관리자로 지정했습니다.' : '멤버로 변경했습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('역할 변경 실패: $e')),
      );
    }
  }

  // ─── Leave Family ───

  void _confirmLeaveFamily(
    BuildContext context,
    WidgetRef ref,
    FamilyModel family,
    String uid,
    List<FamilyMember> members,
  ) {
    final guard = leaveGuardStatus(uid: uid, members: members);

    if (guard == LeaveGuardStatus.blockedSoleAdmin) {
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

    final isLastMember = guard == LeaveGuardStatus.allowedLastMember;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가족 나가기'),
        content: Text(
          '"${family.name}" 가족에서 나가시겠습니까?\n'
          '${isLastMember ? '마지막 구성원이므로 가족 그룹이 삭제됩니다.\n' : ''}'
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

  String _buildRefreshButtonLabel(FamilyModel family) {
    final expiresAt = family.inviteExpiresAt;
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now())) {
      return '새 초대 코드 발급';
    }

    return '초대 코드 재발급';
  }
}

String _avatarInitial(
  AsyncValue<UserModel?> profileAsync,
  FamilySessionUser? user,
) {
  final name = _displayNameLabel(profileAsync, user);
  if (name.isEmpty) return '?';
  return name.substring(0, 1).toUpperCase();
}

String _displayNameLabel(
  AsyncValue<UserModel?> profileAsync,
  FamilySessionUser? user,
) {
  final fromProfile = profileAsync.valueOrNull?.displayName.trim();
  if (fromProfile != null && fromProfile.isNotEmpty) {
    return fromProfile;
  }
  final fromAuth = user?.displayName?.trim();
  if (fromAuth != null && fromAuth.isNotEmpty) {
    return fromAuth;
  }
  return '로그인 사용자';
}

String _initialDisplayNameForEdit(
  AsyncValue<UserModel?> profileAsync,
  FamilySessionUser? user,
) {
  final fromProfile = profileAsync.valueOrNull?.displayName.trim();
  if (fromProfile != null && fromProfile.isNotEmpty) {
    return fromProfile;
  }
  final fromAuth = user?.displayName?.trim();
  if (fromAuth != null && fromAuth.isNotEmpty) {
    return fromAuth;
  }
  return '';
}

void _showEditDisplayNameBottomSheet(
  BuildContext context,
  WidgetRef ref, {
  required String initialName,
  required String? email,
}) {
  final rootContext = context;
  final controller = TextEditingController(text: initialName);
  final savingRef = <bool>[false];

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> save() async {
              if (savingRef[0]) return;
              savingRef[0] = true;
              setSheetState(() {});
              try {
                await ref.read(authRepositoryProvider).updateDisplayName(controller.text);
                ref.invalidate(currentUserProfileProvider);
                ref.invalidate(authStateProvider);
                if (!rootContext.mounted) return;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(content: Text('표시 이름이 저장되었습니다.')),
                );
              } on AuthException catch (e) {
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              } catch (e) {
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(content: Text('저장에 실패했습니다: $e')),
                  );
                }
              } finally {
                savingRef[0] = false;
                if (sheetContext.mounted) {
                  setSheetState(() {});
                }
              }
            }

            final saving = savingRef[0];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '표시 이름',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (email != null && email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  enabled: !saving,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '이름을 입력하세요',
                  ),
                  onSubmitted: (_) {
                    if (!saving) save();
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () {
                          final t = controller.text.trim();
                          if (t.isEmpty) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(content: Text('표시 이름을 입력해주세요.')),
                            );
                            return;
                          }
                          save();
                        },
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('저장'),
                ),
              ],
            );
          },
        ),
      );
    },
  ).whenComplete(controller.dispose);
}

class _RoleBadgeButton extends StatelessWidget {
  final FamilyMember member;
  final bool isSoleAdmin;
  final VoidCallback onTap;

  const _RoleBadgeButton({
    required this.member,
    required this.isSoleAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = member.role == 'admin';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isAdmin
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAdmin ? '관리자' : '멤버',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isAdmin
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit_outlined,
              size: 14,
              color: isAdmin
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
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
