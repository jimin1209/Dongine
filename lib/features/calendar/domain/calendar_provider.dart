import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/calendar/data/calendar_repository.dart';
import 'package:dongine/features/calendar/data/calendar_view_preferences.dart';
import 'package:dongine/shared/models/event_model.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository();
});

final calendarViewPreferencesProvider =
    Provider<CalendarViewPreferences>((ref) {
  return CalendarViewPreferences();
});

final eventsProvider =
    StreamProvider.family<List<EventModel>, String>((ref, familyId) {
  final repo = ref.watch(calendarRepositoryProvider);
  return repo.getEventsStream(familyId);
});

final selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final selectedDayEventsProvider = Provider.family<List<EventModel>, String>(
  (ref, familyId) {
    final eventsAsync = ref.watch(eventsProvider(familyId));
    final selectedDay = ref.watch(selectedDayProvider);

    return eventsAsync.when(
      data: (events) {
        return events.where((event) {
          final eventDay = DateTime(
              event.startAt.year, event.startAt.month, event.startAt.day);
          final selected = DateTime(
              selectedDay.year, selectedDay.month, selectedDay.day);
          return eventDay.isAtSameMomentAs(selected);
        }).toList();
      },
      loading: () => [],
      error: (_, _) => [],
    );
  },
);
