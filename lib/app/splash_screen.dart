import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _GateScaffold(message: '로그인 정보를 확인하고 있어요...'),
      error: (error, _) => _GateErrorScaffold(
        message: '로그인 상태를 확인할 수 없습니다.\n다시 시도해 주세요.',
        actionLabel: '로그인 화면으로',
        onPressed: () => context.go('/login'),
      ),
      data: (user) {
        if (user == null) {
          _navigate(context, '/onboarding');
          return const _GateScaffold(message: '동이네에 오신 것을 환영합니다!');
        }

        final currentFamilyAsync = ref.watch(currentFamilyProvider);
        return currentFamilyAsync.when(
          loading: () =>
              const _GateScaffold(message: '가족 그룹 정보를 불러오고 있어요...'),
          error: (error, _) => _GateErrorScaffold(
            message: '가족 정보를 확인할 수 없습니다.\n다시 시도해 주세요.',
            actionLabel: '가족 설정으로',
            onPressed: () => context.go('/family-setup'),
          ),
          data: (family) {
            _navigate(context, family == null ? '/family-setup' : '/home');
            return _GateScaffold(
              message: family == null
                  ? '가족 그룹 설정으로 이동합니다...'
                  : '홈으로 이동합니다...',
            );
          },
        );
      },
    );
  }

  void _navigate(BuildContext context, String location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.go(location);
      }
    });
  }
}

class _GateScaffold extends StatelessWidget {
  final String message;

  const _GateScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _GateErrorScaffold extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _GateErrorScaffold({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onPressed,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
