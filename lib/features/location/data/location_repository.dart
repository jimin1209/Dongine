import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/location_model.dart';

/// 멤버 문서 스냅샷에서 위치 공유 여부를 해석한다.
/// 문서가 없으면 가족 멤버십이 없거나 동기화 전으로 간주해 `false`(추적·UI 모두 보수적으로 꺼짐).
/// 필드가 없으면 [FamilyMember.fromFirestore]와 같이 기본값 `true`를 사용한다.
bool locationSharingEnabledFromMemberData(
  bool docExists,
  Map<String, dynamic>? data,
) {
  if (!docExists || data == null) return false;
  return data['locationSharingEnabled'] as bool? ?? true;
}

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

  /// 현재 사용자 멤버 문서의 `locationSharingEnabled`를 실시간으로 구독한다.
  Stream<bool> watchLocationSharingEnabled(String familyId, String userId) {
    return _firestore
        .doc(FirestorePaths.familyMember(familyId, userId))
        .snapshots()
        .map(
          (doc) => locationSharingEnabledFromMemberData(
            doc.exists,
            doc.data(),
          ),
        );
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
