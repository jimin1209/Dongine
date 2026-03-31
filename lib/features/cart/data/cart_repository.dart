import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/shared/models/cart_item_model.dart';

class CartRepository {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _cartCollection(String familyId) {
    return _firestore.collection(FirestorePaths.cartItems(familyId));
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
  /// already exists.
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

    // 1. Find a candidate document outside the transaction
    //    (Transaction.get only accepts DocumentReference in the Flutter SDK).
    final candidates = await col
        .where('name', isEqualTo: name)
        .where('isChecked', isEqualTo: false)
        .limit(1)
        .get();

    if (candidates.docs.isNotEmpty) {
      final docRef = candidates.docs.first.reference;
      // 2. Re-read inside a transaction to guarantee atomic read-update.
      await _firestore.runTransaction((txn) async {
        final freshDoc = await txn.get(docRef);
        if (freshDoc.exists) {
          final data = freshDoc.data() as Map<String, dynamic>;
          if (data['isChecked'] == false &&
              data['name'] == name) {
            final existingQty = (data['quantity'] as int?) ?? 1;
            txn.update(docRef, {'quantity': existingQty + quantity});
            return;
          }
        }
        // Document deleted or checked off between query and txn — create new.
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
      // No existing unchecked item — simple add.
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
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<List<String>> getFrequentItems(String familyId) async {
    final snapshot = await _cartCollection(familyId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    final nameCount = <String, int>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name'] as String? ?? '';
      if (name.isNotEmpty) {
        nameCount[name] = (nameCount[name] ?? 0) + 1;
      }
    }

    final sorted = nameCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(10).map((e) => e.key).toList();
  }
}
