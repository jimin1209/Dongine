import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String uid;
  final double latitude;
  final double longitude;
  final String? address;
  final double? battery;
  final double? accuracy;
  final bool isSharing;
  final DateTime updatedAt;

  const LocationModel({
    required this.uid,
    required this.latitude,
    required this.longitude,
    this.address,
    this.battery,
    this.accuracy,
    this.isSharing = true,
    required this.updatedAt,
  });

  /// 위치 최신성 상태
  LocationFreshness get freshness => freshnessAt(DateTime.now());

  /// [now] 기준으로 위치 최신성을 계산한다.
  LocationFreshness freshnessAt(DateTime now) {
    final diff = now.difference(updatedAt);
    if (diff.inMinutes < 2) return LocationFreshness.fresh;
    if (diff.inMinutes < 10) return LocationFreshness.recent;
    return LocationFreshness.stale;
  }

  factory LocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final geopoint = data['geopoint'] as GeoPoint?;
    return LocationModel(
      uid: doc.id,
      latitude: geopoint?.latitude ?? 0,
      longitude: geopoint?.longitude ?? 0,
      address: data['address'],
      battery: (data['battery'] as num?)?.toDouble(),
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      isSharing: data['isSharing'] as bool? ?? true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'geopoint': GeoPoint(latitude, longitude),
      'address': address,
      'battery': battery,
      'accuracy': accuracy,
      'isSharing': isSharing,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

enum LocationFreshness {
  fresh,  // < 2분
  recent, // 2~10분
  stale,  // > 10분
}
