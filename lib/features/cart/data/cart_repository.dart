import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/cart_item_model.dart';

/// Unchecked cart row that matches [name] and [category] (including both null)
/// should merge incoming quantity in [CartRepository.addOrMergeItem].
bool cartItemMatchesMergeTarget(
  Map<String, dynamic> data,
  String name,
  String? category,
) {
  if (data['isChecked'] == true) return false;
  if (data['name'] != name) return false;
  if ((data['category'] as String?) != category) return false;
  return true;
}

int nextMergedQuantity(Map<String, dynamic> data, int addQuantity) {
  final existingQty = (data['quantity'] as int?) ?? 1;
  return existingQty + addQuantity;
}

/// Same aggregation as [CartRepository.getFrequentItems] after the ordered query.
List<String> aggregateTopFrequentNames(
  Iterable<Map<String, dynamic>> docDataMaps, {
  int takeTop = 10,
}) {
  final nameCount = <String, int>{};
  for (final data in docDataMaps) {
    final name = data['name'] as String? ?? '';
    if (name.isNotEmpty) {
      nameCount[name] = (nameCount[name] ?? 0) + 1;
    }
  }
  final sorted = nameCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(takeTop).map((e) => e.key).toList();
}

class CartRepository {
  CartRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Testing helper for fake repositories that override every Firestore path.
  CartRepository.forTest() : _firestore = null;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError(
        'CartRepository.forTest() is for fake repositories only. '
        'Override Firestore-dependent methods or pass a real firestore.',
      );
    }
    return firestore;
  }

  CollectionReference<Map<String, dynamic>> _cartCollection(String familyId) {
    return firestore.collection(FirestorePaths.cartItems(familyId));
  }

  Stream<List<CartItemModel>> getCartItemsStream(String familyId) {
    return _cartCollection(familyId)
        .orderBy('isChecked')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CartItemModel.fromFirestore(doc))
            .toList());
  }

  Future<void> addItem(
    String familyId,
    String name,
    String userId, {
    int quantity = 1,
    String? category,
  }) async {
    await _cartCollection(familyId).add({
      'name': name,
      'quantity': quantity,
      'category': category,
      'isChecked': false,
      'addedBy': userId,
      'checkedBy': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adds an item, or merges quantity if an unchecked item with the same name
  /// and same [category] (including both null) already exists.
  ///
  /// The merge path uses a Firestore transaction so that concurrent quantity
  /// bumps are never lost (optimistic-concurrency retry).
  Future<void> addOrMergeItem(
    String familyId,
    String name,
    String userId, {
    int quantity = 1,
    String? category,
  }) async {
    final col = _cartCollection(familyId);

    final candidates = await col
        .where('name', isEqualTo: name)
        .where('isChecked', isEqualTo: false)
        .get();

    DocumentReference<Map<String, dynamic>>? mergeRef;
    for (final doc in candidates.docs) {
      final data = doc.data();
      if (cartItemMatchesMergeTarget(data, name, category)) {
        mergeRef = doc.reference;
        break;
      }
    }

    if (mergeRef != null) {
      final ref = mergeRef;
      await firestore.runTransaction((txn) async {
        final freshDoc = await txn.get(ref);
        if (freshDoc.exists) {
          final data = freshDoc.data()!;
          if (cartItemMatchesMergeTarget(data, name, category)) {
            txn.update(ref, {'quantity': nextMergedQuantity(data, quantity)});
            return;
          }
        }
        txn.set(col.doc(), {
          'name': name,
          'quantity': quantity,
          'category': category,
          'isChecked': false,
          'addedBy': userId,
          'checkedBy': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      await addItem(familyId, name, userId,
          quantity: quantity, category: category);
    }
  }

  Future<void> updateItem(
    String familyId,
    String itemId, {
    String? name,
    int? quantity,
    String? category,
    bool clearCategory = false,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (quantity != null && quantity >= 1) updates['quantity'] = quantity;
    if (clearCategory) {
      updates['category'] = null;
    } else if (category != null) {
      updates['category'] = category;
    }
    if (updates.isNotEmpty) {
      await _cartCollection(familyId).doc(itemId).update(updates);
    }
  }

  Future<void> toggleItem(
    String familyId,
    String itemId,
    bool checked,
    String userId,
  ) async {
    await _cartCollection(familyId).doc(itemId).update({
      'isChecked': checked,
      'checkedBy': checked ? userId : null,
    });
  }

  Future<void> updateQuantity(
    String familyId,
    String itemId,
    int quantity,
  ) async {
    if (quantity < 1) return;
    await _cartCollection(familyId).doc(itemId).update({
      'quantity': quantity,
    });
  }

  Future<void> deleteItem(String familyId, String itemId) async {
    await _cartCollection(familyId).doc(itemId).delete();
  }

  Future<void> clearCheckedItems(String familyId) async {
    final snapshot = await _cartCollection(familyId)
        .where('isChecked', isEqualTo: true)
        .get();
    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Deletes only cart items whose name starts with `[DEMO]`.
  /// Returns the number of deleted documents.
  Future<int> deleteDemoItems(String familyId) async {
    const prefix = '[DEMO]';
    final snap = await _cartCollection(familyId)
        .where('name', isGreaterThanOrEqualTo: prefix)
        .where('name', isLessThanOrEqualTo: '$prefix\uf8ff')
        .get();
    final batch = firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }

  Future<List<String>> getFrequentItems(String familyId) async {
    final snapshot = await _cartCollection(familyId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    return aggregateTopFrequentNames(
      snapshot.docs.map((d) => d.data()),
    );
  }
}
