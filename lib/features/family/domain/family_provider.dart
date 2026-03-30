import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/data/family_repository.dart';
import 'package:dongine/shared/models/family_model.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository();
});

final currentFamilyProvider = StreamProvider<FamilyModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);

      final repo = ref.watch(familyRepositoryProvider);
      return repo.getUserFamilies(user.uid).asStream().asyncExpand((families) {
        if (families.isEmpty) return Stream.value(null);
        return repo.getFamilyStream(families.first.id);
      });
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});

final familyMembersProvider =
    StreamProvider.family<List<FamilyMember>, String>((ref, familyId) {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getMembersStream(familyId);
});

final userFamiliesProvider = FutureProvider<List<FamilyModel>>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Future.value([]);
      final repo = ref.watch(familyRepositoryProvider);
      return repo.getUserFamilies(user.uid);
    },
    loading: () => Future.value([]),
    error: (_, _) => Future.value([]),
  );
});
