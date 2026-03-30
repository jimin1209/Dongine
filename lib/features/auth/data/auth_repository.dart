import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dongine/shared/models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessage(e.code));
    }
  }

  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(displayName);

      final user = UserModel(
        uid: credential.user!.uid,
        displayName: displayName,
        email: email,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(user.toFirestore());

      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessage(e.code));
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> updateUserProfile(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .update(user.toFirestore());
  }

  /// 공백 제거 후 비어 있지 않은 표시 이름을 반환합니다. 그렇지 않으면 [AuthException]을 던집니다.
  static String validateDisplayName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const AuthException('표시 이름을 입력해주세요.');
    }
    if (trimmed.length > 80) {
      throw const AuthException('표시 이름은 80자 이내로 입력해주세요.');
    }
    return trimmed;
  }

  /// Firebase Auth 프로필과 Firestore `users` 문서의 `displayName`을 같은 값으로 맞춥니다.
  Future<void> updateDisplayName(String newDisplayName) async {
    final trimmed = validateDisplayName(newDisplayName);
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('로그인이 필요합니다.');
    }

    try {
      await user.updateDisplayName(trimmed);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessage(e.code));
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'displayName': trimmed,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  /// 이메일을 검증하고 trim한 값을 반환합니다. 빈 값이거나 '@'이 없으면 [AuthException]을 던집니다.
  static String validateResetEmail(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const AuthException('이메일을 입력해주세요.');
    }
    if (!trimmed.contains('@')) {
      throw const AuthException('올바른 이메일 형식이 아닙니다.');
    }
    return trimmed;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = validateResetEmail(email);
    try {
      await _auth.sendPasswordResetEmail(email: trimmed);
    } on FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessage(e.code));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  static String friendlyMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return '올바른 이메일 형식이 아닙니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다. 관리자에게 문의해주세요.';
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않습니다.';
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. 6자 이상 입력해주세요.';
      case 'operation-not-allowed':
        return '이메일/비밀번호 로그인이 비활성화되어 있습니다.';
      case 'too-many-requests':
        return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요.';
      default:
        return '오류가 발생했습니다. 다시 시도해주세요.';
    }
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
