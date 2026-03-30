import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/calendar/data/google_calendar_service.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/calendar/domain/calendar_provider.dart';
import 'package:dongine/features/calendar/domain/google_calendar_provider.dart';
import 'package:dongine/shared/models/event_model.dart';

class GoogleCalendarSettings extends ConsumerStatefulWidget {
  const GoogleCalendarSettings({super.key});

  @override
  ConsumerState<GoogleCalendarSettings> createState() =>
      _GoogleCalendarSettingsState();
}

class _GoogleCalendarSettingsState
    extends ConsumerState<GoogleCalendarSettings> {
  bool _isSyncing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingSignIn();
  }

  Future<void> _checkExistingSignIn() async {
    final service = ref.read(googleCalendarServiceProvider);
    final restored = await service.signInSilently();
    if (restored && mounted) {
      ref.read(googleCalendarSignedInProvider.notifier).state = true;
    }
  }

  Future<void> _handleSignIn() async {
    final service = ref.read(googleCalendarServiceProvider);
    final success = await service.signIn();

    if (mounted) {
      ref.read(googleCalendarSignedInProvider.notifier).state = success;
      setState(() {
        _statusMessage = success ? '연결되었습니다' : '로그인에 실패했습니다';
      });
    }
  }

  Future<void> _handleSignOut() async {
    final service = ref.read(googleCalendarServiceProvider);
    await service.signOut();

    if (mounted) {
      ref.read(googleCalendarSignedInProvider.notifier).state = false;
      setState(() {
        _statusMessage = '연결이 해제되었습니다';
      });
    }
  }

  Future<void> _handleSync() async {
    final service = ref.read(googleCalendarServiceProvider);
    final family = ref.read(currentFamilyProvider).valueOrNull;
    final user = ref.read(authStateProvider).valueOrNull;

    if (family == null || user == null) {
      setState(() => _statusMessage = '가족 또는 사용자 정보를 찾을 수 없습니다');
      return;
    }

    setState(() {
      _isSyncing = true;
      _statusMessage = null;
    });

    try {
      final calendarRepo = ref.read(calendarRepositoryProvider);
      final syncCount = await service.syncToFirestore(
        family.id,
        calendarRepo,
        user.uid,
      );

      if (mounted) {
        ref.read(googleCalendarLastSyncProvider.notifier).state =
            DateTime.now();
        setState(() {
          _isSyncing = false;
          _statusMessage = '$syncCount개 이벤트가 동기화되었습니다';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _statusMessage = '동기화 실패: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(googleCalendarSignedInProvider);
    final lastSync = ref.watch(googleCalendarLastSyncProvider);
    final service = ref.watch(googleCalendarServiceProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.event, size: 28),
              const SizedBox(width: 8),
              Text(
                'Google Calendar 설정',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 연결 상태
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSignedIn
                  ? Colors.green.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSignedIn
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSignedIn ? Icons.check_circle : Icons.link_off,
                  color: isSignedIn ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSignedIn ? '연결됨' : '연결 안 됨',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSignedIn ? Colors.green : Colors.grey,
                        ),
                      ),
                      if (isSignedIn && service.currentEmail != null)
                        Text(
                          service.currentEmail!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 연결/해제 버튼
          if (!isSignedIn)
            FilledButton.icon(
              onPressed: _handleSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Google Calendar 연결'),
            )
          else ...[
            // 동기화 버튼
            FilledButton.icon(
              onPressed: _isSyncing ? null : _handleSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? '동기화 중...' : '동기화'),
            ),
            const SizedBox(height: 8),
            // 연결 해제 버튼
            OutlinedButton.icon(
              onPressed: _handleSignOut,
              icon: const Icon(Icons.link_off),
              label: const Text('연결 해제'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],

          // 마지막 동기화 시간
          if (lastSync != null) ...[
            const SizedBox(height: 12),
            Text(
              '마지막 동기화: ${DateFormat('M월 d일 HH:mm', 'ko_KR').format(lastSync)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],

          // 상태 메시지
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _statusMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _statusMessage!.contains('실패')
                        ? Colors.red
                        : Colors.green,
                  ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 이벤트를 Google Calendar로 내보내는 버튼 위젯
class ExportToGoogleCalendarButton extends ConsumerWidget {
  final EventModel event;

  const ExportToGoogleCalendarButton({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(googleCalendarSignedInProvider);

    if (!isSignedIn) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: () => _exportEvent(context, ref),
      icon: const Icon(Icons.upload, size: 18),
      label: const Text('Google Calendar로 내보내기'),
    );
  }

  Future<void> _exportEvent(BuildContext context, WidgetRef ref) async {
    final service = ref.read(googleCalendarServiceProvider);
    final family = ref.read(currentFamilyProvider).valueOrNull;
    final calendarRepo = ref.read(calendarRepositoryProvider);

    try {
      final googleEventId = await service.exportToGoogle(event);
      if (googleEventId != null && family != null) {
        final syncedEvent = event.copyWith(
          externalSource: GoogleCalendarService.googleCalendarSource,
          externalSourceId: googleEventId,
          externalCalendarId: 'primary',
          externalUpdatedAt: DateTime.now(),
        );
        await calendarRepo.updateEvent(family.id, syncedEvent);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              googleEventId != null
                  ? 'Google Calendar에 내보내기 완료'
                  : 'Google Calendar 내보내기 실패',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
        );
      }
    }
  }
}
