import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/location_model.dart';

class LocationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateLocation(
    String familyId,
    String userId,
    double lat,
    double lng, {
    String? address,
    double? battery,
    double? accuracy,
  }) async {
    final location = LocationModel(
      uid: userId,
      latitude: lat,
      longitude: lng,
      address: address,
      battery: battery,
      accuracy: accuracy,
      updatedAt: DateTime.now(),
    );

    await _firestore
        .doc(FirestorePaths.memberLocation(familyId, userId))
        .set(location.toFirestore(), SetOptions(merge: true));
  }

  Stream<List<LocationModel>> getFamilyLocationsStream(String familyId) {
    return _firestore
        .collection(FirestorePaths.locations(familyId))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationModel.fromFirestore(doc))
            .toList());
  }

  Stream<LocationModel?> getLocationStream(String familyId, String userId) {
    return _firestore
        .doc(FirestorePaths.memberLocation(familyId, userId))
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return LocationModel.fromFirestore(doc);
    });
  }

  Future<void> toggleLocationSharing(
    String familyId,
    String userId,
    bool enabled,
  ) async {
    await _firestore
        .doc(FirestorePaths.familyMember(familyId, userId))
        .update({'locationSharingEnabled': enabled});
  }
}
