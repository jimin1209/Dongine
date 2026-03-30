import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dongine/features/calendar/domain/calendar_view_helpers.dart';

void main() {
  group('eventTypeIcon', () {
    test('meal → restaurant', () {
      expect(eventTypeIcon('meal'), Icons.restaurant);
    });

    test('date → favorite', () {
      expect(eventTypeIcon('date'), Icons.favorite);
    });

    test('anniversary → cake', () {
      expect(eventTypeIcon('anniversary'), Icons.cake);
    });

    test('hospital → local_hospital', () {
      expect(eventTypeIcon('hospital'), Icons.local_hospital);
    });

    test('알 수 없는 타입 → event', () {
      expect(eventTypeIcon('unknown'), Icons.event);
      expect(eventTypeIcon(''), Icons.event);
    });
  });

  group('eventTypeLabel', () {
    test('meal → 식사', () {
      expect(eventTypeLabel('meal'), '식사');
    });

    test('date → 데이트', () {
      expect(eventTypeLabel('date'), '데이트');
    });

    test('anniversary → 기념일', () {
      expect(eventTypeLabel('anniversary'), '기념일');
    });

    test('hospital → 병원', () {
      expect(eventTypeLabel('hospital'), '병원');
    });

    test('알 수 없는 타입 → 일반', () {
      expect(eventTypeLabel('general'), '일반');
      expect(eventTypeLabel('xyz'), '일반');
    });
  });

  group('eventTypeColor', () {
    test('meal → #FF9800', () {
      expect(eventTypeColor('meal'), '#FF9800');
    });

    test('date → #E91E63', () {
      expect(eventTypeColor('date'), '#E91E63');
    });

    test('anniversary → #9C27B0', () {
      expect(eventTypeColor('anniversary'), '#9C27B0');
    });

    test('hospital → #4CAF50', () {
      expect(eventTypeColor('hospital'), '#4CAF50');
    });

    test('알 수 없는 타입 → #4285F4', () {
      expect(eventTypeColor('general'), '#4285F4');
    });
  });

  group('parseHexColor', () {
    test('유효한 hex 값을 파싱한다', () {
      expect(parseHexColor('#FF9800'), const Color(0xFFFF9800));
      expect(parseHexColor('#4285F4'), const Color(0xFF4285F4));
    });

    test('유효하지 않은 hex 는 기본 파란색으로 폴백한다', () {
      expect(parseHexColor('invalid'), const Color(0xFF4285F4));
      expect(parseHexColor(''), const Color(0xFF4285F4));
    });
  });
}
