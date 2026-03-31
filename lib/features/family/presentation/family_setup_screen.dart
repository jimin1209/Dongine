import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dongine/features/family/domain/family_provider.dart';

class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingFamilies();
  }

  Future<void> _checkExistingFamilies() async {
    final user = ref.read(familySessionUserProvider);
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final repo = ref.read(familyRepositoryProvider);
      final families = await repo.getUserFamilies(user.uid);
      if (families.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/home');
        });
        return;
      }
    } catch (_) {
      // 오류 시 설정 화면 표시
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateFamilyDialog() async {
    final controller = TextEditingController();

    final familyName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 가족 만들기'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '가족 이름',
            hintText: '예: 우리 가족',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );

    if (familyName == null || familyName.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(familySessionUserProvider);
      if (user == null) throw Exception('로그인이 필요합니다.');

      final repo = ref.read(familyRepositoryProvider);
      final family = await repo.createFamily(
        familyName,
        user.uid,
        user.displayName ?? user.email ?? '멤버',
      );
      await ref
          .read(selectedFamilyControllerProvider.notifier)
          .selectFamily(family.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '\'${family.name}\' 가족이 생성되었습니다! '
              '초대 코드: ${family.inviteCode} '
              '(${family.inviteExpiresAt == null ? '관리자 확인 필요' : '7일 유효'})',
            ),
          ),
        );
        ref.invalidate(userFamiliesProvider);
        ref.invalidate(currentFamilyProvider);
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: ${e.toString()}')));
      }
    }
  }

  Future<void> _showJoinFamilyDialog() async {
    final controller = TextEditingController();

    final inviteCode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('초대 코드로 참가하기'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: '초대 코드',
            hintText: '6자리 코드 입력',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              if (code.length == 6) {
                Navigator.pop(context, code);
              }
            },
            child: const Text('참가하기'),
          ),
        ],
      ),
    );

    if (inviteCode == null || inviteCode.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(familySessionUserProvider);
      if (user == null) throw Exception('로그인이 필요합니다.');

      final repo = ref.read(familyRepositoryProvider);
      final family = await repo.joinFamily(
        inviteCode,
        user.uid,
        user.displayName ?? user.email ?? '멤버',
      );
      await ref
          .read(selectedFamilyControllerProvider.notifier)
          .selectFamily(family.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\'${family.name}\' 가족에 참가했습니다!')),
        );
        ref.invalidate(userFamiliesProvider);
        ref.invalidate(currentFamilyProvider);
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.family_restroom,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '가족 그룹 설정',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '새 가족 그룹을 만들거나\n초대 코드로 기존 그룹에 참가하세요.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: _showCreateFamilyDialog,
                icon: const Icon(Icons.add),
                label: const Text('새 가족 만들기'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _showJoinFamilyDialog,
                icon: const Icon(Icons.group_add),
                label: const Text('초대 코드로 참가하기'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
