import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/cart/data/cart_repository.dart';
import 'package:dongine/shared/models/cart_item_model.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository();
});

final cartItemsProvider =
    StreamProvider.family<List<CartItemModel>, String>((ref, familyId) {
  final repo = ref.watch(cartRepositoryProvider);
  return repo.getCartItemsStream(familyId);
});

final cartFilterProvider = StateProvider<String?>((ref) => null);
