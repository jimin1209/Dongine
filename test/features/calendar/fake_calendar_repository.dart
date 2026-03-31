import 'package:dongine/features/calendar/data/calendar_repository.dart';
import 'package:dongine/shared/models/event_model.dart';

/// Firestore 없이 [createEvent] / [updateEvent] 호출을 기록한다.
class FakeCalendarRepository extends CalendarRepository {
  FakeCalendarRepository({this.seedEvents = const []}) : super.forTest();

  final List<EventModel> seedEvents;

  EventModel? lastCreatedEvent;
  String? lastCreateFamilyId;

  EventModel? lastUpdatedEvent;
  String? lastUpdateFamilyId;

  @override
  Stream<List<EventModel>> getEventsStream(String familyId) {
    return Stream.value(seedEvents);
  }

  @override
  Future<void> createEvent(String familyId, EventModel event) async {
    lastCreateFamilyId = familyId;
    lastCreatedEvent = event;
  }

  @override
  Future<void> updateEvent(String familyId, EventModel event) async {
    lastUpdateFamilyId = familyId;
    lastUpdatedEvent = event;
  }
}
