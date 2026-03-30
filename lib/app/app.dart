import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dongine/app/router.dart';
import 'package:dongine/app/theme.dart';
import 'package:dongine/core/services/notification_service.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class DongineApp extends ConsumerStatefulWidget {
  const DongineApp({super.key});

  @override
  ConsumerState<DongineApp> createState() => _DongineAppState();
}

class _DongineAppState extends ConsumerState<DongineApp> {
  ProviderSubscription<AsyncValue<User?>>? _authSubscription;
  bool _notificationServiceConfigured = false;

  @override
  void initState() {
    super.initState();

    _authSubscription = ref.listenManual<AsyncValue<User?>>(authStateProvider, (
      previous,
      next,
    ) {
      final previousUser = previous?.valueOrNull;
      final nextUser = next.valueOrNull;

      if (previousUser == null && nextUser == null) {
        return;
      }

      final notificationService = ref.read(notificationServiceProvider);

      if (previousUser != null && previousUser.uid != nextUser?.uid) {
        unawaited(
          notificationService.unregisterCurrentDevice(previousUser.uid),
        );
      }

      if (nextUser == null) {
        notificationService.setActiveUser(null);
        return;
      }

      unawaited(
        _configureNotifications(
          notificationService: notificationService,
          uid: nextUser.uid,
        ),
      );
    }, fireImmediately: true);
  }

  Future<void> _configureNotifications({
    required NotificationService notificationService,
    required String uid,
  }) async {
    try {
      if (!_notificationServiceConfigured) {
        _notificationServiceConfigured = true;
        await notificationService.configure(
          onOpenRoute: _openRoute,
          onForegroundNotification: _showForegroundNotification,
        );
      }

      await notificationService.registerCurrentDevice(uid);
    } catch (error, stackTrace) {
      debugPrint('알림 초기화 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _openRoute(String route) async {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go(route);
    });
  }

  void _showForegroundNotification(String title, String body) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final message = body.isEmpty ? title : '$title\n$body';
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _authSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '동이네',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
