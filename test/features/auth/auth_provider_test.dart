import 'dart:async';

import 'package:dongine/features/auth/data/auth_repository.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/shared/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);

  @override
  final String uid;
}

class _FakeAuthRepository implements AuthRepositoryBase {
  _FakeAuthRepository(this._authStateChanges);

  final Stream<User?> _authStateChanges;

  Future<UserModel?> Function(String uid)? profileResolver;

  @override
  Stream<User?> get authStateChanges => _authStateChanges;

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    final r = profileResolver;
    if (r == null) return null;
    return r(uid);
  }

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> signInWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> updateUserProfile(UserModel user) => throw UnimplementedError();

  @override
  Future<void> updateDisplayName(String newDisplayName) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

void main() {
  group('authStateProvider → currentUserProfileProvider', () {
    test('사용자 없음이면 currentUserProfileProvider는 null이다', () async {
      final repo = _FakeAuthRepository(Stream<User?>.value(null));
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(currentUserProfileProvider.future);
      expect(profile, isNull);
    });

    test('사용자 있으면 getUserProfile이 돌아준 프로필을 반환한다', () async {
      const uid = 'user-abc';
      final user = _FakeUser(uid);
      final expected = UserModel(
        uid: uid,
        displayName: '테스트',
        email: 't@example.com',
        createdAt: DateTime(2026, 1, 1),
        lastSeen: DateTime(2026, 1, 2),
      );
      final repo = _FakeAuthRepository(Stream<User?>.value(user));
      repo.profileResolver = (_) async => expected;

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(currentUserProfileProvider.future);
      expect(profile, isNotNull);
      expect(profile!.uid, uid);
      expect(profile.displayName, '테스트');
    });

    test('인증 스트림이 첫 이벤트 전(로딩)이면 프로필 future는 null로 완료된다', () async {
      final controller = StreamController<User?>();
      addTearDown(controller.close);
      final repo = _FakeAuthRepository(controller.stream);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(currentUserProfileProvider.future);
      expect(profile, isNull);
    });

    test('인증 스트림 오류면 currentUserProfileProvider는 null로 완료된다', () async {
      final repo = _FakeAuthRepository(
        Stream<User?>.error(Exception('auth-fail')),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(currentUserProfileProvider.future);
      expect(profile, isNull);
    });
  });

  group('authRepositoryProvider override 회귀', () {
    test('authState·currentUserProfile·userProfileProvider 읽기가 예외 없이 동작한다', () async {
      final repo = _FakeAuthRepository(Stream<User?>.value(null));
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final auth = await container.read(authStateProvider.future);
      expect(auth, isNull);

      await container.read(currentUserProfileProvider.future);

      final byUid = await container.read(userProfileProvider('any-uid').future);
      expect(byUid, isNull);
    });
  });
}
