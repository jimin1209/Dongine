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
