import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dongine/core/constants/app_constants.dart';
import 'package:dongine/features/family/data/family_repository.dart';
import 'package:dongine/shared/models/family_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseTime = DateTime(2026, 3, 15, 12, 0, 0);

  Map<String, dynamic> inviteRow({
    String familyId = 'fam-1',
    DateTime? expiresAt,
    bool? isActive,
  }) {
    return {
      'familyId': familyId,
      'inviteCode': 'ABC123',
      'createdBy': 'admin',
      'createdAt': Timestamp.fromDate(baseTime),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      ...?switch (isActive) {
        final active? => {'isActive': active},
        null => null,
      },
    };
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
