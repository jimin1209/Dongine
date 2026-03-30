import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/shared/models/location_model.dart';

void main() {
  LocationModel makeModel({required DateTime updatedAt}) {
    return LocationModel(
      uid: 'user-1',
      latitude: 37.5665,
      longitude: 126.9780,
      address: '서울특별시 중구 세종대로',
      battery: 0.85,
      accuracy: 12.5,
      updatedAt: updatedAt,
    );
  }

  // ── freshness 경계값 테스트 ──────────────────────────────

  group('freshnessAt', () {
    final base = DateTime(2026, 3, 30, 12, 0);

    test('0초 전 → fresh', () {
      final m = makeModel(updatedAt: base);
      expect(m.freshnessAt(base), LocationFreshness.fresh);
    });

    test('1분 59초 전 → fresh (경계 직전)', () {
      final m = makeModel(updatedAt: base);
      final now = base.add(const Duration(minutes: 1, seconds: 59));
      expect(m.freshnessAt(now), LocationFreshness.fresh);
    });

    test('2분 정각 → recent (경계)', () {
      final m = makeModel(updatedAt: base);
      final now = base.add(const Duration(minutes: 2));
      expect(m.freshnessAt(now), LocationFreshness.recent);
    });

    test('9분 59초 전 → recent (경계 직전)', () {
      final m = makeModel(updatedAt: base);
      final now = base.add(const Duration(minutes: 9, seconds: 59));
      expect(m.freshnessAt(now), LocationFreshness.recent);
    });

    test('10분 정각 → stale (경계)', () {
      final m = makeModel(updatedAt: base);
      final now = base.add(const Duration(minutes: 10));
      expect(m.freshnessAt(now), LocationFreshness.stale);
    });

    test('1시간 전 → stale', () {
      final m = makeModel(updatedAt: base);
      final now = base.add(const Duration(hours: 1));
      expect(m.freshnessAt(now), LocationFreshness.stale);
    });
  });

  // ── freshness getter 는 freshnessAt(DateTime.now()) 와 동일 ────

  test('freshness getter 는 현재 시각 기준으로 동작한다', () {
    // updatedAt 이 아주 오래전이면 stale
    final old = makeModel(updatedAt: DateTime(2000));
    expect(old.freshness, LocationFreshness.stale);

    // updatedAt 이 방금이면 fresh
    final now = makeModel(updatedAt: DateTime.now());
    expect(now.freshness, LocationFreshness.fresh);
  });

  // ── toFirestore 직렬화 ───────────────────────────────────

  group('toFirestore', () {
    test('geopoint 가 GeoPoint 타입으로 직렬화된다', () {
      final m = makeModel(updatedAt: DateTime(2026, 3, 30));
      final map = m.toFirestore();

      final geopoint = map['geopoint'] as GeoPoint;
      expect(geopoint.latitude, 37.5665);
      expect(geopoint.longitude, 126.9780);
    });

    test('updatedAt 이 Timestamp 로 직렬화된다', () {
      final dt = DateTime(2026, 3, 30, 12, 30);
      final m = makeModel(updatedAt: dt);
      final map = m.toFirestore();

      expect(map['updatedAt'], Timestamp.fromDate(dt));
    });

    test('모든 필드가 맵에 포함된다', () {
      final m = makeModel(updatedAt: DateTime(2026, 3, 30));
      final map = m.toFirestore();

      expect(map.containsKey('geopoint'), isTrue);
      expect(map.containsKey('address'), isTrue);
      expect(map.containsKey('battery'), isTrue);
      expect(map.containsKey('accuracy'), isTrue);
      expect(map.containsKey('isSharing'), isTrue);
      expect(map.containsKey('updatedAt'), isTrue);
    });

    test('address 가 null 이면 null 로 직렬화된다', () {
      final m = LocationModel(
        uid: 'u1',
        latitude: 0,
        longitude: 0,
        updatedAt: DateTime(2026, 3, 30),
      );
      expect(m.toFirestore()['address'], isNull);
    });

    test('isSharing 기본값은 true', () {
      final m = makeModel(updatedAt: DateTime(2026, 3, 30));
      expect(m.toFirestore()['isSharing'], isTrue);
    });
  });

  // ── fromFirestore 역직렬화 (맵 ↔ 모델 라운드트립) ──────

  group('fromFirestore round-trip 검증 (toFirestore 필드 기준)', () {
    // DocumentSnapshot 을 직접 생성할 수 없으므로
    // toFirestore 출력 맵의 값이 fromFirestore 가 기대하는 형식과
    // 일치하는지 검증한다.

    test('toFirestore 맵에서 GeoPoint 복원이 가능하다', () {
      final m = makeModel(updatedAt: DateTime(2026, 3, 30, 9));
      final map = m.toFirestore();

      final gp = map['geopoint'] as GeoPoint;
      expect(gp.latitude, m.latitude);
      expect(gp.longitude, m.longitude);
    });

    test('toFirestore 맵에서 updatedAt Timestamp 복원이 가능하다', () {
      final dt = DateTime(2026, 3, 30, 15, 45);
      final m = makeModel(updatedAt: dt);
      final map = m.toFirestore();

      final restored = (map['updatedAt'] as Timestamp).toDate();
      expect(restored, dt);
    });

    test('toFirestore 맵의 스칼라 값이 원본과 일치한다', () {
      final m = makeModel(updatedAt: DateTime(2026, 3, 30));
      final map = m.toFirestore();

      expect(map['address'], m.address);
      expect(map['battery'], m.battery);
      expect(map['accuracy'], m.accuracy);
      expect(map['isSharing'], m.isSharing);
    });
  });
}
