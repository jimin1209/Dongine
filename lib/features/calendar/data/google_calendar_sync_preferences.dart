import 'package:shared_preferences/shared_preferences.dart';

/// Google Calendar 동기화 결과를 `shared_preferences`에 보관한다.
class GoogleCalendarSyncPreferences {
  static const _lastAtMsKey = 'google_calendar_last_sync_at_ms';
  static const _lastSuccessKey = 'google_calendar_last_sync_success';
  static const _lastMessageKey = 'google_calendar_last_sync_message';

  Future<GoogleCalendarSyncPersisted?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastAtMsKey);
    if (ms == null) return null;
    final success = prefs.getBool(_lastSuccessKey);
    final message = prefs.getString(_lastMessageKey);
    if (success == null || message == null) return null;

    return GoogleCalendarSyncPersisted(
      completedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      success: success,
      message: message,
    );
  }

  Future<void> save({
    required DateTime completedAt,
    required bool success,
    required String message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastAtMsKey,
      completedAt.millisecondsSinceEpoch,
    );
    await prefs.setBool(_lastSuccessKey, success);
    await prefs.setString(_lastMessageKey, message);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastAtMsKey);
    await prefs.remove(_lastSuccessKey);
    await prefs.remove(_lastMessageKey);
  }
}

class GoogleCalendarSyncPersisted {
  final DateTime completedAt;
  final bool success;
  final String message;

  const GoogleCalendarSyncPersisted({
    required this.completedAt,
    required this.success,
    required this.message,
  });
}
