import 'package:cloud_firestore/cloud_firestore.dart';

class CartItemModel {
  final String id;
  final String name;
  final int quantity;
  final String? category;
  final bool isChecked;
  final String addedBy;
  final String? checkedBy;
  final DateTime createdAt;

  static const List<String> categories = [
    '과일',
    '채소',
    '육류',
    '유제품',
    '음료',
    '생활용품',
    '기타',
  ];

  const CartItemModel({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.category,
    this.isChecked = false,
    required this.addedBy,
    this.checkedBy,
    required this.createdAt,
  });

  factory CartItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CartItemModel(
      id: doc.id,
      name: data['name'] ?? '',
      quantity: data['quantity'] ?? 1,
      category: data['category'] as String?,
      isChecked: data['isChecked'] ?? false,
      addedBy: data['addedBy'] ?? '',
      checkedBy: data['checkedBy'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'quantity': quantity,
      'category': category,
      'isChecked': isChecked,
      'addedBy': addedBy,
      'checkedBy': checkedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  CartItemModel copyWith({
    String? id,
    String? name,
    int? quantity,
    String? category,
    bool? isChecked,
    String? addedBy,
    String? checkedBy,
    DateTime? createdAt,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
      addedBy: addedBy ?? this.addedBy,
      checkedBy: checkedBy ?? this.checkedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
