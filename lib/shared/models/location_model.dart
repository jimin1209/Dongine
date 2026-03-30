import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String uid;
  final double latitude;
  final double longitude;
  final String? address;
  final double? battery;
  final double? accuracy;
  final DateTime updatedAt;

  const LocationModel({
    required this.uid,
    required this.latitude,
    required this.longitude,
    this.address,
    this.battery,
    this.accuracy,
    required this.updatedAt,
  });

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
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'geopoint': GeoPoint(latitude, longitude),
      'address': address,
      'battery': battery,
      'accuracy': accuracy,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
