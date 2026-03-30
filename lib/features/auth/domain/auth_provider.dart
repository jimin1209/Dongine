import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/auth/data/auth_repository.dart';
import 'package:dongine/shared/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final userProfileProvider = FutureProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(authRepositoryProvider).getUserProfile(uid);
});

final currentUserProfileProvider = FutureProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Future.value(null);
      return ref.watch(authRepositoryProvider).getUserProfile(user.uid);
    },
    loading: () => Future.value(null),
    error: (_, _) => Future.value(null),
  );
});
