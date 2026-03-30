import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/data/family_preferences.dart';
import 'package:dongine/features/family/data/family_repository.dart';
import 'package:dongine/shared/models/family_model.dart';

/// 가족 설정 화면에서 쓰는 로그인 사용자 스냅샷.
/// 기본값은 [authStateProvider]에서 파생되며, 테스트에서는 이 provider를 override 할 수 있다.
class FamilySessionUser {
  const FamilySessionUser({
    required this.uid,
    this.email,
    this.displayName,
  });

  final String uid;
  final String? email;
  final String? displayName;
}

final familySessionUserProvider = Provider<FamilySessionUser?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return FamilySessionUser(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
  );
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository();
});

final familyPreferencesProvider = Provider<FamilyPreferences>((ref) {
  return FamilyPreferences();
});

class SelectedFamilyController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.read(familyPreferencesProvider).getSelectedFamilyId();
  }

  Future<void> selectFamily(String? familyId) async {
    state = AsyncValue.data(familyId);

    final preferences = ref.read(familyPreferencesProvider);
    if (familyId == null) {
      await preferences.clearSelectedFamilyId();
      return;
    }

    await preferences.setSelectedFamilyId(familyId);
  }
}

final selectedFamilyControllerProvider =
    AsyncNotifierProvider<SelectedFamilyController, String?>(
  SelectedFamilyController.new,
);

final _userFamiliesStreamProvider = StreamProvider<List<FamilyModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return Stream.value(const <FamilyModel>[]);
  }

  final repo = ref.watch(familyRepositoryProvider);
  return repo.getUserFamiliesStream(user.uid);
});

final userFamiliesProvider = Provider<AsyncValue<List<FamilyModel>>>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return const AsyncValue.data(<FamilyModel>[]);
      }
      return ref.watch(_userFamiliesStreamProvider);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

final currentFamilyIdProvider = Provider<AsyncValue<String?>>((ref) {
  final familiesAsync = ref.watch(userFamiliesProvider);
  final selectedFamilyIdAsync = ref.watch(selectedFamilyControllerProvider);

  return familiesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (families) {
      if (families.isEmpty) {
        if (selectedFamilyIdAsync.valueOrNull != null) {
          scheduleMicrotask(() {
            ref.read(selectedFamilyControllerProvider.notifier).selectFamily(
                  null,
                );
          });
        }
        return const AsyncValue.data(null);
      }

      return selectedFamilyIdAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (error, stack) {
          final fallbackFamilyId = families.first.id;
          scheduleMicrotask(() {
            ref.read(selectedFamilyControllerProvider.notifier).selectFamily(
                  fallbackFamilyId,
                );
          });
          return AsyncValue.data(fallbackFamilyId);
        },
        data: (selectedFamilyId) {
          final selectedFamily =
              _findFamilyById(families, selectedFamilyId) ?? families.first;

          if (selectedFamily.id != selectedFamilyId) {
            scheduleMicrotask(() {
              ref.read(selectedFamilyControllerProvider.notifier).selectFamily(
                    selectedFamily.id,
                  );
            });
          }

          return AsyncValue.data(selectedFamily.id);
        },
      );
    },
  );
});

final familyStreamProvider = StreamProvider.family<FamilyModel, String>((
  ref,
  familyId,
) {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getFamilyStream(familyId);
});

final currentFamilyProvider = Provider<AsyncValue<FamilyModel?>>((ref) {
  final currentFamilyIdAsync = ref.watch(currentFamilyIdProvider);

  return currentFamilyIdAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (familyId) {
      if (familyId == null) {
        return const AsyncValue.data(null);
      }

      final familyAsync = ref.watch(familyStreamProvider(familyId));
      return familyAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (error, stack) => AsyncValue.error(error, stack),
        data: (family) => AsyncValue.data(family),
      );
    },
  );
});

final familyMembersProvider =
    StreamProvider.family<List<FamilyMember>, String>((ref, familyId) {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.getMembersStream(familyId);
});

FamilyModel? _findFamilyById(List<FamilyModel> families, String? familyId) {
  if (familyId == null) return null;

  for (final family in families) {
    if (family.id == familyId) {
      return family;
    }
  }

  return null;
}
