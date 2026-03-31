import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/event_model.dart';

/// 삭제 정책: Google API 삭제를 먼저 호출해야 하는지 (exported + 외부 ID 있음).
bool calendarDeleteShouldInvokeGoogle(EventModel event) {
  return event.isGoogleExported && event.externalSourceId != null;
}

class CalendarRepository {
  CalendarRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Testing helper for fake repositories that override Firestore access.
  CalendarRepository.forTest() : _firestore = null;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError(
        'CalendarRepository.forTest() is for fake repositories only. '
        'Override Firestore-dependent methods or pass a real firestore.',
      );
    }
    return firestore;
  }

  CollectionReference _eventsRef(String familyId) {
    return firestore.collection(FirestorePaths.events(familyId));
  }

  Stream<List<EventModel>> getEventsStream(String familyId) {
    return _eventsRef(familyId).orderBy('startAt').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
    });
  }

  Future<List<EventModel>> getEventsForDay(
    String familyId,
    DateTime day,
  ) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _eventsRef(familyId)
        .where(
          'startAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
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
    final snapshot = await _eventsRef(
      familyId,
    ).where('externalSourceId', isEqualTo: externalSourceId).limit(1).get();

    if (snapshot.docs.isEmpty) return null;
    return EventModel.fromFirestore(snapshot.docs.first);
  }

  Future<List<EventModel>> getEventsByExternalSource(
    String familyId,
    String externalSource,
  ) async {
    final snapshot = await _eventsRef(
      familyId,
    ).where('externalSource', isEqualTo: externalSource).get();

    return snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
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

  /// Deletes only events whose title starts with `[DEMO]`.
  /// Returns the number of deleted documents.
  Future<int> deleteDemoEvents(String familyId) async {
    const prefix = '[DEMO]';
    final snap = await _eventsRef(familyId)
        .where('title', isGreaterThanOrEqualTo: prefix)
        .where('title', isLessThanOrEqualTo: '$prefix\uf8ff')
        .get();
    final batch = firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }

  /// 삭제 정책을 적용한 이벤트 삭제.
  /// - exported 일정: Google Calendar에서도 삭제
  /// - imported 일정: 로컬만 삭제 (Google 보호)
  /// - 로컬 일정: 그냥 삭제
  Future<void> deleteEventWithPolicy(
    String familyId,
    EventModel event,
    GoogleCalendarDeleteFn? deleteFromGoogle,
  ) async {
    if (calendarDeleteShouldInvokeGoogle(event) && deleteFromGoogle != null) {
      await deleteFromGoogle(event.externalSourceId!);
    }
    // imported 일정은 Google 측은 건드리지 않음
    await deleteEvent(familyId, event.id);
  }
}

/// Google Calendar 삭제 함수 시그니처
typedef GoogleCalendarDeleteFn = Future<void> Function(String googleEventId);
