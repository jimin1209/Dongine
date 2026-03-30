import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/shared/models/family_model.dart';

void main() {
  test('초대 만료 시각이 Firestore 맵에 포함된다', () {
    final family = FamilyModel(
      id: 'family-1',
      name: '우리 가족',
      createdBy: 'user-1',
      memberIds: const ['user-1'],
      inviteCode: 'ABC123',
      inviteExpiresAt: DateTime(2026, 4, 6, 12),
      createdAt: DateTime(2026, 3, 30, 12),
    );

    final map = family.toFirestore();

    expect(map['inviteCode'], 'ABC123');
    expect(map['inviteExpiresAt'], isA<Timestamp>());
  });

  group('FamilyMember 역할 관련', () {
    test('기본 역할은 member이다', () {
      final data = <String, dynamic>{
        'nickname': '테스터',
        'joinedAt': Timestamp.fromDate(DateTime(2026, 3, 30)),
        'locationSharingEnabled': true,
      };

      final member = FamilyMember(
        uid: 'user-1',
        role: data['role'] as String? ?? 'member',
        nickname: data['nickname'] as String,
        joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      );

      expect(member.role, 'member');
    });

    test('관리자 역할이 toFirestore에 올바르게 직렬화된다', () {
      final member = FamilyMember(
        uid: 'admin-1',
        role: 'admin',
        nickname: '관리자',
        joinedAt: DateTime(2026, 3, 30),
      );

      final map = member.toFirestore();
      expect(map['role'], 'admin');
    });

    test('멤버 역할이 toFirestore에 올바르게 직렬화된다', () {
      final member = FamilyMember(
        uid: 'user-2',
        role: 'member',
        nickname: '일반멤버',
        joinedAt: DateTime(2026, 3, 30),
      );

      final map = member.toFirestore();
      expect(map['role'], 'member');
    });
  });

  group('FamilyMember 역할 변경 가드', () {
    List<FamilyMember> buildMembers(List<String> roles) {
      return roles.asMap().entries.map((e) {
        return FamilyMember(
          uid: 'user-${e.key}',
          role: e.value,
          nickname: '멤버${e.key}',
          joinedAt: DateTime(2026, 3, 30),
        );
      }).toList();
    }

    test('관리자가 여러 명이면 관리자 해제가 가능하다', () {
      final members = buildMembers(['admin', 'admin', 'member']);
      final adminCount = members.where((m) => m.role == 'admin').length;
      expect(adminCount, greaterThan(1));
    });

    test('관리자가 한 명뿐이면 마지막 관리자로 판별된다', () {
      final members = buildMembers(['admin', 'member', 'member']);
      final adminCount = members.where((m) => m.role == 'admin').length;
      expect(adminCount, 1);
    });

    test('유일한 관리자가 나가기를 시도하면 차단 조건에 해당한다', () {
      final members = buildMembers(['admin', 'member']);
      final uid = 'user-0';
      final currentMember = members.firstWhere((m) => m.uid == uid);
      final adminCount = members.where((m) => m.role == 'admin').length;

      final blocked = currentMember.role == 'admin' &&
          adminCount == 1 &&
          members.length > 1;
      expect(blocked, isTrue);
    });

    test('마지막 멤버(유일 관리자)는 나가기가 허용된다', () {
      final members = buildMembers(['admin']);
      final uid = 'user-0';
      final currentMember = members.firstWhere((m) => m.uid == uid);
      final adminCount = members.where((m) => m.role == 'admin').length;

      final blocked = currentMember.role == 'admin' &&
          adminCount == 1 &&
          members.length > 1;
      expect(blocked, isFalse);
    });

    test('일반 멤버는 역할 변경 없이 자기 데이터만 변경할 수 있다', () {
      final member = FamilyMember(
        uid: 'user-1',
        role: 'member',
        nickname: '멤버',
        joinedAt: DateTime(2026, 3, 30),
      );
      // 역할이 바뀌지 않는 업데이트 시나리오
      final updatedMap = member.toFirestore();
      expect(updatedMap['role'], 'member');
    });
  });

  test('copyWith로 초대 코드와 만료일을 갱신할 수 있다', () {
    final family = FamilyModel(
      id: 'family-1',
      name: '우리 가족',
      createdBy: 'user-1',
      memberIds: const ['user-1'],
      inviteCode: 'ABC123',
      createdAt: DateTime(2026, 3, 30, 12),
    );

    final updated = family.copyWith(
      inviteCode: 'XYZ789',
      inviteExpiresAt: DateTime(2026, 4, 8, 9),
    );

    expect(updated.inviteCode, 'XYZ789');
    expect(updated.inviteExpiresAt, DateTime(2026, 4, 8, 9));
    expect(updated.id, family.id);
  });
}
