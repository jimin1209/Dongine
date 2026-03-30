import 'package:cloud_firestore/cloud_firestore.dart';

class FileItemModel {
  final String id;
  final String name;
  final String type; // 'file' or 'folder'
  final String? mimeType;
  final int? size;
  final String? storagePath;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final String? parentId; // null = root
  final String uploadedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FileItemModel({
    required this.id,
    required this.name,
    required this.type,
    this.mimeType,
    this.size,
    this.storagePath,
    this.downloadUrl,
    this.thumbnailUrl,
    this.parentId,
    required this.uploadedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFolder => type == 'folder';
  bool get isFile => type == 'file';

  factory FileItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FileItemModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? 'file',
      mimeType: data['mimeType'],
      size: data['size'],
      storagePath: data['storagePath'],
      downloadUrl: data['downloadUrl'],
      thumbnailUrl: data['thumbnailUrl'],
      parentId: data['parentId'],
      uploadedBy: data['uploadedBy'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'mimeType': mimeType,
      'size': size,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'thumbnailUrl': thumbnailUrl,
      'parentId': parentId,
      'uploadedBy': uploadedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FileItemModel copyWith({
    String? id,
    String? name,
    String? type,
    String? mimeType,
    int? size,
    String? storagePath,
    String? downloadUrl,
    String? thumbnailUrl,
    String? parentId,
    bool clearParentId = false,
    String? uploadedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FileItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      uploadedBy: uploadedBy ?? this.uploadedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
