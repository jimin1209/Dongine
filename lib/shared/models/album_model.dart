import 'package:cloud_firestore/cloud_firestore.dart';

class AlbumModel {
  final String id;
  final String title;
  final String? description;
  final String? coverPhotoUrl;
  final int photoCount;
  final String? eventId;
  final String createdBy;
  final DateTime createdAt;

  const AlbumModel({
    required this.id,
    required this.title,
    this.description,
    this.coverPhotoUrl,
    this.photoCount = 0,
    this.eventId,
    required this.createdBy,
    required this.createdAt,
  });

  factory AlbumModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlbumModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      coverPhotoUrl: data['coverPhotoUrl'],
      photoCount: data['photoCount'] ?? 0,
      eventId: data['eventId'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'coverPhotoUrl': coverPhotoUrl,
      'photoCount': photoCount,
      'eventId': eventId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class PhotoModel {
  final String id;
  final String albumId;
  final String imageUrl;
  final String? thumbnailUrl;
  final String? caption;
  final String uploadedBy;
  final DateTime createdAt;

  const PhotoModel({
    required this.id,
    required this.albumId,
    required this.imageUrl,
    this.thumbnailUrl,
    this.caption,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory PhotoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PhotoModel(
      id: doc.id,
      albumId: data['albumId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      caption: data['caption'],
      uploadedBy: data['uploadedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'albumId': albumId,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'uploadedBy': uploadedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
