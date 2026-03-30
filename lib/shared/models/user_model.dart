import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final List<String> fcmTokens;
  final List<String> familyIds;
  final DateTime createdAt;
  final DateTime lastSeen;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.fcmTokens = const [],
    this.familyIds = const [],
    required this.createdAt,
    required this.lastSeen,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      fcmTokens: List<String>.from(data['fcmTokens'] ?? []),
      familyIds: List<String>.from(data['familyIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'fcmTokens': fcmTokens,
      'familyIds': familyIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    List<String>? fcmTokens,
    List<String>? familyIds,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      familyIds: familyIds ?? this.familyIds,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
