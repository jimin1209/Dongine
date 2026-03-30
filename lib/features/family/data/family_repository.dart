import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/app_constants.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/family_model.dart';

class FamilyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      AppConstants.inviteCodeLength,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  DateTime _buildInviteExpiration(DateTime now) {
    return now.add(const Duration(days: AppConstants.inviteExpirationDays));
  }

  Map<String, dynamic> _buildInvitationData({
    required String familyId,
    required String inviteCode,
    required String createdBy,
    required DateTime now,
    required DateTime expiresAt,
  }) {
    return {
      'familyId': familyId,
      'inviteCode': inviteCode,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': true,
    };
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final inviteCode = _generateInviteCode();
      final inviteDoc = await _firestore
          .doc(FirestorePaths.invitation(inviteCode))
          .get();

      if (!inviteDoc.exists) {
        return inviteCode;
      }
    }

    throw Exception('초대 코드 생성에 실패했습니다. 다시 시도해주세요.');
  }

  Future<void> _assertFamilyAdmin(String familyId, String uid) async {
    final memberDoc = await _firestore
        .doc(FirestorePaths.familyMember(familyId, uid))
        .get();

    if (!memberDoc.exists) {
      throw Exception('가족 멤버가 아닙니다.');
    }

    final member = FamilyMember.fromFirestore(memberDoc);
    if (member.role != 'admin') {
      throw Exception('가족 관리자만 초대 코드를 관리할 수 있습니다.');
    }
  }

  Future<FamilyModel> createFamily(
    String name,
    String creatorUid,
    String creatorName,
  ) async {
    final docRef = _firestore.collection(FirestorePaths.families).doc();
    final now = DateTime.now();
    final inviteCode = await _generateUniqueInviteCode();
    final inviteExpiresAt = _buildInviteExpiration(now);

    final family = FamilyModel(
      id: docRef.id,
      name: name,
      createdBy: creatorUid,
      memberIds: [creatorUid],
      inviteCode: inviteCode,
      inviteExpiresAt: inviteExpiresAt,
      createdAt: now,
    );

    final member = FamilyMember(
      uid: creatorUid,
      role: 'admin',
      nickname: creatorName,
      joinedAt: now,
    );

    final batch = _firestore.batch();

    batch.set(docRef, family.toFirestore());
    batch.set(
      _firestore.doc(FirestorePaths.invitation(inviteCode)),
      _buildInvitationData(
        familyId: docRef.id,
        inviteCode: inviteCode,
        createdBy: creatorUid,
        now: now,
        expiresAt: inviteExpiresAt,
      ),
    );

    batch.set(
      _firestore.doc(FirestorePaths.familyMember(docRef.id, creatorUid)),
      member.toFirestore(),
    );

    batch.update(_firestore.doc(FirestorePaths.user(creatorUid)), {
      'familyIds': FieldValue.arrayUnion([docRef.id]),
    });

    await batch.commit();

    return family;
  }

  Future<FamilyModel> joinFamily(
    String inviteCode,
    String uid,
    String nickname,
  ) async {
    final normalizedInviteCode = inviteCode.trim().toUpperCase();
    final inviteDoc = await _firestore
        .doc(FirestorePaths.invitation(normalizedInviteCode))
        .get();

    if (!inviteDoc.exists) {
      throw Exception('유효하지 않은 초대 코드입니다.');
    }

    final inviteData = inviteDoc.data() as Map<String, dynamic>;
    final familyId = inviteData['familyId'] as String?;
    final expiresAt = (inviteData['expiresAt'] as Timestamp?)?.toDate();
    final isActive = inviteData['isActive'] != false;

    if (familyId == null || familyId.isEmpty) {
      throw Exception('유효하지 않은 초대 코드입니다.');
    }

    if (!isActive || expiresAt == null || !expiresAt.isAfter(DateTime.now())) {
      throw Exception('만료된 초대 코드입니다. 관리자에게 새 코드를 요청해주세요.');
    }

    final familyDoc = await _firestore
        .doc(FirestorePaths.family(familyId))
        .get();
    if (!familyDoc.exists) {
      throw Exception('가족 그룹을 찾을 수 없습니다.');
    }

    final family = FamilyModel.fromFirestore(familyDoc);

    if (family.inviteCode != normalizedInviteCode) {
      throw Exception('더 이상 유효하지 않은 초대 코드입니다. 최신 코드를 요청해주세요.');
    }

    if (family.memberIds.contains(uid)) {
      throw Exception('이미 이 가족 그룹의 멤버입니다.');
    }

    if (family.memberIds.length >= AppConstants.maxFamilyMembers) {
      throw Exception('가족 그룹 정원이 가득 찼습니다.');
    }

    final member = FamilyMember(
      uid: uid,
      role: 'member',
      nickname: nickname,
      joinedAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    batch.update(familyDoc.reference, {
      'memberIds': FieldValue.arrayUnion([uid]),
    });

    batch.set(
      _firestore.doc(FirestorePaths.familyMember(family.id, uid)),
      member.toFirestore(),
    );

    batch.update(_firestore.doc(FirestorePaths.user(uid)), {
      'familyIds': FieldValue.arrayUnion([family.id]),
    });

    await batch.commit();

    return family;
  }

  Future<FamilyModel> refreshInviteCode(
    String familyId,
    String adminUid,
  ) async {
    await _assertFamilyAdmin(familyId, adminUid);

    final familyDoc = await _firestore
        .doc(FirestorePaths.family(familyId))
        .get();
    if (!familyDoc.exists) {
      throw Exception('가족 그룹을 찾을 수 없습니다.');
    }

    final family = FamilyModel.fromFirestore(familyDoc);
    final nextInviteCode = await _generateUniqueInviteCode();
    final now = DateTime.now();
    final inviteExpiresAt = _buildInviteExpiration(now);
    final batch = _firestore.batch();

    if (family.inviteCode.isNotEmpty) {
      batch.delete(
        _firestore.doc(FirestorePaths.invitation(family.inviteCode)),
      );
    }

    batch.update(familyDoc.reference, {
      'inviteCode': nextInviteCode,
      'inviteExpiresAt': Timestamp.fromDate(inviteExpiresAt),
    });

    batch.set(
      _firestore.doc(FirestorePaths.invitation(nextInviteCode)),
      _buildInvitationData(
        familyId: family.id,
        inviteCode: nextInviteCode,
        createdBy: adminUid,
        now: now,
        expiresAt: inviteExpiresAt,
      ),
    );

    await batch.commit();

    return family.copyWith(
      inviteCode: nextInviteCode,
      inviteExpiresAt: inviteExpiresAt,
    );
  }

  Future<FamilyModel> getFamily(String familyId) async {
    final doc = await _firestore.doc(FirestorePaths.family(familyId)).get();

    if (!doc.exists) {
      throw Exception('가족 그룹을 찾을 수 없습니다.');
    }

    return FamilyModel.fromFirestore(doc);
  }

  Stream<FamilyModel> getFamilyStream(String familyId) {
    return _firestore.doc(FirestorePaths.family(familyId)).snapshots().map((
      doc,
    ) {
      if (!doc.exists) {
        throw Exception('가족 그룹을 찾을 수 없습니다.');
      }
      return FamilyModel.fromFirestore(doc);
    });
  }

  Stream<List<FamilyMember>> getMembersStream(String familyId) {
    return _firestore
        .collection(FirestorePaths.familyMembers(familyId))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FamilyMember.fromFirestore(doc))
              .toList(),
        );
  }

  Future<List<FamilyModel>> getUserFamilies(String uid) async {
    final userDoc = await _firestore.doc(FirestorePaths.user(uid)).get();

    if (!userDoc.exists) return [];

    final data = userDoc.data() as Map<String, dynamic>;
    final familyIds = List<String>.from(data['familyIds'] ?? []);

    if (familyIds.isEmpty) return [];

    final families = <FamilyModel>[];
    for (final familyId in familyIds) {
      try {
        final family = await getFamily(familyId);
        families.add(family);
      } catch (_) {
        // 삭제된 가족 그룹은 무시
      }
    }

    return families;
  }

  Stream<List<FamilyModel>> getUserFamiliesStream(String uid) {
    return _firestore.doc(FirestorePaths.user(uid)).snapshots().asyncMap((
      userDoc,
    ) async {
      if (!userDoc.exists) return <FamilyModel>[];

      final data = userDoc.data() as Map<String, dynamic>;
      final familyIds = List<String>.from(data['familyIds'] ?? []);

      if (familyIds.isEmpty) return <FamilyModel>[];

      final families = <FamilyModel>[];
      for (final familyId in familyIds) {
        try {
          families.add(await getFamily(familyId));
        } catch (_) {
          // 삭제되었거나 접근할 수 없는 가족은 무시
        }
      }

      return families;
    });
  }

  Future<void> leaveFamily(String familyId, String uid) async {
    final batch = _firestore.batch();

    batch.update(_firestore.doc(FirestorePaths.family(familyId)), {
      'memberIds': FieldValue.arrayRemove([uid]),
    });

    batch.delete(_firestore.doc(FirestorePaths.familyMember(familyId, uid)));

    batch.update(_firestore.doc(FirestorePaths.user(uid)), {
      'familyIds': FieldValue.arrayRemove([familyId]),
    });

    await batch.commit();
  }
}
