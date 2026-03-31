import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/app_constants.dart';
import 'package:dongine/features/family/data/family_repository.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseTime = DateTime(2026, 3, 15, 12, 0, 0);

  Map<String, dynamic> inviteRow({
    String familyId = 'fam-1',
    String inviteCode = 'ABC123',
    DateTime? expiresAt,
    bool? isActive,
  }) {
    return {
      'familyId': familyId,
      'inviteCode': inviteCode,
      'createdBy': 'admin',
      'createdAt': Timestamp.fromDate(baseTime),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      ...?switch (isActive) {
        final active? => {'isActive': active},
        null => null,
      },
    };
  }

  /// [joinFamily] 가 초대 문서·가족 문서 순으로 적용하는 검증을 한 번에 재현한다.
  void assertJoinFamilyGuards({
    required bool inviteExists,
    required Map<String, dynamic>? inviteData,
    required FamilyModel family,
    required String normalizedInviteCode,
    required String uid,
    required DateTime now,
  }) {
    assertInviteExistsAndJoinable(inviteExists, inviteData, now);
    assertFamilyJoinableForInvite(
      family,
      normalizedInviteCode,
      uid,
      AppConstants.maxFamilyMembers,
    );
  }

  group('assertInviteRowJoinable', () {
    test('만료 시각이 now 이하이면 만료 예외', () {
      expect(
        () => assertInviteRowJoinable(
          inviteRow(expiresAt: baseTime),
          baseTime,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('만료된 초대 코드'),
          ),
        ),
      );
    });

    test('isActive 가 false 면 만료 예외', () {
      expect(
        () => assertInviteRowJoinable(
          inviteRow(
            expiresAt: baseTime.add(const Duration(days: 1)),
            isActive: false,
          ),
          baseTime,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('만료된 초대 코드'),
          ),
        ),
      );
    });

    test('expiresAt 이 없으면 만료 예외', () {
      expect(
        () => assertInviteRowJoinable(
          inviteRow(expiresAt: null),
          baseTime,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('만료된 초대 코드'),
          ),
        ),
      );
    });

    test('familyId 가 비어 있으면 유효하지 않음', () {
      expect(
        () => assertInviteRowJoinable(
          inviteRow(familyId: ''),
          baseTime,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('유효하지 않은 초대 코드'),
          ),
        ),
      );
    });

    test('유효한 행은 통과한다', () {
      expect(
        () => assertInviteRowJoinable(
          inviteRow(expiresAt: baseTime.add(const Duration(seconds: 1))),
          baseTime,
        ),
        returnsNormally,
      );
    });
  });

  group('assertInviteExistsAndJoinable', () {
    test('초대 문서가 없으면 참가 불가 (재발급으로 삭제된 코드)', () {
      expect(
        () => assertInviteExistsAndJoinable(false, null, baseTime),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('유효하지 않은 초대 코드'),
          ),
        ),
      );
    });

    test('존재하지만 data 가 없으면 참가 불가', () {
      expect(
        () => assertInviteExistsAndJoinable(true, null, baseTime),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('유효하지 않은 초대 코드'),
          ),
        ),
      );
    });

    test('문서가 있어도 행이 만료면 만료 예외', () {
      expect(
        () => assertInviteExistsAndJoinable(
          true,
          inviteRow(expiresAt: baseTime),
          baseTime,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('만료된 초대 코드'),
          ),
        ),
      );
    });

    test('유효한 문서·행이면 통과', () {
      expect(
        () => assertInviteExistsAndJoinable(
          true,
          inviteRow(expiresAt: baseTime.add(const Duration(days: 1))),
          baseTime,
        ),
        returnsNormally,
      );
    });
  });

  group('joinFamily 검증 체인 시나리오', () {
    FamilyModel family({
      required String id,
      String inviteCode = 'JOIN01',
      List<String>? memberIds,
    }) {
      return FamilyModel(
        id: id,
        name: '테스트',
        createdBy: 'admin-uid',
        memberIds: memberIds ?? const ['admin-uid'],
        inviteCode: inviteCode,
        createdAt: baseTime,
      );
    }

    test('만료된 초대 코드로는 초대 단계에서 차단되어 가족 정원 검사까지 가지 않는다', () {
      expect(
        () => assertJoinFamilyGuards(
          inviteExists: true,
          inviteData: inviteRow(
            familyId: 'fam-1',
            inviteCode: 'JOIN01',
            expiresAt: baseTime,
          ),
          family: family(id: 'fam-1'),
          normalizedInviteCode: 'JOIN01',
          uid: 'newbie',
          now: baseTime,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('만료된 초대 코드'),
          ),
        ),
      );
    });

    test('재발급 후 옛 초대 문서가 사라지면 해당 코드로는 참가 불가', () {
      expect(
        () => assertJoinFamilyGuards(
          inviteExists: false,
          inviteData: null,
          family: family(id: 'fam-1', inviteCode: 'NEWCOD'),
          normalizedInviteCode: 'OLDCOD',
          uid: 'newbie',
          now: baseTime,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('유효하지 않은 초대 코드'),
          ),
        ),
      );
    });

    test('재발급 후 새 코드와 가족 문서 inviteCode 가 일치하면 신규 멤버 참가 검증 통과', () {
      const newCode = 'NEWZZ1';
      expect(
        () => assertJoinFamilyGuards(
          inviteExists: true,
          inviteData: inviteRow(
            familyId: 'fam-1',
            inviteCode: newCode,
            expiresAt: baseTime.add(const Duration(days: AppConstants.inviteExpirationDays)),
          ),
          family: family(id: 'fam-1', inviteCode: newCode),
          normalizedInviteCode: newCode,
          uid: 'newbie',
          now: baseTime,
        ),
        returnsNormally,
      );
    });

    test('재발급 후 가족 문서만 새 코드로 바뀌고 사용자가 옛 코드를 쓰면 거절', () {
      expect(
        () => assertJoinFamilyGuards(
          inviteExists: true,
          inviteData: inviteRow(
            familyId: 'fam-1',
            inviteCode: 'OLDCOD',
            expiresAt: baseTime.add(const Duration(days: 1)),
          ),
          family: family(id: 'fam-1', inviteCode: 'NEWCOD'),
          normalizedInviteCode: 'OLDCOD',
          uid: 'newbie',
          now: baseTime,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('더 이상 유효하지 않은'),
          ),
        ),
      );
    });

    test('이미 memberIds 에 있는 uid 는 초대 행이 살아 있어도 재참가·중복 참가 차단', () {
      expect(
        () => assertJoinFamilyGuards(
          inviteExists: true,
          inviteData: inviteRow(
            familyId: 'fam-1',
            inviteCode: 'JOIN01',
            expiresAt: baseTime.add(const Duration(days: 1)),
          ),
          family: family(
            id: 'fam-1',
            memberIds: const ['admin-uid', 'dup-uid'],
          ),
          normalizedInviteCode: 'JOIN01',
          uid: 'dup-uid',
          now: baseTime,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('이미 이 가족 그룹의 멤버'),
          ),
        ),
      );
    });
  });

  group('assertFamilyJoinableForInvite', () {
    FamilyModel family({
      String inviteCode = 'JOIN01',
      List<String>? memberIds,
    }) {
      return FamilyModel(
        id: 'f1',
        name: '테스트',
        createdBy: 'a',
        memberIds: memberIds ?? const ['a'],
        inviteCode: inviteCode,
        createdAt: baseTime,
      );
    }

    test('가족 문서의 inviteCode 가 초대와 다르면 거절', () {
      expect(
        () => assertFamilyJoinableForInvite(
          family(inviteCode: 'OTHER'),
          'JOIN01',
          'newbie',
          AppConstants.maxFamilyMembers,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('더 이상 유효하지 않은'),
          ),
        ),
      );
    });

    test('이미 memberIds 에 포함된 uid 면 거절', () {
      expect(
        () => assertFamilyJoinableForInvite(
          family(memberIds: const ['a', 'dup']),
          'JOIN01',
          'dup',
          AppConstants.maxFamilyMembers,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('이미 이 가족 그룹의 멤버'),
          ),
        ),
      );
    });

    test('정원(최대 인원)에 도달하면 거절', () {
      final ids = List.generate(
        AppConstants.maxFamilyMembers,
        (i) => 'm$i',
      );
      expect(
        () => assertFamilyJoinableForInvite(
          family(memberIds: ids),
          'JOIN01',
          'newbie',
          AppConstants.maxFamilyMembers,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('정원이 가득'),
          ),
        ),
      );
    });

    test('정원 미만이고 코드·멤버십이 맞으면 통과', () {
      expect(
        () => assertFamilyJoinableForInvite(
          family(memberIds: const ['a']),
          'JOIN01',
          'newbie',
          AppConstants.maxFamilyMembers,
        ),
        returnsNormally,
      );
    });
  });
}
