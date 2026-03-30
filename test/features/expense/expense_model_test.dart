import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/shared/models/expense_model.dart';

void main() {
  final fixedDate = DateTime(2026, 3, 30, 14, 30);
  final fixedCreatedAt = DateTime(2026, 3, 29, 9, 0);

  ExpenseModel sample({
    String id = 'exp-1',
    String title = '점심',
    int amount = 12000,
    String category = '식비',
    String? memo = '회식',
    String createdBy = 'user-a',
    String paidBy = 'user-b',
    DateTime? date,
    String? eventId = 'evt-1',
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id,
      title: title,
      amount: amount,
      category: category,
      memo: memo,
      createdBy: createdBy,
      paidBy: paidBy,
      date: date ?? fixedDate,
      eventId: eventId,
      createdAt: createdAt ?? fixedCreatedAt,
    );
  }

  group('categoryIcon / categoryColor', () {
    test('알려진 카테고리는 고정 아이콘·색에 매핑된다', () {
      const cases = <String, ({IconData icon, Color color})>{
        '식비': (icon: Icons.restaurant, color: Colors.orange),
        '교통': (icon: Icons.directions_bus, color: Colors.blue),
        '생활': (icon: Icons.home, color: Colors.teal),
        '의료': (icon: Icons.local_hospital, color: Colors.red),
        '교육': (icon: Icons.school, color: Colors.indigo),
        '여가': (icon: Icons.sports_esports, color: Colors.purple),
        '기타': (icon: Icons.more_horiz, color: Colors.grey),
      };

      for (final entry in cases.entries) {
        expect(
          ExpenseModel.categoryIcon(entry.key),
          entry.value.icon,
          reason: 'category=${entry.key}',
        );
        expect(
          ExpenseModel.categoryColor(entry.key),
          entry.value.color,
          reason: 'category=${entry.key}',
        );
      }
    });

    test('정의되지 않은 카테고리는 기본(기타) 스타일로 폴백한다', () {
      expect(ExpenseModel.categoryIcon('알 수 없음'), Icons.more_horiz);
      expect(ExpenseModel.categoryColor('알 수 없음'), Colors.grey);
    });

    test('categories 리스트가 매핑 대상 카테고리와 일치한다', () {
      expect(ExpenseModel.categories, [
        '식비',
        '교통',
        '생활',
        '의료',
        '교육',
        '여가',
        '기타',
      ]);
    });
  });

  group('toFirestore', () {
    test('스칼라·Timestamp 필드가 기대 형식으로 직렬화된다', () {
      final m = sample();
      final map = m.toFirestore();

      expect(map['title'], m.title);
      expect(map['amount'], m.amount);
      expect(map['category'], m.category);
      expect(map['memo'], m.memo);
      expect(map['createdBy'], m.createdBy);
      expect(map['paidBy'], m.paidBy);
      expect(map['eventId'], m.eventId);
      expect(map['date'], Timestamp.fromDate(m.date));
      expect(map['createdAt'], Timestamp.fromDate(m.createdAt));
    });

    test('memo·eventId 가 null 이면 맵에 null 로 들어간다', () {
      final m = sample(memo: null, eventId: null);
      final map = m.toFirestore();

      expect(map['memo'], isNull);
      expect(map['eventId'], isNull);
    });

    test('id 는 toFirestore 맵에 포함되지 않는다', () {
      final map = sample(id: 'only-on-model').toFirestore();
      expect(map.containsKey('id'), isFalse);
    });
  });

  group('fromFirestoreData (fromFirestore 와 동일 규칙)', () {
    test('맵에서 필드를 복원한다', () {
      final data = sample().toFirestore();
      final restored = ExpenseModel.fromFirestoreData('doc-xyz', data);

      expect(restored.id, 'doc-xyz');
      expect(restored.title, '점심');
      expect(restored.amount, 12000);
      expect(restored.category, '식비');
      expect(restored.memo, '회식');
      expect(restored.createdBy, 'user-a');
      expect(restored.paidBy, 'user-b');
      expect(restored.eventId, 'evt-1');
      expect(restored.date, fixedDate);
      expect(restored.createdAt, fixedCreatedAt);
    });

    test('toFirestore → fromFirestoreData 라운드트립이 동일 본문을 유지한다', () {
      final original = sample();
      final back = ExpenseModel.fromFirestoreData(
        original.id,
        original.toFirestore(),
      );

      expect(back.title, original.title);
      expect(back.amount, original.amount);
      expect(back.category, original.category);
      expect(back.memo, original.memo);
      expect(back.createdBy, original.createdBy);
      expect(back.paidBy, original.paidBy);
      expect(back.date, original.date);
      expect(back.eventId, original.eventId);
      expect(back.createdAt, original.createdAt);
    });

    test('category 가 없으면 기타로 둔다', () {
      final restored = ExpenseModel.fromFirestoreData(
        'id-1',
        {
          'title': 'x',
          'amount': 1,
          'createdBy': 'a',
          'paidBy': 'b',
          'date': Timestamp.fromDate(fixedDate),
          'createdAt': Timestamp.fromDate(fixedCreatedAt),
        },
      );
      expect(restored.category, '기타');
    });
  });

  group('copyWith', () {
    test('전달한 필드만 바뀌고 나머지는 유지된다', () {
      final base = sample();
      final next = base.copyWith(
        title: '저녁',
        amount: 20000,
        category: '교통',
        memo: null,
        paidBy: 'user-c',
        date: DateTime(2026, 4, 1),
        eventId: null,
        createdAt: DateTime(2026, 4, 2),
      );

      expect(next.id, base.id);
      expect(next.title, '저녁');
      expect(next.amount, 20000);
      expect(next.category, '교통');
      expect(next.memo, base.memo);
      expect(next.createdBy, base.createdBy);
      expect(next.paidBy, 'user-c');
      expect(next.date, DateTime(2026, 4, 1));
      expect(next.eventId, base.eventId);
      expect(next.createdAt, DateTime(2026, 4, 2));
    });

    test('인자를 생략하면 기존 값이 그대로다', () {
      final base = sample();
      final same = base.copyWith();
      expect(same.title, base.title);
      expect(same.amount, base.amount);
      expect(same.memo, base.memo);
      expect(same.eventId, base.eventId);
    });
  });
}
