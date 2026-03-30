import 'package:dongine/shared/models/cart_item_model.dart';

/// Returns `true` when the [items] list already contains an unchecked item
/// whose name matches [name] exactly.
bool hasUncheckedDuplicate(List<CartItemModel> items, String name) {
  return items.any((i) => !i.isChecked && i.name == name);
}

/// Computes the merged quantity when adding [addQuantity] to an existing item
/// that already has [existingQuantity].
int computeMergedQuantity(int existingQuantity, int addQuantity) {
  return existingQuantity + addQuantity;
}

/// Filters [suggestions] by removing names that are already present in
/// [uncheckedNames]. This mirrors the UI logic that hides suggestion chips
/// for items already in the unchecked cart.
List<String> filterSuggestions(
  List<String> suggestions,
  Set<String> uncheckedNames,
) {
  return suggestions.where((s) => !uncheckedNames.contains(s)).toList();
}

/// Computes the top-[limit] most-frequent item names from a raw [names] list
/// (ordered by frequency descending). Pure equivalent of
/// `CartRepository.getFrequentItems`.
List<String> computeFrequentItems(List<String> names, {int limit = 10}) {
  final counts = <String, int>{};
  for (final n in names) {
    if (n.isNotEmpty) {
      counts[n] = (counts[n] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(limit).map((e) => e.key).toList();
}

/// Computes the Firestore update-field map for an item edit.
///
/// Only fields that actually changed are included. Returns an empty map when
/// nothing changed (caller should skip the write).
Map<String, dynamic> computeItemUpdateFields({
  required String newName,
  required String oldName,
  required int newQuantity,
  required int oldQuantity,
  required String? newCategory,
  required String? oldCategory,
}) {
  final updates = <String, dynamic>{};
  if (newName != oldName) updates['name'] = newName;
  if (newQuantity != oldQuantity && newQuantity >= 1) {
    updates['quantity'] = newQuantity;
  }
  if (newCategory != oldCategory) {
    updates['category'] = newCategory; // null means clear
  }
  return updates;
}

/// Validates quantity bounds. Returns the clamped value (min 1, max 99).
int clampQuantity(int value) {
  if (value < 1) return 1;
  if (value > 99) return 99;
  return value;
}
