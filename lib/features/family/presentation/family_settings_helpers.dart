import 'package:dongine/shared/models/family_model.dart';

/// 현재 사용자가 관리자인지 판별한다.
bool isUserAdmin(List<FamilyMember> members, String? uid) {
  if (uid == null) return false;
  return members.any((m) => m.uid == uid && m.role == 'admin');
}

/// 해당 멤버가 유일한 관리자인지 판별한다.
bool isSoleAdmin(FamilyMember member, int adminCount) {
  return member.role == 'admin' && adminCount <= 1;
}

/// 멤버 목록에서 관리자 수를 센다.
int countAdmins(List<FamilyMember> members) {
  return members.where((m) => m.role == 'admin').length;
}

/// 역할 변경 버튼을 노출할 수 있는지 여부를 판별한다.
bool canChangeRole({
  required bool isCurrentUserAdmin,
  required String? familyId,
  required String? currentUid,
}) {
  return isCurrentUserAdmin && familyId != null && currentUid != null;
}

/// 가족 나가기 차단 상태를 나타내는 열거형.
enum LeaveGuardStatus {
  /// 유일한 관리자이면서 다른 구성원이 있어 나갈 수 없다.
  blockedSoleAdmin,

  /// 마지막 구성원이므로 나가면 그룹이 삭제된다.
  allowedLastMember,

  /// 자유롭게 나갈 수 있다.
  allowed,
}

/// 가족 나가기 시도 시 차단 상태를 결정한다.
LeaveGuardStatus leaveGuardStatus({
  required String uid,
  required List<FamilyMember> members,
}) {
  final adminCount = countAdmins(members);
  final isSoleAdminUser =
      adminCount == 1 && members.any((m) => m.uid == uid && m.role == 'admin');
  final hasOtherMembers = members.length > 1;

  if (isSoleAdminUser && hasOtherMembers) {
    return LeaveGuardStatus.blockedSoleAdmin;
  }

  if (!hasOtherMembers) {
    return LeaveGuardStatus.allowedLastMember;
  }

  return LeaveGuardStatus.allowed;
}
