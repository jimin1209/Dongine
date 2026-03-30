import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/event_model.dart';

class CalendarRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _eventsRef(String familyId) {
    return _firestore.collection(FirestorePaths.events(familyId));
  }

  Stream<List<EventModel>> getEventsStream(String familyId) {
    return _eventsRef(familyId)
        .orderBy('startAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
    });
  }

  Future<List<EventModel>> getEventsForDay(
      String familyId, DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _eventsRef(familyId)
        .where('startAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('startAt')
        .get();

    return snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
  }

  Future<EventModel?> getEvent(String familyId, String eventId) async {
    final doc = await _eventsRef(familyId).doc(eventId).get();
    if (!doc.exists) return null;
    return EventModel.fromFirestore(doc);
  }

  Future<EventModel?> getEventByExternalSourceId(
    String familyId,
    String externalSourceId,
  ) async {
    final snapshot = await _eventsRef(familyId)
        .where('externalSourceId', isEqualTo: externalSourceId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return EventModel.fromFirestore(snapshot.docs.first);
  }

  Future<void> createEvent(String familyId, EventModel event) async {
    await upsertEvent(familyId, event);
  }

  Future<void> updateEvent(String familyId, EventModel event) async {
    await _eventsRef(familyId).doc(event.id).update(event.toFirestore());
  }

  Future<void> upsertEvent(String familyId, EventModel event) async {
    await _eventsRef(familyId).doc(event.id).set(event.toFirestore());
  }

  Future<void> deleteEvent(String familyId, String eventId) async {
    await _eventsRef(familyId).doc(eventId).delete();
  }
}
