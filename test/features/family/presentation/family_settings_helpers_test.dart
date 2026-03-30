import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/family/presentation/family_settings_helpers.dart';
import 'package:dongine/shared/models/family_model.dart';

FamilyMember _member({
  String uid = 'user-0',
  String role = 'member',
  String nickname = '멤버',
}) {
  return FamilyMember(
    uid: uid,
    role: role,
    nickname: nickname,
    joinedAt: DateTime(2026, 3, 30),
  );
}

void main() {
  // ─── isUserAdmin ───

  group('isUserAdmin', () {
    test('관리자 역할의 사용자는 true를 반환한다', () {
      final members = [
        _member(uid: 'admin-1', role: 'admin'),
        _member(uid: 'user-1', role: 'member'),
      ];
      expect(isUserAdmin(members, 'admin-1'), isTrue);
    });

    test('일반 멤버는 false를 반환한다', () {
      final members = [
        _member(uid: 'admin-1', role: 'admin'),
        _member(uid: 'user-1', role: 'member'),
      ];
      expect(isUserAdmin(members, 'user-1'), isFalse);
    });

    test('uid가 null이면 false를 반환한다', () {
      final members = [_member(uid: 'admin-1', role: 'admin')];
      expect(isUserAdmin(members, null), isFalse);
    });

    test('빈 멤버 목록은 false를 반환한다', () {
      expect(isUserAdmin([], 'admin-1'), isFalse);
    });

    test('목록에 없는 uid는 false를 반환한다', () {
      final members = [_member(uid: 'admin-1', role: 'admin')];
      expect(isUserAdmin(members, 'unknown'), isFalse);
    });
  });

  // ─── countAdmins ───

  group('countAdmins', () {
    test('관리자가 없으면 0을 반환한다', () {
      final members = [
        _member(uid: 'u1', role: 'member'),
        _member(uid: 'u2', role: 'member'),
      ];
      expect(countAdmins(members), 0);
    });

    test('관리자가 한 명이면 1을 반환한다', () {
      final members = [
        _member(uid: 'u1', role: 'admin'),
        _member(uid: 'u2', role: 'member'),
      ];
      expect(countAdmins(members), 1);
    });

    test('관리자가 여러 명이면 정확한 수를 반환한다', () {
      final members = [
        _member(uid: 'u1', role: 'admin'),
        _member(uid: 'u2', role: 'admin'),
        _member(uid: 'u3', role: 'member'),
      ];
      expect(countAdmins(members), 2);
    });

    test('빈 목록은 0을 반환한다', () {
      expect(countAdmins([]), 0);
    });
  });

  // ─── isSoleAdmin ───

  group('isSoleAdmin', () {
    test('관리자이고 adminCount가 1이면 true', () {
      final admin = _member(uid: 'a1', role: 'admin');
      expect(isSoleAdmin(admin, 1), isTrue);
    });

    test('관리자이고 adminCount가 2이면 false', () {
      final admin = _member(uid: 'a1', role: 'admin');
      expect(isSoleAdmin(admin, 2), isFalse);
    });

    test('일반 멤버이면 adminCount와 무관하게 false', () {
      final member = _member(uid: 'u1', role: 'member');
      expect(isSoleAdmin(member, 1), isFalse);
    });

    test('관리자이고 adminCount가 0이면 true(엣지 케이스)', () {
      final admin = _member(uid: 'a1', role: 'admin');
      expect(isSoleAdmin(admin, 0), isTrue);
    });
  });

  // ─── canChangeRole ───

  group('canChangeRole', () {
    test('관리자이고 familyId와 currentUid가 있으면 true', () {
      expect(
        canChangeRole(
          isCurrentUserAdmin: true,
          familyId: 'fam-1',
          currentUid: 'uid-1',
        ),
        isTrue,
      );
    });

    test('관리자가 아니면 false', () {
      expect(
        canChangeRole(
          isCurrentUserAdmin: false,
          familyId: 'fam-1',
          currentUid: 'uid-1',
        ),
        isFalse,
      );
    });

    test('familyId가 null이면 false', () {
      expect(
        canChangeRole(
          isCurrentUserAdmin: true,
          familyId: null,
          currentUid: 'uid-1',
        ),
        isFalse,
      );
    });

    test('currentUid가 null이면 false', () {
      expect(
        canChangeRole(
          isCurrentUserAdmin: true,
          familyId: 'fam-1',
          currentUid: null,
        ),
        isFalse,
      );
    });
  });

  // ─── leaveGuardStatus ───

  group('leaveGuardStatus', () {
    test('유일한 관리자 + 다른 구성원 → blockedSoleAdmin', () {
      final members = [
        _member(uid: 'admin-1', role: 'admin'),
        _member(uid: 'user-1', role: 'member'),
      ];
      expect(
        leaveGuardStatus(uid: 'admin-1', members: members),
        LeaveGuardStatus.blockedSoleAdmin,
      );
    });

    test('유일한 관리자 + 혼자 → allowedLastMember', () {
      final members = [_member(uid: 'admin-1', role: 'admin')];
      expect(
        leaveGuardStatus(uid: 'admin-1', members: members),
        LeaveGuardStatus.allowedLastMember,
      );
    });

    test('관리자가 여러 명이면 관리자도 나갈 수 있다 → allowed', () {
      final members = [
        _member(uid: 'admin-1', role: 'admin'),
        _member(uid: 'admin-2', role: 'admin'),
        _member(uid: 'user-1', role: 'member'),
      ];
      expect(
        leaveGuardStatus(uid: 'admin-1', members: members),
        LeaveGuardStatus.allowed,
      );
    });

    test('일반 멤버는 자유롭게 나갈 수 있다 → allowed', () {
      final members = [
        _member(uid: 'admin-1', role: 'admin'),
        _member(uid: 'user-1', role: 'member'),
      ];
      expect(
        leaveGuardStatus(uid: 'user-1', members: members),
        LeaveGuardStatus.allowed,
      );
    });

    test('일반 멤버가 혼자 남았으면 → allowedLastMember', () {
      final members = [_member(uid: 'user-1', role: 'member')];
      expect(
        leaveGuardStatus(uid: 'user-1', members: members),
        LeaveGuardStatus.allowedLastMember,
      );
    });

    test('관리자 2명 중 하나가 나가기 → allowed', () {
      final members = [
        _member(uid: 'admin-1', role: 'admin'),
        _member(uid: 'admin-2', role: 'admin'),
      ];
      expect(
        leaveGuardStatus(uid: 'admin-1', members: members),
        LeaveGuardStatus.allowed,
      );
    });

    test('유일한 관리자 + 멤버 3명 → blockedSoleAdmin', () {
      final members = [
        _member(uid: 'admin-1', role: 'admin'),
        _member(uid: 'user-1', role: 'member'),
        _member(uid: 'user-2', role: 'member'),
        _member(uid: 'user-3', role: 'member'),
      ];
      expect(
        leaveGuardStatus(uid: 'admin-1', members: members),
        LeaveGuardStatus.blockedSoleAdmin,
      );
    });
  });
}
