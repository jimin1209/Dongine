import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyModel {
  final String id;
  final String name;
  final String? photoUrl;
  final String createdBy;
  final List<String> memberIds;
  final String inviteCode;
  final DateTime? inviteExpiresAt;
  final DateTime createdAt;

  const FamilyModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.createdBy,
    this.memberIds = const [],
    required this.inviteCode,
    this.inviteExpiresAt,
    required this.createdAt,
  });

  factory FamilyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyModel(
      id: doc.id,
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      createdBy: data['createdBy'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      inviteCode: data['inviteCode'] ?? '',
      inviteExpiresAt: (data['inviteExpiresAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  FamilyModel copyWith({
    String? id,
    String? name,
    String? photoUrl,
    String? createdBy,
    List<String>? memberIds,
    String? inviteCode,
    DateTime? inviteExpiresAt,
    bool clearInviteExpiresAt = false,
    DateTime? createdAt,
  }) {
    return FamilyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      createdBy: createdBy ?? this.createdBy,
      memberIds: memberIds ?? this.memberIds,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteExpiresAt: clearInviteExpiresAt
          ? null
          : inviteExpiresAt ?? this.inviteExpiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'createdBy': createdBy,
      'memberIds': memberIds,
      'inviteCode': inviteCode,
      'inviteExpiresAt': inviteExpiresAt == null
          ? null
          : Timestamp.fromDate(inviteExpiresAt!),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class FamilyMember {
  final String uid;
  final String role;
  final String nickname;
  final DateTime joinedAt;
  final bool locationSharingEnabled;

  const FamilyMember({
    required this.uid,
    required this.role,
    required this.nickname,
    required this.joinedAt,
    this.locationSharingEnabled = true,
  });

  factory FamilyMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyMember(
      uid: doc.id,
      role: data['role'] ?? 'member',
      nickname: data['nickname'] ?? '',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      locationSharingEnabled: data['locationSharingEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'role': role,
      'nickname': nickname,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'locationSharingEnabled': locationSharingEnabled,
    };
  }
}
