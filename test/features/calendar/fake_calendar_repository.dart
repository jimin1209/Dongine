import 'package:dongine/features/calendar/data/calendar_repository.dart';
import 'package:dongine/shared/models/event_model.dart';

/// Firestore 없이 [createEvent] 호출만 기록한다.
class FakeCalendarRepository extends CalendarRepository {
  FakeCalendarRepository() : super.forTest();

  EventModel? lastCreatedEvent;
  String? lastCreateFamilyId;

  @override
  Stream<List<EventModel>> getEventsStream(String familyId) {
    return Stream.value(const []);
  }

  @override
  Future<void> createEvent(String familyId, EventModel event) async {
    lastCreateFamilyId = familyId;
    lastCreatedEvent = event;
  }
}
