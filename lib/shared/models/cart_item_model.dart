import 'package:cloud_firestore/cloud_firestore.dart';

class CartItemModel {
  final String id;
  final String name;
  final int quantity;
  final String unit;
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

  static const List<String> defaultUnits = ['개', 'g', 'kg', 'ml', 'L', '팩', '봉', '병', '박스', '줄'];

  const CartItemModel({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unit = '개',
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
      unit: data['unit'] as String? ?? '개',
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
      'unit': unit,
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
    String? unit,
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
      unit: unit ?? this.unit,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
      addedBy: addedBy ?? this.addedBy,
      checkedBy: checkedBy ?? this.checkedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
